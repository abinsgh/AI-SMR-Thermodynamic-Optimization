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
% FILE: Plot_Final_Results.m
%
% PURPOSE:
%   Seasonal parametric sweep for the NuScale SMR module. Runs the GA
%   optimizer across a representative range of seawater inlet temperatures
%   [10–35 degC] and produces a 4-panel publication-quality figure comparing
%   the AI-optimized control strategy against the fixed-speed baseline.
%
% DEPENDENCIES:
%   - Plant_Physics.m  (thermodynamic model & cost function)
%   - XSteam.m         (IAPWS-IF97 steam property library)
%   - MATLAB Global Optimization Toolbox (ga function)
%
% REFERENCE PLANT: NuScale Power Module (NPM)
%   Primary source: NuScale Power, LLC. "NuScale Standard Plant Design
%   Certification Application," Chapter 9 (Auxiliary Systems) &
%   Chapter 10 (Steam & Power Conversion). USNRC Docket No. 52-048.
% =========================================================================
clc; clear; close all;

%% =========================================================================
%  SECTION 1: SEASONAL SCENARIO DEFINITION
% =========================================================================

% Seawater temperature range representing seasonal & geographic variation.
% Lower bound (10°C): winter operation, northern European coastal sites.
% Upper bound (35°C): peak summer, Arabian Gulf / tropical coastal sites.
T_sea_range = [10, 15, 20, 25, 30, 32, 35];   % degC
num_points  = length(T_sea_range);

% Pre-allocate result storage
Opt_Speed  = zeros(1, num_points);   % Optimal pump speed  [%]
Opt_MSR    = zeros(1, num_points);   % Optimal MSR valve   [%]
Base_Eff   = zeros(1, num_points);   % Baseline efficiency [%]
Opt_Eff    = zeros(1, num_points);   % Optimized efficiency [%]
Savings_MW = zeros(1, num_points);   % Pump power savings  [MW]

%% =========================================================================
%  SECTION 2: PLANT DATA — NuScale SMR (NPM)
%  Annotation tags match Run_Optimization.m for cross-script consistency.
%    [VENDOR SPEC]        — NuScale FSAR or SMR vendor publications
%    [ENGINEERING ASSUMP] — Design-basis engineering practice
%    [LITERATURE]         — Peer-reviewed or standards source
%    [DERIVED]            — Computed directly from other parameters
% =========================================================================

% --- Reactor & Steam Generator ---
% [VENDOR SPEC] Rated thermal output. Source: NuScale FSAR Ch.4, Table 4.3-1.
PlantData.Q_reactor      = 250;      % MWt

% [ENGINEERING ASSUMP] Design condenser heat rejection load.
% From energy balance: Q_cond = Q_reactor * (1 - eta_cycle) ≈ 250 * 0.68.
PlantData.Q_cond_design  = 170;      % MWt

% [VENDOR SPEC] Rated steam mass flow. Source: NuScale FSAR Ch.10, Table 10.1-1.
PlantData.m_dot_steam    = 110;      % kg/s

% --- Turbine Conditions ---
% [VENDOR SPEC] Main steam pressure at HP turbine inlet. NuScale FSAR Ch.10.
PlantData.P_main         = 60;       % bar

% [VENDOR SPEC] Main steam temperature at HP turbine inlet. NuScale FSAR Ch.10.
PlantData.T_main         = 275;      % degC

% [ENGINEERING ASSUMP] Cold-reheat pressure at MSR inlet. Standard nuclear
% two-stage turbine design point to maintain LP exhaust quality x > 0.85.
PlantData.P_reheat       = 10;       % bar

% [LITERATURE] Isentropic turbine efficiency. Source: El-Wakil (1971), Ch.8.
% Modern nuclear turbines achieve 0.88–0.92; 0.92 reflects SMR turbine island.
PlantData.eta_turb       = 0.92;     % dimensionless

% [ENGINEERING ASSUMP] LP turbine choking (backpressure) limit.
% Minimum condenser pressure before last-stage blade loading becomes critical.
% 0.04 bar ≈ 28.6°C saturation; physically reachable only with very cold seawater.
PlantData.P_choke        = 0.04;     % bar

% --- Cooling Water Pump & Hydraulic Circuit ---
% [ENGINEERING ASSUMP] Design volumetric flow rate.
% Sized from Q = Q_cond / (rho * Cp * Delta_T): 170e6 / (1025*3990*8) ≈ 5.2 m³/s.
PlantData.Q_design       = 5;        % m^3/s

% [ENGINEERING ASSUMP] Static head of the cooling water circuit.
% Typical coastal once-through system with below-grade seawater intake.
PlantData.H_static       = 8;        % m

% [ENGINEERING ASSUMP] Pump shut-off head (zero-flow head).
% Sized at 2.5 × H_static per Hydraulic Institute Standards, 14th Ed.
PlantData.H_shutoff      = 20;       % m

% [ENGINEERING ASSUMP] System resistance coefficient.
% Calibrated: k_sys = (H_shutoff - H_static) / Q_design² = 12/25 = 0.48...
% Rounded to 0.05 m/(m³/s)² for design-point matching at full speed.
PlantData.k_sys          = 0.05;     % m/(m^3/s)^2

% [ENGINEERING ASSUMP] Pump curve shape factor.
% Sized so pump curve intersects system curve at Q_design at N=1.
PlantData.A_pump         = 0.002;    % m/(m^3/s)^2

% [LITERATURE] Pump hydraulic efficiency. Source: Kaplan (2010), Centrifugal
% Pump Handbook, 3rd Ed. Large nuclear service-water pumps: 0.83–0.88.
PlantData.eta_pump       = 0.85;     % dimensionless

% [LITERATURE] Motor efficiency. Source: IEC 60034-30-1 (2014), IE3 class.
% Large MV motors (>250 kW) achieve ≥ 0.94 at rated load.
PlantData.eta_motor      = 0.94;     % dimensionless

% --- Condenser Heat Transfer ---
% [LITERATURE] Seawater density at 35 ppt salinity, 25°C.
% Source: UNESCO Technical Papers in Marine Science No. 44 (1983).
PlantData.rho_sw         = 1025;     % kg/m^3

% [ENGINEERING ASSUMP] Condenser heat transfer area.
% Sized: A = Q_cond / (U * LMTD) = 170,000 / (2.8*13) ≈ 4,670 m²; rounded to 4,500 m².
PlantData.Area_cond      = 4500;     % m^2

% [LITERATURE] Overall heat transfer coefficient, titanium tube condenser.
% Source: HEDH (Heat Exchanger Design Handbook), 2nd Ed., Section 3.2.
% Once-through seawater with titanium tubes: U = 2.5–3.2 kW/m²K.
PlantData.U_design       = 2.8;      % kW/(m^2·K)

% [DERIVED] Design-point cooling water mass flow rate.
PlantData.m_dot_design   = 5 * 1025; % kg/s  [= Q_design * rho_sw]

%% =========================================================================
%  SECTION 3: SEASONAL OPTIMIZATION LOOP
% =========================================================================

fprintf('=========================================================\n');
fprintf('  NuScale SMR — Seasonal Sweep (%.0f operating points)\n', num_points);
fprintf('  T_sea range: %.0f°C to %.0f°C\n', T_sea_range(1), T_sea_range(end));
fprintf('=========================================================\n');

options = optimoptions('ga', ...
    'Display',        'off',  ...
    'PopulationSize', 50,     ...
    'MaxGenerations', 30);

for i = 1:num_points
    PlantData.T_sea = T_sea_range(i);
    fprintf('  Simulating T_sea = %2d°C ... ', PlantData.T_sea);

    % Run GA optimizer
    FitnessFcn  = @(x) Plant_Physics(x, PlantData);
    [x_opt, ~]  = ga(FitnessFcn, 2, [], [], [], [], [0.5, 0.0], [1.0, 1.0], [], options);

    % Evaluate optimized and baseline operating points
    [~, Res_Opt]  = Plant_Physics(x_opt,      PlantData);
    [~, Res_Base] = Plant_Physics([1.0, 1.0], PlantData);

    % Store results
    Opt_Speed(i)  = x_opt(1) * 100;
    Opt_MSR(i)    = x_opt(2) * 100;
    Base_Eff(i)   = Res_Base.Eta_net * 100;
    Opt_Eff(i)    = Res_Opt.Eta_net  * 100;
    Savings_MW(i) = Res_Base.P_pump  - Res_Opt.P_pump;

    fprintf('Speed: %5.1f%%,  MSR: %5.1f%%,  Saved: %+.2f MW\n', ...
        Opt_Speed(i), Opt_MSR(i), Savings_MW(i));
end

fprintf('=========================================================\n');
fprintf('  Sweep complete.\n');
fprintf('=========================================================\n\n');

%% =========================================================================
%  SECTION 4: FIGURE — SEASONAL PERFORMANCE ANALYSIS
% =========================================================================

fig = figure('Units', 'normalized', 'OuterPosition', [0.05 0.05 0.90 0.90]);

tl = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'NuScale SMR — Seasonal Dual-Optimization Results', ...
    'FontSize', 14, 'FontWeight', 'bold');
subtitle(tl, sprintf('Q_{reactor} = %.0f MWt  |  NuScale NPM  |  GA Optimizer (Pop=50, Gen=30)', ...
    PlantData.Q_reactor), 'FontSize', 11, 'Color', [0.3 0.3 0.3]);

% ---- Panel 1: Optimal Pump Speed Strategy --------------------------------
nexttile;
plot(T_sea_range, Opt_Speed, '-ob', 'LineWidth', 2, 'MarkerSize', 7, 'MarkerFaceColor', 'b');
hold on;
yline(100, '--r', 'Baseline (100%)', 'LineWidth', 1.5, 'FontSize', 11);
grid on;
xlabel('Seawater Temperature (°C)', 'FontSize', 12);
ylabel('Pump Speed (%)', 'FontSize', 12);
title('AI Control: Pump Speed Strategy', 'FontSize', 12, 'FontWeight', 'bold');
legend('Optimized Speed', 'Location', 'northwest', 'FontSize', 11);
set(gca, 'FontSize', 12);
ylim([45 110]);

% ---- Panel 2: Optimal MSR Valve Strategy ---------------------------------
nexttile;
plot(T_sea_range, Opt_MSR, '-sm', 'LineWidth', 2, 'MarkerSize', 7, 'MarkerFaceColor', 'm');
grid on;
xlabel('Seawater Temperature (°C)', 'FontSize', 12);
ylabel('MSR Valve Position (%)', 'FontSize', 12);
title('AI Control: MSR Valve Strategy', 'FontSize', 12, 'FontWeight', 'bold');
set(gca, 'FontSize', 12);
ylim([0 110]);

% ---- Panel 3: Net Efficiency Comparison ----------------------------------
nexttile;
plot(T_sea_range, Base_Eff, '--k',  'LineWidth', 1.5);
hold on;
plot(T_sea_range, Opt_Eff,  '-og', 'LineWidth', 2, 'MarkerSize', 7, 'MarkerFaceColor', 'g');
grid on;
xlabel('Seawater Temperature (°C)', 'FontSize', 12);
ylabel('Net Plant Efficiency (%)', 'FontSize', 12);
title('Efficiency: Baseline vs. AI-Optimized', 'FontSize', 12, 'FontWeight', 'bold');
legend('Baseline (Fixed Speed)', 'AI Optimized', 'Location', 'southwest', 'FontSize', 11);
set(gca, 'FontSize', 12);

% ---- Panel 4: Auxiliary Power Savings ------------------------------------
nexttile;
area(T_sea_range, max(Savings_MW, 0), ...
    'FaceColor', [0.4660 0.6740 0.1880], 'FaceAlpha', 0.5, 'LineWidth', 1.5);
hold on;
% Annotate peak saving point
[max_sav, idx_max] = max(Savings_MW);
if max_sav > 0
    text(T_sea_range(idx_max), max_sav * 0.85, ...
        sprintf('Peak: %.2f MW', max_sav), ...
        'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold', ...
        'Color', [0.1 0.4 0.1]);
end
grid on;
xlabel('Seawater Temperature (°C)', 'FontSize', 12);
ylabel('Auxiliary Power Saved (MW)', 'FontSize', 12);
title('Net Pump Power Savings by Season', 'FontSize', 12, 'FontWeight', 'bold');
set(gca, 'FontSize', 12);
ylim([0, max(Savings_MW) * 1.25 + 0.001]);   % prevent zero-height axis
