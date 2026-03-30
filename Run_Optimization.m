%% SMR Rankine Cycle Optimization
clc; clear; close all;

%% 1. Define SMR Plant Data
PlantData.Q_reactor_base = 250;    % MWt
PlantData.Q_cond_design  = 170;    % MWt
PlantData.m_dot_steam    = 110;    % kg/s

PlantData.P_main      = 60;        % bar
PlantData.T_main      = 275;       % degC
PlantData.P_reheat    = 10;        % bar
PlantData.eta_turb    = 0.92;      
PlantData.P_choke     = 0.04;      % bar

PlantData.Q_design    = 5;         % m^3/s
PlantData.H_static    = 8;         % m
PlantData.H_shutoff   = 20;        % m
PlantData.k_sys       = 0.05;      
PlantData.A_pump      = 0.002;     % m^2
PlantData.eta_pump    = 0.85;      
PlantData.eta_motor   = 0.94;
PlantData.rho_sw      = 1025;      
PlantData.Area_cond   = 4500;      % m^2 
PlantData.U_design    = 2.8;       
PlantData.m_dot_design= 5 * 1025;  

%% 2. Simulation Scenario
PlantData.T_sea = 35; % Seasonal seawater temperature (C)
fprintf('Running SMR Optimization for T_sea: %.1f C\n', PlantData.T_sea);

%% 3. Plant Operation Mode
PlantData.Q_reactor = PlantData.Q_reactor_base;
PlantData.m_dot_steam = 110; 

%% 4. Genetic Algorithm Optimization
% Bounds: Pump Speed [0.5 - 1.0], MSR Valve [0.0 - 1.0]
lb = [0.5, 0.0]; 
ub = [1.0, 1.0]; 

options = optimoptions('ga', 'Display', 'iter', 'PopulationSize', 50, 'MaxGenerations', 30);
FitnessFcn = @(x) Plant_Physics(x, PlantData);

fprintf('\nInitializing GA Optimization...\n');
[x_opt, fval] = ga(FitnessFcn, 2, [], [], [], [], lb, ub, [], options);

%% 5. Results Analysis
[~, Res_Opt] = Plant_Physics(x_opt, PlantData);    
[~, Res_Base] = Plant_Physics([1.0, 1.0], PlantData); % Baseline comparison

fprintf('\n--- Optimization Results ---\n');
fprintf('Optimal Pump Speed: %.2f %%\n', x_opt(1)*100);
fprintf('Optimal MSR Valve:  %.2f %%\n', x_opt(2)*100);
fprintf('--------------------------------\n');

Base_Net_Power = Res_Base.W_turb - Res_Base.P_pump;
Opt_Net_Power  = Res_Opt.W_turb - Res_Opt.P_pump;

fprintf('Baseline Net Power: %.2f MW\n', Base_Net_Power);
fprintf('Optimized Net Power: %.2f MW\n', Opt_Net_Power);
fprintf('Efficiency Gain: +%.3f %%\n', (Res_Opt.Eta_net - Res_Base.Eta_net)*100);

Power_Saved_kW = (Res_Base.P_pump - Res_Opt.P_pump) * 1000; 
if Power_Saved_kW > 1
    fprintf('Auxiliary Power Saved: %.1f kW\n', Power_Saved_kW);
else
    fprintf('System at Max Capacity\n');
end

%% 6. Thermodynamics Verification
P_cond_Bar = Res_Opt.P_cond; 
P_mmHg = P_cond_Bar * 750.062;
A = 8.07131; B = 1730.63; C = 233.426;
T_cond_Exact = (B ./ (A - log10(P_mmHg))) - C;

fprintf('--------------------------------\n');
fprintf('Physics Verification:\n');
fprintf(' Condenser Pressure: %.4f bar\n', P_cond_Bar);
fprintf(' Exact Saturation T: %.2f C\n', T_cond_Exact);
fprintf(' Real Flow Rate:     %.2f m^3/s\n', Res_Opt.Q_cw);
fprintf('--------------------------------\n');
