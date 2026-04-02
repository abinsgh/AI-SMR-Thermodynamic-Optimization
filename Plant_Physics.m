% =========================================================================
% PROJECT: NuScale SMR — Auxiliary Power Optimization using Genetic Algorithms
% TEAM MEMBERS:
%   - Ahmed Saeed Alghamdi
%   - Faisal Saeed Bahadi
%   - Ahmed Saud Alsalahi
% SUPERVISED BY: Dr. Anas Alwafi
% -------------------------------------------------------------------------
% DESCRIPTION: Advanced thermodynamic simulation and optimization of the
% SMR Rankine cycle using AI to maximize net power during peak summer conditions.
% =========================================================================
%
% FILE: Plant_Physics.m
%
% PURPOSE:
%   Core thermodynamic and hydraulic simulation engine for the NuScale SMR
%   Rankine cycle. Given two GA decision variables — pump speed ratio and MSR
%   valve position — this function computes the plant's net electrical output
%   and returns a scalar cost value for minimization by the genetic algorithm.
%
% INPUTS:
%   x(1)      — Pump Speed Ratio          [-]   range: [0.5, 1.0]
%   x(2)      — MSR Valve Position        [-]   range: [0.0, 1.0]
%   PlantData — Struct of plant parameters (see Run_Optimization.m for definitions)
%
% OUTPUTS:
%   Cost      — GA objective (scalar): negative net power [MW], to be minimized
%   Results   — Struct with full operating point data (optional second output)
%
% PHYSICS MODEL OVERVIEW:
%   1. Hydraulic Model     : Pump-system curve intersection (affinity laws)
%   2. Condenser Model     : LMTD heat transfer with flow-dependent U correction
%   3. HP Turbine          : Isentropic expansion with efficiency correction
%   4. MSR Model           : Steam extraction & superheating via live steam bleed
%   5. LP Turbine          : Isentropic expansion to condenser back-pressure
%   6. Cost Function       : Cost = -W_net + penalties (backpressure, thermal discharge)
%
% DEPENDENCIES:
%   XSteam.m — IAPWS-IF97 water/steam property library
% =========================================================================

function [Cost, Results] = Plant_Physics(x, PlantData)

    %% =====================================================================
    %  SECTION 1: UNPACK DECISION VARIABLES
    % =====================================================================

    % x(1): Pump Speed Ratio [N/N_rated], controlled via Variable Frequency Drive (VFD).
    %        Lower bound of 0.5 enforced by GA; below 50% speed, NPSH margin
    %        becomes insufficient and cavitation risk increases significantly.
    N_ratio   = x(1);   % [-]

    % x(2): MSR (Moisture Separator Reheater) Valve Position.
    %        0.0 = fully bypassed (steam enters LP turbine at saturation temperature)
    %        1.0 = fully open   (maximum live-steam superheating of LP turbine inlet)
    MSR_Valve = x(2);   % [-]

    %% =====================================================================
    %  SECTION 2: HYDRAULIC MODEL — PUMP-SYSTEM CURVE INTERSECTION
    % =====================================================================
    %
    % The operating flow rate is found analytically by intersecting the
    % speed-scaled pump curve with the system resistance curve:
    %
    %   Pump curve   : H_pump = H_shutoff * N^2 - A_pump * Q^2
    %   System curve : H_sys  = H_static  + k_sys  * Q^2
    %
    % Setting H_pump = H_sys and solving for Q^2:
    %   Q^2 = (H_shutoff * N^2 - H_static) / (A_pump + k_sys)
    %
    % This is the "curve intersection" method — it avoids iterative solving
    % and gives a direct algebraic result for any speed ratio N.

    % Numerator: speed-scaled shut-off head minus static system head [m]
    num = (PlantData.H_shutoff * N_ratio^2) - PlantData.H_static;

    % Denominator: sum of pump and system resistance coefficients [m/(m^3/s)^2]
    den = (PlantData.A_pump + PlantData.k_sys);

    % Q^2 with floor at zero to guard against negative values at very low N
    % (physically: pump cannot overcome static head, flow goes to zero)
    Q_squared = max(num / den, 0);   % [m^6/s^2]

    % Actual volumetric flow rate of cooling seawater [m^3/s]
    Q_cw = sqrt(Q_squared);   % [m^3/s]

    % Cooling water mass flow rate [kg/s]
    m_dot_cw = Q_cw * PlantData.rho_sw;   % [kg/s]

    % Operating head at the calculated flow point [m]
    % H_op = H_static + friction losses at flow Q_cw
    H_op = PlantData.H_static + PlantData.k_sys * Q_squared;   % [m]

    % Hydraulic power delivered to the fluid [MW]
    % P_hyd = rho * g * Q * H  (converted from W to MW by dividing by 1e6)
    P_hyd = (PlantData.rho_sw * 9.81 * Q_cw * H_op) / 1e6;   % [MW]

    % Total pump shaft power, accounting for hydraulic and motor losses [MW]
    % P_pump = P_hyd / (eta_pump * eta_motor)
    P_pump = P_hyd / (PlantData.eta_pump * PlantData.eta_motor);   % [MW]

    %% =====================================================================
    %  SECTION 3: CONDENSER MODEL — DYNAMIC HEAT TRANSFER
    % =====================================================================
    %
    % The overall heat transfer coefficient U degrades at partial flow due to
    % reduced turbulence inside the condenser tubes. The correction follows
    % a standard shell-and-tube correlation:
    %
    %   U_curr = U_design * (m_dot_cw / m_dot_design)^0.6
    %
    % Exponent 0.6 is the Dittus-Boelter turbulent-flow power law for the
    % tube-side convection coefficient (Incropera et al., 7th Ed., Ch.8).

    % Flow ratio relative to design-point mass flow [-]
    Flow_Ratio = m_dot_cw / PlantData.m_dot_design;   % [-]

    % Protect against division-by-zero or extremely low flow (< 1% of design)
    % which would cause physically unrealistic U values
    if Flow_Ratio < 0.01
        Flow_Ratio = 0.01;
    end

    % Current overall heat transfer coefficient [kW/(m^2·K)]
    U_curr = PlantData.U_design * (Flow_Ratio)^0.6;   % [kW/(m^2·K)]

    % Dynamic condenser thermal load, scaled by actual vs. design steam flow [MWt]
    % Load_Factor accounts for partial-load operation of the steam generator
    Load_Factor    = PlantData.m_dot_steam / 110.0;           % [-]
    Q_cond_Actual  = PlantData.Q_cond_design * Load_Factor;   % [MWt]

    % Log Mean Temperature Difference (LMTD) across the condenser [K]
    % Derived from Q = U * A * LMTD  =>  LMTD = Q / (U * A)
    % (Q converted from MWt to kWt by multiplying by 1000)
    LMTD = (Q_cond_Actual * 1000) / (U_curr * PlantData.Area_cond);   % [K]

    % Specific heat capacity of seawater [kJ/(kg·K)]
    % Standard value at 35 ppt salinity, 25°C (Sharqawy et al., 2010)
    Cp_sw = 3.99;   % [kJ/(kg·K)]

    % Temperature rise of seawater across the condenser [K]
    % From energy balance: Q = m_dot_cw * Cp_sw * Delta_T
    % Floor case: if flow stops entirely, assign a large penalty value
    if m_dot_cw > 0.1
        Delta_T_Range = (Q_cond_Actual * 1000) / (m_dot_cw * Cp_sw);   % [K]
    else
        % Penalty value: physically represents condenser thermal runaway
        % at near-zero cooling flow — forces GA away from this infeasible region
        Delta_T_Range = 100;   % [K]
    end

    % Cooling water outlet temperature [degC]
    T_out = PlantData.T_sea + Delta_T_Range;   % [degC]

    % Approximate condenser saturation temperature [degC]
    % The steam condenses at a temperature above the bulk seawater temperature.
    % T_sat is estimated as the seawater temperature plus LMTD plus half the
    % seawater temperature rise (arithmetic mean of inlet/outlet driving difference).
    T_sat_cond = PlantData.T_sea + LMTD + (Delta_T_Range / 2);   % [degC]

    % Condenser saturation pressure from IAPWS-IF97 steam tables [bar]
    try
        P_cond = XSteam('psat_T', T_sat_cond);   % [bar]
    catch
        % Fallback if XSteam call fails (e.g., temperature out of valid range)
        P_cond = 1.0;   % [bar] — conservative default, will trigger backpressure penalty
    end

    % ---- LP Turbine Back-Pressure (Choking) Limit -------------------------
    % If the computed condenser pressure falls below the physical choking limit,
    % clamp it at P_choke. This represents the minimum achievable condenser
    % pressure before LP turbine last-stage blade loading becomes critical.
    if P_cond < PlantData.P_choke
        P_cond = PlantData.P_choke;   % [bar]
        try
            % Recompute saturation temperature at the clamped pressure
            T_sat_cond = XSteam('Tsat_p', P_cond);   % [degC]
        catch
            % Dynamic 2nd-Law fallback: condenser temperature MUST exceed T_sea
            % by at least a minimum pinch-point margin (2 K) to ensure heat can
            % flow from steam to seawater. A hardcoded value would violate this
            % requirement whenever T_sea exceeds that hardcoded temperature.
            T_sat_cond = PlantData.T_sea + 2.0;   % [degC]
        end
    end

    %% =====================================================================
    %  SECTION 4: TURBINE & MSR MODEL
    % =====================================================================

    % ---- 4A. High Pressure Turbine (HPT) ----------------------------------
    %
    % Steam expands from main steam conditions (P_main, T_main) to the
    % cold-reheat pressure (P_reheat). Actual enthalpy drop is computed
    % from the isentropic enthalpy drop scaled by isentropic efficiency.

    % Main steam enthalpy at HP turbine inlet [kJ/kg]
    h_main = XSteam('h_pT', PlantData.P_main, PlantData.T_main);   % [kJ/kg]

    % Main steam entropy at HP turbine inlet [kJ/(kg·K)]
    s_main = XSteam('s_pT', PlantData.P_main, PlantData.T_main);   % [kJ/(kg·K)]

    % Isentropic exit enthalpy at cold-reheat pressure (ideal expansion) [kJ/kg]
    h_HPT_out_ideal = XSteam('h_ps', PlantData.P_reheat, s_main);   % [kJ/kg]

    % Actual exit enthalpy, accounting for irreversibilities [kJ/kg]
    % h_out = h_in - eta_turb * (h_in - h_out_ideal)
    h_HPT_out = h_main - PlantData.eta_turb * (h_main - h_HPT_out_ideal);   % [kJ/kg]

    % HPT power output [MW]
    % W = m_dot * (h_in - h_out)  [converted from kW to MW by dividing by 1000]
    W_HPT = PlantData.m_dot_steam * (h_main - h_HPT_out) / 1000;   % [MW]

    % ---- 4B. Moisture Separator Reheater (MSR) Model ----------------------
    %
    % The MSR superheats the cold-reheat steam using a bleed of live (main)
    % steam before the steam enters the LP turbine. This improves steam quality
    % at LP turbine exhaust and reduces moisture-induced blade erosion.
    %
    % MSR_Valve = 0 : no reheat — LP inlet is at saturation temperature
    % MSR_Valve = 1 : full reheat — LP inlet is at T_hot_reheat_max (260°C)
    %
    % The LP inlet temperature is linearly interpolated between these bounds.

    % Saturation temperature at cold-reheat pressure [degC]
    T_sat_reheat = XSteam('Tsat_p', PlantData.P_reheat);   % [degC]

    % Maximum LP turbine inlet temperature achievable with live steam heating [degC]
    % Limited to 260°C to avoid excessive live steam extraction and thermal stress
    T_hot_reheat_max = 260;   % [degC]

    % Actual LP turbine inlet temperature [degC]
    T_LPT_in = T_sat_reheat + MSR_Valve * (T_hot_reheat_max - T_sat_reheat);   % [degC]

    % LP turbine inlet enthalpy [kJ/kg]
    h_LPT_in = XSteam('h_pT', PlantData.P_reheat, T_LPT_in);   % [kJ/kg]

    % ---- Steam Extraction Fraction (y) for MSR Heating --------------------
    %
    % The fraction y of main steam bled off to heat the MSR is determined by
    % an energy balance on the reheater:
    %
    %   y * Heat_Source = (1 - y) * Heat_Sink   (assuming negligible losses)
    %   y = Heat_Sink / (Heat_Source + Heat_Sink)
    %
    % Heat_Source: available enthalpy from live steam bleed [kJ/kg]
    % Heat_Sink  : heat required to superheat cold-reheat steam [kJ/kg]

    % Enthalpy of saturated liquid at main steam pressure [kJ/kg]
    % (condensate from live steam bleed after giving up its heat)
    h_live_condensate = XSteam('hL_p', PlantData.P_main);   % [kJ/kg]

    % Enthalpy available per kg of live steam bleed [kJ/kg]
    Heat_Source = h_main - h_live_condensate;   % [kJ/kg]

    % Enthalpy required per kg of cold-reheat steam to reach T_LPT_in [kJ/kg]
    Heat_Sink = h_LPT_in - h_HPT_out;   % [kJ/kg]

    % Steam extraction fraction [-]
    y = Heat_Sink / (Heat_Source + Heat_Sink);   % [-]

    % Physical upper bound: extraction fraction capped at 15% to maintain
    % acceptable LP turbine steam flow and avoid excessive live-steam bypass
    if y > 0.15
        y = 0.15;
    end

    % ---- 4C. Low Pressure Turbine (LPT) -----------------------------------
    %
    % The remaining (1-y) fraction of steam expands through the LP turbine
    % from cold-reheat conditions to condenser back-pressure.

    % LP turbine mass flow rate [kg/s]
    m_dot_LPT = PlantData.m_dot_steam * (1 - y);   % [kg/s]

    % LP turbine inlet entropy [kJ/(kg·K)]
    s_LPT_in = XSteam('s_pT', PlantData.P_reheat, T_LPT_in);   % [kJ/(kg·K)]

    % Isentropic exit enthalpy at condenser pressure [kJ/kg]
    % Note: moisture correction (Baumann rule) is implicitly captured by
    % the isentropic efficiency value, which is adequate for system-level simulation
    h_LPT_out_ideal = XSteam('h_ps', P_cond, s_LPT_in);   % [kJ/kg]

    % Actual LP turbine exit enthalpy [kJ/kg]
    h_LPT_out = h_LPT_in - PlantData.eta_turb * (h_LPT_in - h_LPT_out_ideal);   % [kJ/kg]

    % LP turbine power output [MW]
    W_LPT = m_dot_LPT * (h_LPT_in - h_LPT_out) / 1000;   % [MW]

    %% =====================================================================
    %  SECTION 5: NET POWER & COST FUNCTION
    % =====================================================================

    % Total turbine gross power output (HPT + LPT) [MW]
    W_Total_Turbine = W_HPT + W_LPT;   % [MW]

    % Net electrical power output after subtracting pump parasitic load [MW]
    % W_net = W_turbine - P_pump
    % This single expression captures the fundamental trade-off:
    %   reducing pump speed saves auxiliary power but increases condenser
    %   back-pressure, which reduces turbine output.
    %   The GA finds the operating point where W_net is globally maximized.
    W_Net = W_Total_Turbine - P_pump;   % [MW]

    % Net thermal efficiency of the Rankine cycle [-]
    % eta_net = W_net / Q_reactor
    Eta_net = W_Net / PlantData.Q_reactor;   % [-]

    % ---- GA Cost Function -------------------------------------------------
    % The GA minimizes Cost. To maximize W_net, Cost is defined as -W_net.
    % Penalties are then added as positive increments to steer the GA away
    % from physically infeasible or regulatory-violating operating points.
    Cost = -1 * W_Net;   % [MW] — base objective

    % ---- Penalty Functions (Physical & Regulatory Constraints) ------------
    %
    % IMPORTANT DESIGN NOTE: The two penalties below operate on INDEPENDENT
    % physical systems and are not double-counting the same effect:
    %
    %   Penalty 1 = Turbine mechanical safety constraint (backpressure trip)
    %   Penalty 2 = Environmental regulatory constraint (thermal discharge)
    %
    % When pump speed is low, both may activate simultaneously. This is
    % physically correct — the GA correctly learns that certain low-flow
    % operating points violate multiple independent constraints at once.
    %
    % A former stall-protection penalty (N_ratio < 0.5) has been removed.
    % It was unreachable dead code: the GA lower bound lb(1) = 0.5 already
    % enforces this hard constraint through the optimization bounds.

    % Penalty 1 — Turbine Back-Pressure Safety Limit
    % Basis: LP turbine trip setpoint for nuclear PWR/SMR installations.
    % Threshold: 0.10 bar — standard operational limit; exceeding this risks
    %            last-stage blade damage and automatic turbine trip.
    % Weight: 10,000 — intentionally large to make this a "hard" constraint
    %         that dominates the cost landscape and is never violated by the GA.
    if P_cond > 0.10
        Cost = Cost + (P_cond - 0.10) * 10000;
    end

    % Penalty 2 — Environmental Thermal Discharge Limit
    % Basis: IAEA-TECDOC-1085 guideline for once-through coastal cooling systems.
    % Threshold: Delta_T <= 15 K above ambient seawater temperature.
    %            (Site-specific environmental permits may impose stricter limits.)
    % Weight: 100 — "soft" constraint; allows GA to explore the trade-off space
    %         near the boundary rather than creating a hard cliff.
    if Delta_T_Range > 15
        Cost = Cost + (Delta_T_Range - 15) * 100;
    end

    %% =====================================================================
    %  SECTION 6: RESULTS STRUCT (returned only when explicitly requested)
    % =====================================================================

    if nargout > 1
        Results.P_pump       = P_pump;           % Pump shaft power consumption   [MW]
        Results.P_cond       = P_cond;           % Condenser saturation pressure   [bar]
        Results.T_cond       = T_sat_cond;       % Condenser saturation temperature [degC]
        Results.T_out        = T_out;            % Seawater outlet temperature      [degC]
        Results.W_turb       = W_Total_Turbine;  % Gross turbine power output       [MW]
        Results.W_net        = W_Net;            % Net plant electrical output      [MW]
        Results.Eta_net      = Eta_net;          % Net Rankine cycle efficiency     [-]
        Results.Extraction_y = y;               % MSR steam extraction fraction    [-]
        Results.Q_cw         = Q_cw;            % Cooling water volumetric flow    [m^3/s]
    end

end
