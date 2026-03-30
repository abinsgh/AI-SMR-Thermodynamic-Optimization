function [Cost, Results] = Plant_Physics(x, PlantData)
    % x(1) = Pump Speed Ratio [0.5 - 1.0]
    % x(2) = MSR Valve Position [0.0 - 1.0]
    
    %% 1. Unpack Inputs
    N_ratio = x(1);
    MSR_Valve = x(2); 
    
    %% 2. Hydraulic & Pump Model
    num = (PlantData.H_shutoff * N_ratio^2) - PlantData.H_static;
    den = (PlantData.A_pump + PlantData.k_sys);
    
    Q_squared = max(num / den, 0);
    Q_cw = sqrt(Q_squared);
    m_dot_cw = Q_cw * PlantData.rho_sw; 
    
    H_op = PlantData.H_static + PlantData.k_sys * Q_squared;
    
    P_hyd = (PlantData.rho_sw * 9.81 * Q_cw * H_op) / 1e6; % MW
    P_pump = P_hyd / (PlantData.eta_pump * PlantData.eta_motor);
    
    %% 3. Condenser Model
    Flow_Ratio = max(m_dot_cw / PlantData.m_dot_design, 0.01);
    U_curr = PlantData.U_design * (Flow_Ratio)^0.6;
    
    Load_Factor = PlantData.m_dot_steam / 110.0; 
    Q_cond_Actual = PlantData.Q_cond_design * Load_Factor; 
    
    LMTD = (Q_cond_Actual * 1000) / (U_curr * PlantData.Area_cond); 
    Cp_sw = 3.99; % kJ/kg.K
    
    if m_dot_cw > 0.1
        Delta_T_Range = (Q_cond_Actual * 1000) / (m_dot_cw * Cp_sw);
    else
        Delta_T_Range = 100; % Penalty for low flow
    end
    
    T_out = PlantData.T_sea + Delta_T_Range;
    T_sat_cond = PlantData.T_sea + LMTD + (Delta_T_Range / 2); 
    
    try
        P_cond = XSteam('psat_T', T_sat_cond);
    catch
        P_cond = 1.0; 
    end
    
    % Choking Limit
    if P_cond < PlantData.P_choke
        P_cond = PlantData.P_choke;
        try
            T_sat_cond = XSteam('Tsat_p', P_cond);
        catch
            T_sat_cond = 29.0; 
        end
    end
    
    %% 4. Turbine & MSR Model
    h_main = XSteam('h_pT', PlantData.P_main, PlantData.T_main);
    s_main = XSteam('s_pT', PlantData.P_main, PlantData.T_main);
    
    h_HPT_out_ideal = XSteam('h_ps', PlantData.P_reheat, s_main);
    h_HPT_out = h_main - PlantData.eta_turb * (h_main - h_HPT_out_ideal);
    
    W_HPT = PlantData.m_dot_steam * (h_main - h_HPT_out) / 1000; 
    
    T_sat_reheat = XSteam('Tsat_p', PlantData.P_reheat);
    T_hot_reheat_max = 260; 
    
    T_LPT_in = T_sat_reheat + MSR_Valve * (T_hot_reheat_max - T_sat_reheat);
    h_LPT_in = XSteam('h_pT', PlantData.P_reheat, T_LPT_in);
    
    h_live_condensate = XSteam('hL_p', PlantData.P_main); 
    Heat_Source = h_main - h_live_condensate;
    Heat_Sink   = h_LPT_in - h_HPT_out;
    
    y = min(Heat_Sink / (Heat_Source + Heat_Sink), 0.15); 
    
    m_dot_LPT = PlantData.m_dot_steam * (1 - y);
    s_LPT_in = XSteam('s_pT', PlantData.P_reheat, T_LPT_in);
    
    h_LPT_out_ideal = XSteam('h_ps', P_cond, s_LPT_in);
    h_LPT_out = h_LPT_in - PlantData.eta_turb * (h_LPT_in - h_LPT_out_ideal);
    
    W_LPT = m_dot_LPT * (h_LPT_in - h_LPT_out) / 1000; 
    
    %% 5. Cost Function & Constraints
    W_Total_Turbine = W_HPT + W_LPT;
    W_Net = W_Total_Turbine - P_pump; 
    Eta_net = W_Net / PlantData.Q_reactor;
    
    % Objective: Maximize net power
    Cost = -1 * W_Net; 
    
    % Operational constraints
    if P_cond > 0.10
        Cost = Cost + (P_cond - 0.10) * 10000; % Backpressure limit
    end
    
    if N_ratio < 0.5
        Cost = Cost + 1000; % Stall protection
    end
    
    if Delta_T_Range > 15
        Cost = Cost + (Delta_T_Range - 15) * 100; % Environmental limit
    end
    
    %% 6. Results
    if nargout > 1
        Results.P_pump = P_pump;
        Results.P_cond = P_cond;
        Results.T_cond = T_sat_cond; 
        Results.T_out  = T_out;      
        Results.W_turb = W_Total_Turbine;
        Results.W_net  = W_Net;       
        Results.Eta_net = Eta_net;
        Results.Extraction_y = y;
        Results.Q_cw = Q_cw;         
    end
end
