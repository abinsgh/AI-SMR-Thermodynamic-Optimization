% =========================================================================
% PROJECT: NuScale SMR — Auxiliary Power Optimization using Genetic Algorithms
% TEAM MEMBERS: Ahmed Saeed Alghamdi, Faisal Saeed Bahadi, Ahmed Saud Alsalahi
% SUPERVISED BY: Dr. Anas Alwafi
% =========================================================================
%
% FILE: PWR_Dashboard_exported.m
%
% PURPOSE:
%   SCADA-style Intelligent Control Room Dashboard for the NuScale SMR
%   (250 MWt). Runs a full GA seasonal optimization sweep on startup, then
%   provides real-time interpolated readouts as the operator adjusts the
%   seawater temperature slider. All visuals use a dark high-contrast theme
%   consistent with nuclear control room design practice.
%
% LAYOUT OVERVIEW:
%   ┌─────────────────────────────────────────────────────────┐
%   │  STATUS BAR  — Title + Team Credits                     │
%   ├──────────────┬──────────────────────────────────────────┤
%   │  LEFT        │  GAUGE PANEL                             │
%   │  SIDEBAR     │  [ P_cond ] [ P_pump ] [ W_Net ] [LAMP] │
%   │              ├──────────────────────────────────────────┤
%   │  T_sea       │  Ax_Control     │  Ax_Gain               │
%   │  SLIDER      │  Speed + Valve  │  Eff + Power Saved     │
%   │              │  vs T_sea       │  vs T_sea              │
%   │  COMPARISON  │                 │                        │
%   │  PANEL       │                 │                        │
%   └──────────────┴─────────────────┴────────────────────────┘
%
% DEPENDENCIES:
%   Plant_Physics.m, XSteam.m, MATLAB Global Optimization Toolbox
% =========================================================================

classdef PWR_Dashboard_exported < matlab.apps.AppBase

    % =====================================================================
    % UI Component Properties
    % =====================================================================
    properties (Access = public)
        UIFigure            matlab.ui.Figure

        % Status bar
        TitleLabel          matlab.ui.control.Label
        CreditsLabel        matlab.ui.control.Label

        % Left sidebar — temperature control
        TempValueLabel      matlab.ui.control.Label
        TempSlider          matlab.ui.control.Slider
        RunBtn              matlab.ui.control.Button

        % Left sidebar — comparison panel labels
        Lbl_Base_Power      matlab.ui.control.Label
        Lbl_Base_Eff        matlab.ui.control.Label
        Lbl_Base_Pump       matlab.ui.control.Label
        Lbl_Opt_Power       matlab.ui.control.Label
        Lbl_Opt_Eff         matlab.ui.control.Label
        Lbl_Opt_Pump        matlab.ui.control.Label
        Lbl_Gain_Eff        matlab.ui.control.Label
        Lbl_Gain_Power      matlab.ui.control.Label

        % Gauges
        GaugePres           matlab.ui.control.LinearGauge
        GaugePresLabel      matlab.ui.control.Label
        GaugePump           matlab.ui.control.NinetyDegreeGauge
        GaugePumpLabel      matlab.ui.control.Label
        GaugeNet            matlab.ui.control.SemicircularGauge
        GaugeNetLabel       matlab.ui.control.Label

        % Status lamp
        StatusLamp          matlab.ui.control.Lamp
        StatusLampLabel     matlab.ui.control.Label

        % Plot axes
        Ax_Control          matlab.ui.control.UIAxes
        Ax_Gain             matlab.ui.control.UIAxes
    end

    % =====================================================================
    % Private Data Properties
    % =====================================================================
    properties (Access = private)
        % Seasonal sweep result vectors (indexed over T_range)
        T_range             % Temperature sweep points              [degC]
        Speed_Data          % Optimal pump speed                    [%]
        Valve_Data          % Optimal MSR valve position            [%]
        Eff_Base_Data       % Baseline cycle efficiency             [%]
        Eff_Opt_Data        % AI-optimized cycle efficiency         [%]
        Power_Save_Data     % Auxiliary pump power savings          [MW]
        W_Net_Base_Data     % Baseline net electrical output        [MW]
        W_Net_Opt_Data      % AI-optimized net electrical output    [MW]
        P_cond_Data         % Condenser saturation pressure         [bar]
        P_pump_Base_Data    % Baseline pump shaft power             [MW]
        P_pump_Opt_Data     % AI-optimized pump shaft power         [MW]

        % Interactive redline handles on both axes
        hLine_Control       % Vertical marker on Ax_Control
        hLine_Gain          % Vertical marker on Ax_Gain
    end

    % =====================================================================
    % Private Utility Methods
    % =====================================================================
    methods (Access = private)

        % -----------------------------------------------------------------
        % buildPlantData: Returns a fully populated NuScale SMR parameter
        % struct, consistent with Plant_Physics.m and Run_Optimization.m.
        % -----------------------------------------------------------------
        function P = buildPlantData(~)
            % [VENDOR SPEC] NuScale FSAR Ch.4 & Ch.10
            P.Q_reactor_base = 250;      % Rated thermal output       [MWt]
            P.Q_cond_design  = 170;      % Condenser heat rejection   [MWt]
            P.m_dot_steam    = 110;      % Rated steam mass flow      [kg/s]
            P.P_main         = 60;       % HP turbine inlet pressure  [bar]
            P.T_main         = 275;      % HP turbine inlet temp      [degC]
            P.P_reheat       = 10;       % Cold-reheat pressure       [bar]
            P.eta_turb       = 0.92;     % Isentropic efficiency      [-]
            P.P_choke        = 0.04;     % LP choking limit           [bar]
            % [ENGINEERING ASSUMP] Hydraulic circuit & condenser
            P.Q_design       = 5;        % Design cooling flow        [m^3/s]
            P.H_static       = 8;        % Static circuit head        [m]
            P.H_shutoff      = 20;       % Pump shut-off head         [m]
            P.k_sys          = 0.05;     % System resistance coeff    [m/(m^3/s)^2]
            P.A_pump         = 0.002;    % Pump curve shape factor    [m/(m^3/s)^2]
            P.eta_pump       = 0.85;     % Pump hydraulic efficiency  [-]
            P.eta_motor      = 0.94;     % Motor efficiency           [-]
            P.rho_sw         = 1025;     % Seawater density           [kg/m^3]
            P.Area_cond      = 4500;     % Condenser HX area          [m^2]
            P.U_design       = 2.8;      % Design overall HTC         [kW/(m^2·K)]
            P.m_dot_design   = 5 * 1025; % Design cooling mass flow   [kg/s]
            % Operating point fields (overridden in sweep loop)
            P.T_sea          = 25;
            P.Q_reactor      = 250;
            P.m_dot_steam    = 110;
        end

        % -----------------------------------------------------------------
        % runSeasonalSweep: Executes the GA optimization at each point in
        % T_range (10:5:40 degC). Populates all data arrays. Displays a
        % progress dialog during the sweep.
        % -----------------------------------------------------------------
        function runSeasonalSweep(app)
            d = uiprogressdlg(app.UIFigure, ...
                'Title',   'NuScale SMR — AI Initialization', ...
                'Message', 'Running GA seasonal sweep...', ...
                'Indeterminate', 'off');

            PlantData    = buildPlantData(app);
            app.T_range  = 10 : 5 : 40;   % 7 evaluation points [degC]
            n            = numel(app.T_range);

            % Pre-allocate all result arrays
            app.Speed_Data       = zeros(1, n);
            app.Valve_Data       = zeros(1, n);
            app.Eff_Base_Data    = zeros(1, n);
            app.Eff_Opt_Data     = zeros(1, n);
            app.Power_Save_Data  = zeros(1, n);
            app.W_Net_Base_Data  = zeros(1, n);
            app.W_Net_Opt_Data   = zeros(1, n);
            app.P_cond_Data      = zeros(1, n);
            app.P_pump_Base_Data = zeros(1, n);
            app.P_pump_Opt_Data  = zeros(1, n);

            % GA configuration — matches Run_Optimization.m
            opts = optimoptions('ga', ...
                'Display',        'off', ...
                'PopulationSize', 50,    ...
                'MaxGenerations', 25);

            for i = 1 : n
                d.Value   = i / n;
                d.Message = sprintf('Optimizing T_sea = %.0f °C  (%d / %d)', ...
                    app.T_range(i), i, n);

                PlantData.T_sea       = app.T_range(i);
                PlantData.Q_reactor   = 250;   % Full power [MWt]
                PlantData.m_dot_steam = 110;   % Full steam flow [kg/s]

                % Run genetic algorithm
                FitnessFcn = @(x) Plant_Physics(x, PlantData);
                [x_opt, ~] = ga(FitnessFcn, 2, [], [], [], [], ...
                    [0.5 0.0], [1.0 1.0], [], opts);

                % Evaluate optimized and baseline operating points
                [~, R_opt]  = Plant_Physics(x_opt,      PlantData);
                [~, R_base] = Plant_Physics([1.0 1.0],  PlantData);

                % Store results
                app.Speed_Data(i)       = x_opt(1) * 100;                      % [%]
                app.Valve_Data(i)       = x_opt(2) * 100;                      % [%]
                app.Eff_Base_Data(i)    = R_base.Eta_net * 100;                % [%]
                app.Eff_Opt_Data(i)     = R_opt.Eta_net  * 100;                % [%]
                app.P_cond_Data(i)      = R_opt.P_cond;                        % [bar]
                app.P_pump_Base_Data(i) = R_base.P_pump;                       % [MW]
                app.P_pump_Opt_Data(i)  = R_opt.P_pump;                        % [MW]
                app.W_Net_Base_Data(i)  = R_base.W_turb - R_base.P_pump;      % [MW]
                app.W_Net_Opt_Data(i)   = R_opt.W_turb  - R_opt.P_pump;       % [MW]
                app.Power_Save_Data(i)  = max(R_base.P_pump - R_opt.P_pump, 0); % [MW]
            end

            close(d);
        end

        % -----------------------------------------------------------------
        % renderStaticPlots: Draws the full sweep curves on both axes.
        % Called once after runSeasonalSweep and again after re-run.
        % -----------------------------------------------------------------
        function renderStaticPlots(app)
            T  = app.T_range;
            T0 = app.TempSlider.Value;

            % ---- Ax_Control: Pump Speed + MSR Valve vs T_sea ------------
            cla(app.Ax_Control);
            hold(app.Ax_Control, 'on');

            plot(app.Ax_Control, T, app.Speed_Data, '-o', ...
                'Color', [0.00 0.85 1.00], 'LineWidth', 2.0, ...
                'MarkerFaceColor', [0.00 0.85 1.00], 'MarkerSize', 6);

            plot(app.Ax_Control, T, app.Valve_Data, '-s', ...
                'Color', [1.00 0.55 0.00], 'LineWidth', 2.0, ...
                'MarkerFaceColor', [1.00 0.55 0.00], 'MarkerSize', 6);

            app.hLine_Control = xline(app.Ax_Control, T0, ...
                '--', 'Color', [1.00 0.20 0.20], 'LineWidth', 1.5);

            legend(app.Ax_Control, {'Pump Speed [%]', 'MSR Valve [%]'}, ...
                'TextColor', [0.75 0.75 0.75], ...
                'Color',     [0.10 0.11 0.14], ...
                'EdgeColor', [0.30 0.32 0.38], ...
                'FontSize',  9);

            ylim(app.Ax_Control, [0 110]);
            xlim(app.Ax_Control, [min(T)-1  max(T)+1]);

            % ---- Ax_Gain: Efficiency (left) + Power Saved (right) -------
            cla(app.Ax_Gain);

            yyaxis(app.Ax_Gain, 'left');
            hold(app.Ax_Gain, 'on');

            plot(app.Ax_Gain, T, app.Eff_Base_Data, '--', ...
                'Color', [0.65 0.65 0.65], 'LineWidth', 1.5);

            plot(app.Ax_Gain, T, app.Eff_Opt_Data, '-o', ...
                'Color', [0.00 0.90 0.35], 'LineWidth', 2.0, ...
                'MarkerFaceColor', [0.00 0.90 0.35], 'MarkerSize', 6);

            app.Ax_Gain.YAxis(1).Color = [0.00 0.90 0.35];
            ylabel(app.Ax_Gain, 'Net Efficiency  [%]', ...
                'Color', [0.00 0.90 0.35], 'FontSize', 10);

            yyaxis(app.Ax_Gain, 'right');
            area(app.Ax_Gain, T, app.Power_Save_Data, ...
                'FaceColor', [1.00 0.85 0.00], 'FaceAlpha', 0.30, ...
                'EdgeColor', [1.00 0.85 0.00], 'LineWidth', 1.5);

            app.Ax_Gain.YAxis(2).Color = [1.00 0.85 0.00];
            ylabel(app.Ax_Gain, 'Auxiliary Power Saved  [MW]', ...
                'Color', [1.00 0.85 0.00], 'FontSize', 10);

            % Add redline on top (switch back to left to keep it on foreground)
            yyaxis(app.Ax_Gain, 'left');
            app.hLine_Gain = xline(app.Ax_Gain, T0, ...
                '--', 'Color', [1.00 0.20 0.20], 'LineWidth', 1.5);

            xlim(app.Ax_Gain, [min(T)-1  max(T)+1]);

            legend(app.Ax_Gain, ...
                {'Baseline Eff [%]', 'Optimized Eff [%]', 'Power Saved [MW]'}, ...
                'TextColor', [0.75 0.75 0.75], ...
                'Color',     [0.10 0.11 0.14], ...
                'EdgeColor', [0.30 0.32 0.38], ...
                'FontSize',  9);
        end

        % -----------------------------------------------------------------
        % updateDashboard: Interpolates all simulation data at T_val and
        % pushes results to every live component on the dashboard.
        % -----------------------------------------------------------------
        function updateDashboard(app, T_val)
            T = app.T_range;

            % Clamp T_val to sweep range to avoid extrapolation artifacts
            T_val = max(min(T_val, max(T)), min(T));

            % Interpolate all state variables at T_val
            spd        = interp1(T, app.Speed_Data,       T_val, 'linear');
            valve      = interp1(T, app.Valve_Data,       T_val, 'linear');
            p_cond     = interp1(T, app.P_cond_Data,      T_val, 'linear');
            p_pump_opt = interp1(T, app.P_pump_Opt_Data,  T_val, 'linear');
            p_pump_base= interp1(T, app.P_pump_Base_Data, T_val, 'linear');
            w_net_opt  = interp1(T, app.W_Net_Opt_Data,   T_val, 'linear');
            w_net_base = interp1(T, app.W_Net_Base_Data,  T_val, 'linear');
            eff_opt    = interp1(T, app.Eff_Opt_Data,     T_val, 'linear');
            eff_base   = interp1(T, app.Eff_Base_Data,    T_val, 'linear');
            pwr_save   = max(p_pump_base - p_pump_opt, 0);
            eff_gain   = eff_opt - eff_base;

            % ---- Temperature display ------------------------------------
            app.TempValueLabel.Text = sprintf('T_{sea} = %.1f °C', T_val);

            % ---- Gauges -------------------------------------------------
            app.GaugePres.Value = max(min(p_cond,    0.15),  0);
            app.GaugePump.Value = max(min(p_pump_opt, 10.0), 0);
            app.GaugeNet.Value  = max(min(w_net_opt, 100.0), 0);

            % ---- Status Lamp --------------------------------------------
            if p_cond >= 0.095
                app.StatusLamp.Color      = [1.00 0.15 0.15];
                app.StatusLampLabel.Text      = 'PRESSURE ALARM';
                app.StatusLampLabel.FontColor = [1.00 0.15 0.15];
            elseif p_cond >= 0.080
                app.StatusLamp.Color      = [1.00 0.65 0.00];
                app.StatusLampLabel.Text      = 'CAUTION';
                app.StatusLampLabel.FontColor = [1.00 0.65 0.00];
            else
                app.StatusLamp.Color      = [0.00 0.90 0.35];
                app.StatusLampLabel.Text      = 'SAFE';
                app.StatusLampLabel.FontColor = [0.00 0.90 0.35];
            end

            % ---- Comparison Panel — Baseline ----------------------------
            app.Lbl_Base_Power.Text = sprintf('%.2f MW',  w_net_base);
            app.Lbl_Base_Eff.Text   = sprintf('%.3f %%',  eff_base);
            app.Lbl_Base_Pump.Text  = sprintf('%.3f MW',  p_pump_base);

            % ---- Comparison Panel — AI Optimized ------------------------
            app.Lbl_Opt_Power.Text  = sprintf('%.2f MW',  w_net_opt);
            app.Lbl_Opt_Eff.Text    = sprintf('%.3f %%',  eff_opt);
            app.Lbl_Opt_Pump.Text   = sprintf('%.3f MW',  p_pump_opt);

            % ---- Net Optimization Gain ----------------------------------
            gainColor = [0.00 0.90 0.35];     % green = improvement
            if eff_gain <= 0
                gainColor = [1.00 0.35 0.35]; % red = degradation
            end
            app.Lbl_Gain_Eff.Text       = sprintf('%+.4f %%',   eff_gain);
            app.Lbl_Gain_Power.Text     = sprintf('%+.2f kW',   pwr_save * 1000);
            app.Lbl_Gain_Eff.FontColor  = gainColor;
            app.Lbl_Gain_Power.FontColor= gainColor;

            % ---- Move synchronized redlines on both axes ----------------
            try
                app.hLine_Control.Value = T_val;
                app.hLine_Gain.Value    = T_val;
            catch
                % Handles not yet created (first call before renderStaticPlots)
            end
        end

    end

    % =====================================================================
    % Callbacks
    % =====================================================================
    methods (Access = private)

        % App startup: run sweep → render plots → initialize to 25 °C
        function startupFcn(app)
            % Set app icon if available
            [scriptPath, ~, ~] = fileparts(which(mfilename));
            iconFile = fullfile(scriptPath, 'Assets', 'Nuclear_symbol.svg.png');
            if isfile(iconFile)
                app.UIFigure.Icon = iconFile;
            end

            % Run full GA seasonal sweep (shows progress dialog)
            runSeasonalSweep(app);

            % Render static plot curves on both axes
            renderStaticPlots(app);

            % Initialize dashboard at default temperature (25 °C)
            updateDashboard(app, 25.0);
        end

        % Fires continuously as slider is dragged — updates redlines & readout
        function TempSliderValueChanging(app, event)
            app.TempValueLabel.Text = sprintf('T_{sea} = %.1f °C', event.Value);
            try
                app.hLine_Control.Value = event.Value;
                app.hLine_Gain.Value    = event.Value;
            catch
            end
        end

        % Fires when slider is released — full dashboard refresh
        function TempSliderValueChanged(app, event)
            updateDashboard(app, app.TempSlider.Value);
        end

        % Re-run optimization button: repeats full sweep then refreshes
        function RunBtnPushed(app, event)
            runSeasonalSweep(app);
            renderStaticPlots(app);
            updateDashboard(app, app.TempSlider.Value);
        end

    end

    % =====================================================================
    % Component Initialization
    % =====================================================================
    methods (Access = private)

        function createComponents(app)

            % Define shared theme colors as local variables for readability
            BG_DARK   = [0.10 0.11 0.14];   % Figure / axes background
            BG_PANEL  = [0.14 0.15 0.19];   % Panel backgrounds
            BG_STATUS = [0.06 0.08 0.12];   % Status bar background
            CLR_CYAN  = [0.00 0.85 1.00];   % Primary label / title color
            CLR_GREY  = [0.60 0.65 0.70];   % Secondary text color
            CLR_DIM   = [0.40 0.43 0.48];   % Tertiary / separator color

            % ==============================================================
            %  MAIN FIGURE
            % ==============================================================
            app.UIFigure                = uifigure('Visible', 'off');
            app.UIFigure.Position       = [40 40 1340 820];
            app.UIFigure.Name           = 'NuScale SMR — Intelligent Optimization Module';
            app.UIFigure.Color          = BG_DARK;
            app.UIFigure.Resize         = 'off';

            % ==============================================================
            %  MAIN GRID  3 rows × 2 cols
            %    Row 1 : Status bar (full width)
            %    Row 2 : Gauge panel
            %    Row 3 : Plots panel
            %    Col 1 : Left sidebar (spans rows 2–3)
            %    Col 2 : Gauges + Plots
            % ==============================================================
            mainGrid = uigridlayout(app.UIFigure, [3 2]);
            mainGrid.RowHeight    = {62, 250, '1x'};
            mainGrid.ColumnWidth  = {270, '1x'};
            mainGrid.BackgroundColor = BG_DARK;
            mainGrid.Padding      = [6 6 6 6];
            mainGrid.RowSpacing   = 6;
            mainGrid.ColumnSpacing= 6;

            % ==============================================================
            %  ROW 1 — STATUS BAR (spans both columns)
            % ==============================================================
            statusPanel = uipanel(mainGrid);
            statusPanel.Layout.Row    = 1;
            statusPanel.Layout.Column = [1 2];
            statusPanel.BackgroundColor = BG_STATUS;
            statusPanel.BorderType    = 'none';

            statusGrid = uigridlayout(statusPanel, [2 1]);
            statusGrid.RowHeight      = {'1x', 20};
            statusGrid.BackgroundColor= BG_STATUS;
            statusGrid.Padding        = [12 6 12 4];
            statusGrid.RowSpacing     = 2;

            app.TitleLabel = uilabel(statusGrid);
            app.TitleLabel.Layout.Row = 1;
            app.TitleLabel.Text       = 'NUSCALE SMR  MODULE-1   |   AUXILIARY POWER OPTIMIZATION MODULE';
            app.TitleLabel.FontSize   = 17;
            app.TitleLabel.FontWeight = 'bold';
            app.TitleLabel.FontColor  = CLR_CYAN;
            app.TitleLabel.HorizontalAlignment = 'center';

            app.CreditsLabel = uilabel(statusGrid);
            app.CreditsLabel.Layout.Row = 2;
            app.CreditsLabel.Text       = ['Team: A. Alghamdi  ·  F. Bahadi  ·  A. Alsalahi' ...
                '   |   Supervised By: Dr. A. Alwafi   |   King Abdulaziz University — NE499 (2026)'];
            app.CreditsLabel.FontSize   = 10;
            app.CreditsLabel.FontColor  = CLR_DIM;
            app.CreditsLabel.HorizontalAlignment = 'center';

            % ==============================================================
            %  COLUMN 1 — LEFT SIDEBAR (spans rows 2–3)
            % ==============================================================
            sideGrid = uigridlayout(mainGrid, [2 1]);
            sideGrid.Layout.Row    = [2 3];
            sideGrid.Layout.Column = 1;
            sideGrid.RowHeight     = {215, '1x'};
            sideGrid.BackgroundColor = BG_DARK;
            sideGrid.Padding       = [0 0 0 0];
            sideGrid.RowSpacing    = 6;

            % ---- Slider Section -----------------------------------------
            sliderPanel = uipanel(sideGrid);
            sliderPanel.Layout.Row    = 1;
            sliderPanel.BackgroundColor = BG_PANEL;
            sliderPanel.BorderType    = 'none';

            slGrid = uigridlayout(sliderPanel, [6 1]);
            slGrid.RowHeight      = {16, 42, 8, 55, 16, 38};
            slGrid.BackgroundColor= BG_PANEL;
            slGrid.Padding        = [14 10 14 10];
            slGrid.RowSpacing     = 4;

            lbl_ctrl = uilabel(slGrid);
            lbl_ctrl.Layout.Row = 1;
            lbl_ctrl.Text       = 'SYSTEM HEAT SINK CONTROL  [ T_sea ]';
            lbl_ctrl.FontSize   = 9;
            lbl_ctrl.FontWeight = 'bold';
            lbl_ctrl.FontColor  = CLR_GREY;
            lbl_ctrl.HorizontalAlignment = 'center';

            app.TempValueLabel = uilabel(slGrid);
            app.TempValueLabel.Layout.Row = 2;
            app.TempValueLabel.Text       = 'T_{sea} = 25.0 °C';
            app.TempValueLabel.FontSize   = 20;
            app.TempValueLabel.FontWeight = 'bold';
            app.TempValueLabel.FontColor  = CLR_CYAN;
            app.TempValueLabel.HorizontalAlignment = 'center';

            spacer1 = uilabel(slGrid);          % visual spacer
            spacer1.Layout.Row = 3;
            spacer1.Text = '';

            app.TempSlider = uislider(slGrid);
            app.TempSlider.Layout.Row    = 4;
            app.TempSlider.Limits        = [10 40];
            app.TempSlider.Value         = 25;
            app.TempSlider.MajorTicks    = [10 15 20 25 30 35 40];
            app.TempSlider.MajorTickLabels = {'10','15','20','25','30','35','40'};
            app.TempSlider.MinorTicks    = [];
            app.TempSlider.FontColor     = CLR_GREY;
            app.TempSlider.FontSize      = 9;
            app.TempSlider.ValueChangedFcn   = createCallbackFcn(app, @TempSliderValueChanged,   true);
            app.TempSlider.ValueChangingFcn  = createCallbackFcn(app, @TempSliderValueChanging,  true);

            lbl_unit = uilabel(slGrid);
            lbl_unit.Layout.Row = 5;
            lbl_unit.Text       = 'Seawater Inlet Temperature  [°C]';
            lbl_unit.FontSize   = 9;
            lbl_unit.FontColor  = CLR_DIM;
            lbl_unit.HorizontalAlignment = 'center';

            app.RunBtn = uibutton(slGrid, 'push');
            app.RunBtn.Layout.Row        = 6;
            app.RunBtn.Text              = 'RE-RUN AI OPTIMIZATION';
            app.RunBtn.FontSize          = 10;
            app.RunBtn.FontWeight        = 'bold';
            app.RunBtn.BackgroundColor   = [0.05 0.28 0.42];
            app.RunBtn.FontColor         = CLR_CYAN;
            app.RunBtn.ButtonPushedFcn   = createCallbackFcn(app, @RunBtnPushed, true);

            % ---- Comparison Panel ---------------------------------------
            compPanel = uipanel(sideGrid);
            compPanel.Layout.Row    = 2;
            compPanel.BackgroundColor = BG_PANEL;
            compPanel.BorderType    = 'none';

            cpGrid = uigridlayout(compPanel, [12 3]);
            cpGrid.RowHeight      = {18, 16, 28, 28, 28, 8, 18, 18, 28, 28, 8, '1x'};
            cpGrid.ColumnWidth    = {'fit', '1x', '1x'};
            cpGrid.BackgroundColor= BG_PANEL;
            cpGrid.Padding        = [10 8 10 8];
            cpGrid.RowSpacing     = 2;
            cpGrid.ColumnSpacing  = 4;

            % Header
            h = uilabel(cpGrid); h.Layout.Row = 1; h.Layout.Column = [1 3];
            h.Text = 'PERFORMANCE COMPARISON'; h.FontSize = 10;
            h.FontWeight = 'bold'; h.FontColor = CLR_CYAN;
            h.HorizontalAlignment = 'center';

            % Column sub-headers
            uilabel(cpGrid); % empty [2,1]
            lbh = uilabel(cpGrid); lbh.Layout.Row = 2; lbh.Layout.Column = 2;
            lbh.Text = 'BASELINE'; lbh.FontSize = 9; lbh.FontWeight = 'bold';
            lbh.FontColor = [0.65 0.65 0.65]; lbh.HorizontalAlignment = 'center';
            loh = uilabel(cpGrid); loh.Layout.Row = 2; loh.Layout.Column = 3;
            loh.Text = 'AI OPTIMIZED'; loh.FontSize = 9; loh.FontWeight = 'bold';
            loh.FontColor = [0.00 0.80 0.35]; loh.HorizontalAlignment = 'center';

            % Row helper: create metric label in column 1
            function lbl = mkMetric(parent, grid, row, txt)
                lbl = uilabel(grid);
                lbl.Layout.Row = row; lbl.Layout.Column = 1;
                lbl.Text = txt; lbl.FontSize = 9;
                lbl.FontColor = [0.55 0.58 0.62];
                lbl.HorizontalAlignment = 'right';
            end

            function lbl = mkVal(parent, grid, row, col)
                lbl = uilabel(grid);
                lbl.Layout.Row = row; lbl.Layout.Column = col;
                lbl.Text = '---'; lbl.FontSize = 12;
                lbl.FontWeight = 'bold'; lbl.FontColor = [0.85 0.87 0.90];
                lbl.HorizontalAlignment = 'center';
            end

            mkMetric(compPanel, cpGrid, 3, 'Net Power');
            app.Lbl_Base_Power = mkVal(compPanel, cpGrid, 3, 2);
            app.Lbl_Opt_Power  = mkVal(compPanel, cpGrid, 3, 3);
            app.Lbl_Opt_Power.FontColor = [0.00 0.90 0.35];

            mkMetric(compPanel, cpGrid, 4, 'Efficiency');
            app.Lbl_Base_Eff   = mkVal(compPanel, cpGrid, 4, 2);
            app.Lbl_Opt_Eff    = mkVal(compPanel, cpGrid, 4, 3);
            app.Lbl_Opt_Eff.FontColor = [0.00 0.90 0.35];

            mkMetric(compPanel, cpGrid, 5, 'Pump Load');
            app.Lbl_Base_Pump  = mkVal(compPanel, cpGrid, 5, 2);
            app.Lbl_Opt_Pump   = mkVal(compPanel, cpGrid, 5, 3);
            app.Lbl_Opt_Pump.FontColor = [1.00 0.65 0.00];

            % Separator row (row 6 = 8px, no content)

            gh = uilabel(cpGrid); gh.Layout.Row = 7; gh.Layout.Column = [1 3];
            gh.Text = 'NET OPTIMIZATION GAIN'; gh.FontSize = 10;
            gh.FontWeight = 'bold'; gh.FontColor = CLR_CYAN;
            gh.HorizontalAlignment = 'center';

            mkMetric(compPanel, cpGrid, 8, '');
            gain_col2 = uilabel(cpGrid); gain_col2.Layout.Row = 8; gain_col2.Layout.Column = 2;
            gain_col2.Text = 'Eff. Delta'; gain_col2.FontSize = 9;
            gain_col2.FontColor = CLR_DIM; gain_col2.HorizontalAlignment = 'center';
            gain_col3 = uilabel(cpGrid); gain_col3.Layout.Row = 8; gain_col3.Layout.Column = 3;
            gain_col3.Text = 'Saved Power'; gain_col3.FontSize = 9;
            gain_col3.FontColor = CLR_DIM; gain_col3.HorizontalAlignment = 'center';

            mkMetric(compPanel, cpGrid, 9, '');
            app.Lbl_Gain_Eff   = mkVal(compPanel, cpGrid, 9, 2);
            app.Lbl_Gain_Eff.FontColor = [0.00 0.90 0.35];
            app.Lbl_Gain_Power = mkVal(compPanel, cpGrid, 9, 3);
            app.Lbl_Gain_Power.FontColor = [0.00 0.90 0.35];

            % ==============================================================
            %  ROW 2, COL 2 — GAUGE PANEL
            % ==============================================================
            gaugePanel = uipanel(mainGrid);
            gaugePanel.Layout.Row    = 2;
            gaugePanel.Layout.Column = 2;
            gaugePanel.BackgroundColor = BG_PANEL;
            gaugePanel.BorderType    = 'none';

            gGrid = uigridlayout(gaugePanel, [2 4]);
            gGrid.RowHeight      = {'1x', 26};
            gGrid.ColumnWidth    = {'1x', '1x', '1x', 80};
            gGrid.BackgroundColor= BG_PANEL;
            gGrid.Padding        = [14 10 14 6];
            gGrid.ColumnSpacing  = 10;
            gGrid.RowSpacing     = 4;

            % ---- Gauge 1: Condenser Pressure (Linear gauge horizontal) --
            app.GaugePres = uigauge(gGrid, 'linear');
            app.GaugePres.Layout.Row    = 1;
            app.GaugePres.Layout.Column = 1;
            app.GaugePres.Limits        = [0.00 0.15];
            app.GaugePres.Value         = 0.05;
            app.GaugePres.Orientation   = 'horizontal';
            app.GaugePres.ScaleColors   = {[0.00 0.80 0.30], [1.00 0.65 0.00], [1.00 0.15 0.15]};
            app.GaugePres.ScaleColorLimits = [0.000 0.080; 0.080 0.095; 0.095 0.150];
            app.GaugePres.FontSize      = 10;
            app.GaugePres.FontColor     = CLR_CYAN;
            app.GaugePres.BackgroundColor = BG_PANEL;
            app.GaugePres.MajorTicks    = [0 0.03 0.06 0.09 0.12 0.15];

            app.GaugePresLabel = uilabel(gGrid);
            app.GaugePresLabel.Layout.Row    = 2;
            app.GaugePresLabel.Layout.Column = 1;
            app.GaugePresLabel.Text    = 'CONDENSER VACUUM  [P_cond, bar]';
            app.GaugePresLabel.FontSize= 9;
            app.GaugePresLabel.FontWeight = 'bold';
            app.GaugePresLabel.FontColor = CLR_GREY;
            app.GaugePresLabel.HorizontalAlignment = 'center';

            % ---- Gauge 2: Pump Power (90-degree gauge) ------------------
            app.GaugePump = uigauge(gGrid, 'ninetydegree');
            app.GaugePump.Layout.Row    = 1;
            app.GaugePump.Layout.Column = 2;
            app.GaugePump.Limits        = [0 10];
            app.GaugePump.Value         = 2;
            app.GaugePump.ScaleColors   = {[0.00 0.80 0.30], [1.00 0.65 0.00], [1.00 0.15 0.15]};
            app.GaugePump.ScaleColorLimits = [0 5; 5 8; 8 10];
            app.GaugePump.FontSize      = 10;
            app.GaugePump.FontColor     = CLR_CYAN;
            app.GaugePump.BackgroundColor = BG_PANEL;

            app.GaugePumpLabel = uilabel(gGrid);
            app.GaugePumpLabel.Layout.Row    = 2;
            app.GaugePumpLabel.Layout.Column = 2;
            app.GaugePumpLabel.Text    = 'CIRCULATING PUMP LOAD  [P_pump, MW]';
            app.GaugePumpLabel.FontSize= 9;
            app.GaugePumpLabel.FontWeight = 'bold';
            app.GaugePumpLabel.FontColor = CLR_GREY;
            app.GaugePumpLabel.HorizontalAlignment = 'center';

            % ---- Gauge 3: Net Plant Power (semicircular gauge) ----------
            app.GaugeNet = uigauge(gGrid, 'semicircular');
            app.GaugeNet.Layout.Row    = 1;
            app.GaugeNet.Layout.Column = 3;
            app.GaugeNet.Limits        = [0 100];
            app.GaugeNet.Value         = 70;
            app.GaugeNet.ScaleColors   = {[1.00 0.15 0.15], [1.00 0.65 0.00], [0.00 0.80 0.30]};
            app.GaugeNet.ScaleColorLimits = [0 50; 50 70; 70 100];
            app.GaugeNet.FontSize      = 10;
            app.GaugeNet.FontColor     = CLR_CYAN;
            app.GaugeNet.BackgroundColor = BG_PANEL;

            app.GaugeNetLabel = uilabel(gGrid);
            app.GaugeNetLabel.Layout.Row    = 2;
            app.GaugeNetLabel.Layout.Column = 3;
            app.GaugeNetLabel.Text    = 'NET GENERATION  [W_Net, MW]';
            app.GaugeNetLabel.FontSize= 9;
            app.GaugeNetLabel.FontWeight = 'bold';
            app.GaugeNetLabel.FontColor = CLR_GREY;
            app.GaugeNetLabel.HorizontalAlignment = 'center';

            % ---- Status Lamp (column 4) ---------------------------------
            lampGrid = uigridlayout(gGrid, [4 1]);
            lampGrid.Layout.Row    = [1 2];
            lampGrid.Layout.Column = 4;
            lampGrid.RowHeight     = {'1x', 36, 30, '1x'};
            lampGrid.BackgroundColor = BG_PANEL;
            lampGrid.Padding       = [4 4 4 4];

            app.StatusLamp = uilamp(lampGrid);
            app.StatusLamp.Layout.Row = 2;
            app.StatusLamp.Color      = [0.00 0.90 0.35];
           % app.StatusLamp.Shape      = 'circle';

            app.StatusLampLabel = uilabel(lampGrid);
            app.StatusLampLabel.Layout.Row = 3;
            app.StatusLampLabel.Text       = 'SAFE';
            app.StatusLampLabel.FontSize   = 9;
            app.StatusLampLabel.FontWeight = 'bold';
            app.StatusLampLabel.FontColor  = [0.00 0.90 0.35];
            app.StatusLampLabel.HorizontalAlignment = 'center';

            % ==============================================================
            %  ROW 3, COL 2 — PLOT PANEL  (2 side-by-side axes)
            % ==============================================================
            plotPanel = uipanel(mainGrid);
            plotPanel.Layout.Row    = 3;
            plotPanel.Layout.Column = 2;
            plotPanel.BackgroundColor = BG_PANEL;
            plotPanel.BorderType    = 'none';

            plotGrid = uigridlayout(plotPanel, [1 2]);
            plotGrid.ColumnWidth    = {'1x', '1x'};
            plotGrid.BackgroundColor= BG_PANEL;
            plotGrid.Padding        = [10 10 10 10];
            plotGrid.ColumnSpacing  = 10;

            % ---- Ax_Control ---------------------------------------------
            app.Ax_Control = uiaxes(plotGrid);
            app.Ax_Control.Layout.Column = 1;
            app.Ax_Control.Color         = BG_DARK;
            app.Ax_Control.XColor        = CLR_GREY;
            app.Ax_Control.YColor        = CLR_GREY;
            app.Ax_Control.GridColor     = [0.25 0.27 0.32];
            app.Ax_Control.GridAlpha     = 0.6;
            app.Ax_Control.XGrid         = 'on';
            app.Ax_Control.YGrid         = 'on';
            app.Ax_Control.Box           = 'on';
            app.Ax_Control.FontSize      = 10;
            title(app.Ax_Control, 'AI CONTROL STRATEGY', ...
                'Color', CLR_CYAN, 'FontSize', 11, 'FontWeight', 'bold');
            xlabel(app.Ax_Control, 'Seawater Temperature  [°C]', ...
                'Color', CLR_GREY, 'FontSize', 10);
            ylabel(app.Ax_Control, 'Control Position  [%]', ...
                'Color', CLR_GREY, 'FontSize', 10);

            % ---- Ax_Gain ------------------------------------------------
            app.Ax_Gain = uiaxes(plotGrid);
            app.Ax_Gain.Layout.Column = 2;
            app.Ax_Gain.Color         = BG_DARK;
            app.Ax_Gain.XColor        = CLR_GREY;
            app.Ax_Gain.GridColor     = [0.25 0.27 0.32];
            app.Ax_Gain.GridAlpha     = 0.6;
            app.Ax_Gain.XGrid         = 'on';
            app.Ax_Gain.YGrid         = 'on';
            app.Ax_Gain.Box           = 'on';
            app.Ax_Gain.FontSize      = 10;
            title(app.Ax_Gain, 'EFFICIENCY & POWER GAIN', ...
                'Color', CLR_CYAN, 'FontSize', 11, 'FontWeight', 'bold');
            xlabel(app.Ax_Gain, 'Seawater Temperature  [°C]', ...
                'Color', CLR_GREY, 'FontSize', 10);

            % Make figure visible once all components are built
            app.UIFigure.Visible = 'on';
        end

    end

    % =====================================================================
    % App Creation and Deletion
    % =====================================================================
    methods (Access = public)

        function app = PWR_Dashboard_exported
           createComponents(app)
            registerApp(app, app.UIFigure)
            runStartupFcn(app, @startupFcn)
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            delete(app.UIFigure)
        end

    end

end
