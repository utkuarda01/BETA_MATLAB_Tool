%% BETA_Bandpass_Tool by Utku Arda Akıncı | Alpha | Post SMACD

classdef BETA_Bandpass_Tool_alpha< matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure             matlab.ui.Figure
        GridLayout           matlab.ui.container.GridLayout
        LeftPanel            matlab.ui.container.Panel
        InputGrid            matlab.ui.container.GridLayout
        
        % Inputs
        lblFreq              matlab.ui.control.Label
        efFreq               matlab.ui.control.NumericEditField
        lblOrder             matlab.ui.control.Label
        ddOrder              matlab.ui.control.DropDown
        
        % --- DYNAMIC TRIO (Design Specs) ---
        lblQ                 matlab.ui.control.Label
        efQ                  matlab.ui.control.NumericEditField
        
        lblBW                matlab.ui.control.Label
        efBW                 matlab.ui.control.NumericEditField
        
        lblMinGain           matlab.ui.control.Label 
        efMinGain            matlab.ui.control.NumericEditField 
        
        % --- SIMULATION OVERRIDE ---
        lblOverride          matlab.ui.control.Label
        swOverride           matlab.ui.control.Switch
        
        lblIntGain           matlab.ui.control.Label
        efIntGain            matlab.ui.control.NumericEditField 
        
        % --- CUSTOM TF ---
        lblCustomTF          matlab.ui.control.Label
        swCustomTF           matlab.ui.control.Switch
        lblCustomNum         matlab.ui.control.Label
        efCustomNum          matlab.ui.control.EditField
        lblCustomDen         matlab.ui.control.Label
        efCustomDen          matlab.ui.control.EditField
        lblCustomInt         matlab.ui.control.Label
        efCustomInt          matlab.ui.control.EditField
        
        % --- ACTIONS ---
        btnRun               matlab.ui.control.Button
        btnGenSim            matlab.ui.control.Button 
        btnRunSim            matlab.ui.control.Button
        btnGenVA             matlab.ui.control.Button 
        
        lblStatus            matlab.ui.control.Label
        
        % Outputs (TabGroup)
        TabGroup             matlab.ui.container.TabGroup
        
        % Tab 1: Magnitude
        tMag                 matlab.ui.container.Tab
        gMag                 matlab.ui.container.GridLayout
        axMag                matlab.ui.control.UIAxes       
        axMagWide            matlab.ui.control.UIAxes       
        
        % Tab 2: Phase (Split)
        tPhase               matlab.ui.container.Tab
        gPhase               matlab.ui.container.GridLayout
        axPhase              matlab.ui.control.UIAxes    
        axPhaseSim           matlab.ui.control.UIAxes    
        
        % Tab 3: Pole-Zero (Split)
        tPZ                  matlab.ui.container.Tab
        gPZ                  matlab.ui.container.GridLayout
        axPZ                 matlab.ui.control.UIAxes    
        axPZSim              matlab.ui.control.UIAxes    
        
        % Tab 4: Equations
        tEq                  matlab.ui.container.Tab
        gEq                  matlab.ui.container.GridLayout
        pnlNorm              matlab.ui.container.Panel
        txtNorm              matlab.ui.control.TextArea
        pnlReal              matlab.ui.container.Panel
        txtReal              matlab.ui.control.TextArea

        % Tab 5: Simulink Results
        tSim                 matlab.ui.container.Tab
        gSim                 matlab.ui.container.GridLayout
        axSimTime            matlab.ui.control.UIAxes
        axSimFreq            matlab.ui.control.UIAxes
        axSimWide            matlab.ui.control.UIAxes 

        % Tab 6: Text Log
        tText                matlab.ui.container.Tab
        gText                matlab.ui.container.GridLayout
        txtArea              matlab.ui.control.TextArea
    end

   % Custom Colors & Global Fonts
    properties (Access = private)
        CustomBlue = [0.12, 0.56, 1.00]; 

        % --- ADDED FOR DRAGGABLE SPLITTER ---
        isDragging logical = false;
        SplitterPanel matlab.ui.container.Panel

        % --- GLOBAL FONT SCALERS ---  
        Font_UI_Spacing  = 5;

        % --- GLOBAL FONT SCALERS ---
        Font_UI_Labels   = 16; 
        Font_UI_Controls = 16; 
        Font_Axes_Ticks  = 16; 
        Font_Axes_Labels = 16; 
        Font_Axes_Titles = 16; 
        Font_Annotations = 14; 

        % --- GLOBAL PLOT SCALERS ---
        Plot_Line_Width  = 3; 
        Plot_Marker_Size = 6;  
        
        % --- STATE CACHE ---
        CachedQ double   = 50.0; 
    end

    methods (Access = private)

        % =================================================================
        % UI SPLITTER CALLBACKS
        % =================================================================
        function onStartDrag(app, ~, ~)
            % User clicked the splitter. Set dragging state to true.
            app.isDragging = true;
            % Optional: Change the mouse pointer to indicate dragging
            app.UIFigure.Pointer = 'left'; 
        end

        function onDragSplitter(app, ~, ~)
            % Only execute if the user is actively holding down the splitter
            if app.isDragging
                % Get current mouse position relative to the figure
                currentPos = app.UIFigure.CurrentPoint;
                newWidth = currentPos(1);
                
                % Add boundary limits to prevent the UI from breaking or disappearing
                minWidth = 200; % Minimum width for left panel
                maxWidth = app.UIFigure.Position(3) - 100; % Keep at least 100px for plots
                
                if newWidth >= minWidth && newWidth <= maxWidth
                    % Update the 1st column's width in real-time
                    app.GridLayout.ColumnWidth{1} = newWidth;
                end
            end
        end

        function onStopDrag(app, ~, ~)
            % User released the mouse button. Stop dragging.
            if app.isDragging
                app.isDragging = false;
                app.UIFigure.Pointer = 'arrow'; % Restore default pointer
            end
        end

        % =================================================================
        % HELPERS
        % =================================================================
        
        function applyGlobalFonts(app)
            if isvalid(app.InputGrid)
                uiComps = app.InputGrid.Children;
                for i = 1:length(uiComps)
                    try 
                        if isa(uiComps(i), 'matlab.ui.control.Label')
                            uiComps(i).FontSize = app.Font_UI_Labels;
                        else
                            uiComps(i).FontSize = app.Font_UI_Controls;
                        end
                    catch
                    end
                end
            end
            
            axesList = [app.axMag, app.axMagWide, app.axPhase, app.axPhaseSim, ...
                        app.axPZ, app.axPZSim, app.axSimTime, app.axSimFreq, app.axSimWide];
            for i = 1:length(axesList)
                if isvalid(axesList(i))
                    ax = axesList(i);
                    ax.FontSize = app.Font_Axes_Ticks;       
                    ax.XLabel.FontSize = app.Font_Axes_Labels; 
                    ax.YLabel.FontSize = app.Font_Axes_Labels; 
                    ax.TitleFontSizeMultiplier = app.Font_Axes_Titles / app.Font_Axes_Ticks;
                    ax.Title.FontSize = app.Font_Axes_Titles;  
                    if ~isempty(ax.Legend)
                        ax.Legend.FontSize = app.Font_Axes_Ticks; 
                    end
                end
            end
        end

        function factor = getBWFactor(app)
            ordVal = str2double(app.ddOrder.Value);
            switch ordVal
                case 2, factor = 1.0;
                case 4, factor = 0.648164; 
                case 6, factor = 0.511;
                otherwise, factor = 1.0;
            end
        end

        function G_min = calcMinGain(app, Q_val)
            if Q_val <= 0, G_min = 0; return; end
            A_req = 20 * Q_val;
            g_raw = 20 * log10(A_req);
            G_min = ceil(g_raw * 2) / 2;
        end

        function syncIntegratorGain(app)
            if strcmp(app.swOverride.Value, 'Off')
                app.efIntGain.Value = app.efMinGain.Value;
            end
        end
        
        function updateDenFromQ(app)
            if strcmp(app.swCustomTF.Value, 'On') && str2double(app.ddOrder.Value) == 2
                try
                    den = str2num(app.efCustomDen.Value); %#ok<ST2NM>
                    if length(den) == 3 && den(1) ~= 0
                        Q = app.efQ.Value;
                        d2 = den(1); d0 = den(3);
                        d0_norm = d0 / d2;
                        
                        if isinf(Q) || Q == 0
                            new_d1 = 0;
                        else
                            new_d1 = d2 * (sqrt(d0_norm) / Q);
                        end
                        app.efCustomDen.Value = sprintf('[%g, %g, %g]', d2, new_d1, d0);
                    end
                catch
                end
            end
        end
        
        function [g_res, c_taps] = calcCRFF_Coeffs(~, Order)
            g_res = [1, 1]; c_taps = [0, 0, 0, 0];
            if Order == 2
                c_taps = [0.69, 1.01]; 
                g_res = 1.0; 
            elseif Order == 4
                c_taps = [0.3, 0.9, 0.9, 0.3]; 
                g_res = [1.0, 1.0];
            elseif Order == 6
                g_res = [1.0, 1.0, 1.0];
                c_taps = [0.8, 0.9, 0.9, 0.9, 0.9, 0.8];
            end
        end

        % Math solver for generic 2nd and 4th order topologies
        function [params, isValid, errMsg] = parseCustomTF(app, Order)
            params = struct(); isValid = false; errMsg = '';
            try
                num = str2num(app.efCustomNum.Value); %#ok<ST2NM>
                den = str2num(app.efCustomDen.Value); %#ok<ST2NM>
                ints = str2num(app.efCustomInt.Value); %#ok<ST2NM>
                
                if Order == 2
                    if length(num) ~= 2, error('Numerator must be [n1, n0].'); end
                    if length(den) ~= 3, error('Denominator must be [s^2, s^1, s^0].'); end
                    if length(ints) ~= 2, error('Integrator gains must be [a1, a2].'); end
                    
                    d2 = den(1); d1 = den(2); d0 = den(3);
                    if d2 == 0, error('s^2 coefficient cannot be zero.'); end
                    
                    n1 = num(1)/d2; n0 = num(2)/d2;
                    d1 = d1/d2; d0 = d0/d2;
                    
                    a1 = ints(1); a2 = ints(2);
                    if a1 == 0 || a2 == 0, error('Integrator gains cannot be zero.'); end
                    
                    params.C1 = n1 / a1;
                    params.C3 = n0 / (a1 * a2);
                    params.C2 = -d0 / (a1 * a2);
                    params.K_damp = -d1 / a1;
                    params.a1 = a1; params.a2 = a2;
                    
                elseif Order == 4
                    if length(num) ~= 4, error('Numerator must be [s^3, s^2, s^1, s^0].'); end
                    if length(den) ~= 5, error('Denominator must be [s^4, s^3, s^2, s^1, s^0].'); end
                    if length(ints) ~= 4, error('Integrator gains must be [a1, a2, a3, a4].'); end
                    
                    d4 = den(1);
                    if d4 == 0, error('s^4 coefficient cannot be zero.'); end
                    
                    num = num / d4;
                    den = den / d4;
                    n3 = num(1); n2 = num(2); n1 = num(3); n0 = num(4);
                    
                    a1 = ints(1); a2 = ints(2); a3 = ints(3); a4 = ints(4);
                    if any(ints == 0), error('Integrator gains cannot be zero.'); end
                    
                    try
                        % 1e-4 tolerance protects cplxpair from silently crashing during real-time typing
                        r = cplxpair(roots(den), 1e-4); 
                    catch
                        error('Denominator roots cannot be cleanly factored into real cascaded pairs. Ensure coefficients are mathematically valid real numbers.');
                    end
                    
                    pair1 = r(1:2);
                    pair2 = r(3:4);
                    Q1 = real(poly(pair1)); % s^2 + A*s + B
                    Q2 = real(poly(pair2)); % s^2 + C*s + E
                    
                    A = Q1(2); B = Q1(3);
                    C = Q2(2); E = Q2(3);
                    
                    params.K_damp1 = -A / a1;
                    params.C5 = -B / (a1 * a2);
                    
                    params.K_damp2 = -C / a3;
                    params.C6 = -E / (a3 * a4);
                    
                    params.C1 = n3 / a1;
                    params.C2 = (n2 - params.C1 * a1 * C) / (a1 * a2);
                    params.C3 = (n1 - params.C1 * a1 * E - params.C2 * a1 * a2 * C) / (a1 * a2 * a3);
                    params.C4 = (n0 - params.C2 * a1 * a2 * E) / (a1 * a2 * a3 * a4);
                    
                    params.a1 = a1; params.a2 = a2; params.a3 = a3; params.a4 = a4;
                end
                isValid = true;
            catch ME
                errMsg = ME.message;
            end
        end
        
        function sys = getCRFF_SS(app, Order, w0, Q, A_lin, g_res, c_taps, customParams)
            if nargin < 8, customParams = []; end
            leak_term = w0 / A_lin;  
            damp_term = w0 / Q;     
            
            if Order == 6
                A = zeros(6,6);
                A(1,1) = -leak_term - damp_term; A(1,2) = -g_res(1) * w0; 
                A(2,1) = w0; A(2,2) = -leak_term;
                A(3,2) = w0; A(3,3) = -leak_term - damp_term; A(3,4) = -g_res(2) * w0;
                A(4,3) = w0; A(4,4) = -leak_term;
                A(5,4) = w0; A(5,5) = -leak_term - damp_term; A(5,6) = -g_res(3) * w0;
                A(6,5) = w0; A(6,6) = -leak_term;
                B = [w0; 0; 0; 0; 0; 0]; C = c_taps; D = 0;
                sys = ss(A, B, C, D);
                
            elseif Order == 4
                A = zeros(4,4);
                if ~isempty(customParams)
                    a1 = customParams.a1; a2 = customParams.a2; 
                    a3 = customParams.a3; a4 = customParams.a4;
                    
                    A(1,1) = -leak_term + a1 * w0 * customParams.K_damp1; 
                    A(1,2) = a1 * w0 * customParams.C5;
                    A(2,1) = a2 * w0; 
                    A(2,2) = -leak_term;
                    A(3,2) = a3 * w0; 
                    A(3,3) = -leak_term + a3 * w0 * customParams.K_damp2; 
                    A(3,4) = a3 * w0 * customParams.C6;
                    A(4,3) = a4 * w0; 
                    A(4,4) = -leak_term;
                    
                    B = [a1 * w0; 0; 0; 0];
                    C = [customParams.C1, customParams.C2, customParams.C3, customParams.C4];
                else
                    A(1,1) = -leak_term - damp_term; A(1,2) = -g_res(1) * w0; 
                    A(2,1) = w0; A(2,2) = -leak_term;
                    A(3,2) = w0; A(3,3) = -leak_term - damp_term; A(3,4) = -g_res(2) * w0;
                    A(4,3) = w0; A(4,4) = -leak_term;
                    B = [w0; 0; 0; 0]; 
                    C = c_taps; 
                end
                D = 0;
                sys = ss(A, B, C, D);
                
            elseif Order == 2
                A = zeros(2,2);
                if ~isempty(customParams)
                    a1 = customParams.a1; a2 = customParams.a2;
                    A(1,1) = -leak_term + a1 * w0 * customParams.K_damp; 
                    A(1,2) = a1 * w0 * customParams.C2; 
                    A(2,1) = a2 * w0; 
                    A(2,2) = -leak_term;
                    B = [a1 * w0; 0];
                    C = [customParams.C1, customParams.C3];
                else
                    A(1,1) = -leak_term - damp_term; A(1,2) = -1.0 * w0; 
                    A(2,1) = w0; A(2,2) = -leak_term;
                    B = [w0; 0];
                    C = c_taps; 
                end
                D = 0;
                sys = ss(A, B, C, D);
            else
                sys = tf(1,1);
            end
        end

        function str = formatFreq(~, f_hz)
            % Dynamically format a frequency string with 3 decimal places
            if f_hz == 0
                str = '0.000 Hz';
            elseif f_hz >= 1e9
                str = sprintf('%.3f GHz', f_hz / 1e9);
            elseif f_hz >= 1e6
                str = sprintf('%.3f MHz', f_hz / 1e6);
            elseif f_hz >= 1e3
                str = sprintf('%.3f kHz', f_hz / 1e3);
            else
                str = sprintf('%.3f Hz', f_hz);
            end
        end
        
        function [scale, unit] = getFreqScale(~, f_hz)
            % Determine the best axis scale and unit label based on Center Freq
            if f_hz >= 1e9
                scale = 1e9; unit = 'GHz';
            elseif f_hz >= 1e6
                scale = 1e6; unit = 'MHz';
            elseif f_hz >= 1e3
                scale = 1e3; unit = 'kHz';
            else
                scale = 1; unit = 'Hz';
            end
        end

        % =================================================================
        % CALLBACKS
        % =================================================================

        function onOverrideChanged(app, ~, ~)
            isManual = strcmp(app.swOverride.Value, 'On');
            if isManual
                app.efIntGain.Editable = 'on';
            else
                app.efIntGain.Editable = 'off';
                app.syncIntegratorGain();
            end
            app.efIntGain.BackgroundColor = '#2D2D2D'; 
            app.efIntGain.FontColor = [1 1 1];
        end

        function onCustomTFChanged(app, ~, ~)
            isOn = strcmp(app.swCustomTF.Value, 'On');
            if isOn
                % Capture the current manual target Q before overwritten with an estimation
                app.CachedQ = app.efQ.Value;
                
                app.efCustomNum.Enable = 'on';
                app.efCustomDen.Enable = 'on';
                app.efCustomInt.Enable = 'on';
                
                ordVal = str2double(app.ddOrder.Value);
                if ordVal == 6
                    app.ddOrder.Value = '4'; 
                    ordVal = 4;
                end
                
                % Validate lengths cleanly or load default templates safely
                try
                    n = str2num(app.efCustomNum.Value); %#ok<ST2NM>
                    d = str2num(app.efCustomDen.Value); %#ok<ST2NM>
                    i = str2num(app.efCustomInt.Value); %#ok<ST2NM>
                    if ordVal == 2 && (length(n)~=2 || length(d)~=3 || length(i)~=2), error('reset'); end
                    if ordVal == 4 && (length(n)~=4 || length(d)~=5 || length(i)~=4), error('reset'); end
                catch
                    if ordVal == 2
                        app.efCustomNum.Value = '[0.69, 1.01]';
                        app.efCustomDen.Value = '[1, 0, 1]';
                        app.efCustomInt.Value = '[1, 1]';
                    elseif ordVal == 4
                        app.efCustomNum.Value = '[0.3, 0.9, 1.2, 1.2]';
                        app.efCustomDen.Value = '[1, 0.04, 2.0004, 0.04, 1]';
                        app.efCustomInt.Value = '[1, 1, 1, 1]';
                    end
                end
                
                if ordVal == 2
                    app.lblCustomNum.Text = 'Num [s^1, s^0]';
                    app.lblCustomDen.Text = 'Den [s^2, s^1, s^0]';
                    app.lblCustomInt.Text = 'Int Gains [a1, a2]';
                    app.lblCustomTF.Text = 'Custom TF (2nd)';
                    app.lblQ.Text = 'System Q';
                    
                    app.efQ.Editable = 'on';
                    app.efBW.Editable = 'on';
                    app.efMinGain.Editable = 'on';
                    app.efQ.BackgroundColor = '#2D2D2D';
                    app.efBW.BackgroundColor = '#2D2D2D';
                    app.efMinGain.BackgroundColor = '#2D2D2D';
                    app.updateDenFromQ();
                    
                elseif ordVal == 4
                    app.lblCustomNum.Text = 'Num [s^3..s^0]';
                    app.lblCustomDen.Text = 'Den [s^4..s^0]';
                    app.lblCustomInt.Text = 'Int [a1..a4]';
                    app.lblCustomTF.Text = 'Custom TF (4th)';
                    app.lblQ.Text = 'System Q';
                   
                    app.efQ.Editable = 'off';
                    app.efBW.Editable = 'off';
                    app.efMinGain.Editable = 'off';
                    app.efQ.BackgroundColor = '#404040';
                    app.efBW.BackgroundColor = '#404040';
                    app.efMinGain.BackgroundColor = '#404040';
                    app.onCustomDenChanged([], []);
                end
            else
                app.efCustomNum.Enable = 'off';
                app.efCustomDen.Enable = 'off';
                app.efCustomInt.Enable = 'off';
                app.lblQ.Text = 'Resonator Q';
                
                app.efQ.Editable = 'on';
                app.efBW.Editable = 'on';
                app.efMinGain.Editable = 'on';
                app.efQ.BackgroundColor = '#2D2D2D';
                app.efBW.BackgroundColor = '#2D2D2D';
                app.efMinGain.BackgroundColor = '#2D2D2D';
                
                % Restore the cached target Q and force an immediate resync of symmetric BW
                app.efQ.Value = app.CachedQ;
                app.onQChanged([], []);
            end
        end

        function onCustomDenChanged(app, ~, event)
            ordVal = str2double(app.ddOrder.Value);
            isCustom4th = false;
            try
                % Check if event is from ValueChanging (real-time typing)
                if nargin > 2 && ~isempty(event) && isprop(event, 'Value')
                    den_str = event.Value;
                else
                    den_str = app.efCustomDen.Value;
                end
                
                den = str2num(den_str); %#ok<ST2NM>
                
                if ordVal == 2 && length(den) == 3 && den(1) ~= 0
                    d2 = den(1); d1 = den(2); d0 = den(3);
                    d1_norm = d1 / d2;
                    d0_norm = d0 / d2;
                    if d1_norm == 0, new_Q = inf; else, new_Q = sqrt(d0_norm) / d1_norm; end
                    
                elseif ordVal == 4 && length(den) == 5 && den(1) ~= 0
                    d4 = den(1);
                    den_norm = den / d4;
                    
                    % 1e-4 tolerance protects cplxpair from silently crashing during real-time typing
                    r = cplxpair(roots(den_norm), 1e-4); 
                    Q1_poly = real(poly(r(1:2)));
                    Q2_poly = real(poly(r(3:4)));
                    
                    A = Q1_poly(2); B = Q1_poly(3);
                    C = Q2_poly(2); E = Q2_poly(3);
                    
                    if A == 0, q1 = inf; else, q1 = sqrt(B) / A; end
                    if C == 0, q2 = inf; else, q2 = sqrt(E) / C; end
                    
                    if isinf(q1) || isinf(q2)
                        new_Q = inf;
                    else
                        new_Q = sqrt(q1 * q2); % Geometric Mean for peak gain estimation (I think this might be wrong)
                    end
                    isCustom4th = true;
                else
                    return;
                end
                
                % Update as long as it's a number (even if negative/unstable)
                if ~isnan(new_Q) 
                    f0 = app.efFreq.Value;
                    
                    if f0 > 0
                         % 1. Calculate true physical System Bandwidth and true System Q

                        if isCustom4th && ~isinf(new_Q)
                            % Stagger-tuned geometric mean natively reflects physical bandwidth
                            true_sys_q = new_Q;
                            bw_hz = f0 / true_sys_q; 
                        else
                            factor = app.getBWFactor();
                            bw_hz = (f0 / new_Q) * factor;
                        
                            if factor == 1.0
                                true_sys_q = new_Q;
                            else
                                true_sys_q = f0 / bw_hz;
                            end
                        end
                        
                        % 2. Apply updates
                        if app.efQ.Value ~= round(true_sys_q, 3) || isCustom4th
                            app.efQ.Value = round(true_sys_q, 3);
                            app.efBW.Value = round(bw_hz / 1e6, 6); 
                            
                            % DC Gain must support the underlying physical Resonator Q (new_Q)
                            new_G = app.calcMinGain(new_Q);
                            app.efMinGain.Value = new_G;
                            app.syncIntegratorGain();
                        end
                    end
                end
            catch
                % Silently wait for the user to finish typing a valid array
            end
        end

        function onOrderChanged(app, ~, ~)
            ordVal = str2double(app.ddOrder.Value);
            if strcmp(app.swCustomTF.Value, 'On')
                if ordVal == 6
                    app.swCustomTF.Value = 'Off';
                    app.onCustomTFChanged();
                else
                    if ordVal == 2
                        app.lblCustomNum.Text = 'Num [s^1, s^0]';
                        app.lblCustomDen.Text = 'Den [s^2, s^1, s^0]';
                        app.lblCustomInt.Text = 'Int Gains [a1, a2]';
                        app.lblCustomTF.Text = 'Custom TF (2nd)';
                        app.lblQ.Text = 'System Q';
                        app.efCustomNum.Value = '[0.69, 1.01]';
                        app.efCustomDen.Value = '[1, 0, 1]';
                        app.efCustomInt.Value = '[1, 1]';
                        
                        app.efQ.Editable = 'on';
                        app.efBW.Editable = 'on';
                        app.efMinGain.Editable = 'on';
                        app.efQ.BackgroundColor = '#2D2D2D';
                        app.efBW.BackgroundColor = '#2D2D2D';
                        app.efMinGain.BackgroundColor = '#2D2D2D';
                        app.updateDenFromQ();
                        
                    elseif ordVal == 4
                        app.lblCustomNum.Text = 'Num [s^3..s^0]';
                        app.lblCustomDen.Text = 'Den [s^4..s^0]';
                        app.lblCustomInt.Text = 'Int [a1..a4]';
                        app.lblCustomTF.Text = 'Custom TF (4th)';
                        app.lblQ.Text = 'System Q';
                        app.efCustomNum.Value = '[0.3, 0.9, 1.2, 1.2]';
                        app.efCustomDen.Value = '[1, 0.04, 2.0004, 0.04, 1]';
                        app.efCustomInt.Value = '[1, 1, 1, 1]';
                        
                        % Fully locked Read-Only mode
                        app.efQ.Editable = 'off';
                        app.efBW.Editable = 'off';
                        app.efMinGain.Editable = 'off';
                        app.efQ.BackgroundColor = '#404040';
                        app.efBW.BackgroundColor = '#404040';
                        app.efMinGain.BackgroundColor = '#404040';
                        app.onCustomDenChanged([], []);
                    end
                end
            end
            app.onQChanged(); 
        end

        function onFreqChanged(app, ~, ~)
            if str2double(app.ddOrder.Value) == 4 && strcmp(app.swCustomTF.Value, 'On')
                % Intercept freq change to accurately recalculate asymmetric BW
                app.onCustomDenChanged([], []); 
            else
                app.onQChanged();
            end
        end

        function onBWChanged(app, ~, ~)
            bw_mhz = app.efBW.Value;
            bw_hz = bw_mhz * 1e6;
            f0 = app.efFreq.Value;
            factor = app.getBWFactor();
            if bw_hz > 0 && f0 > 0
                new_Q = round((f0 / bw_hz) * factor, 3);
                app.efQ.Value = new_Q;
                new_G = app.calcMinGain(new_Q);
                app.efMinGain.Value = new_G;
                app.syncIntegratorGain();
                app.updateDenFromQ(); 
            end
        end

        function onQChanged(app, ~, ~)
            Q = app.efQ.Value;
            f0 = app.efFreq.Value;
            factor = app.getBWFactor();
            if Q > 0 && f0 > 0
                bw_hz = (f0 / Q) * factor;
                app.efBW.Value = round(bw_hz / 1e6, 6);
                new_G = app.calcMinGain(Q);
                app.efMinGain.Value = new_G;
                app.syncIntegratorGain();
                app.updateDenFromQ(); 
            end
        end
        
        function onMinGainChanged(app, ~, ~)
            G_db = app.efMinGain.Value;
            f0 = app.efFreq.Value;
            factor = app.getBWFactor();
            A_vol = 10^(G_db/20);
            new_Q = round(A_vol / 20, 3); 
            if new_Q > 0
                app.efQ.Value = new_Q;
                if f0 > 0
                    bw_hz = (f0 / new_Q) * factor;
                    app.efBW.Value = round(bw_hz / 1e6, 6);
                end
                app.syncIntegratorGain();
                app.updateDenFromQ(); 
            end
        end

        % =================================================================
        % BUTTONS
        % =================================================================

        function onRunButton(app, ~, ~)
            app.lblStatus.Text = 'Starting Analysis...';
            app.lblStatus.FontColor = [0.85 0.5 0]; 
            drawnow;
            
            f0 = app.efFreq.Value;
            Q_input = app.efQ.Value;
            BW_target_hz = app.efBW.Value * 1e6; 
            
            % Safety Net: If BW reads as 0, calculate true BW to prevent NaN crashes
            if BW_target_hz <= 0
                factor = app.getBWFactor();
                BW_target_hz = (f0 / Q_input) * factor;
            end
            
            Order = str2double(app.ddOrder.Value);
            w0 = 2 * pi * f0;
            
            SimGainDB = app.efIntGain.Value;
            A_vol_sim = 10^(SimGainDB/20);
            
            app.txtArea.Value = {'Initializing analysis...', ''};
            
            % --- DYNAMIC Q STRING FOR LOG ---
            if strcmp(app.swCustomTF.Value, 'On') && Order == 4
                try
                    den_val = str2num(app.efCustomDen.Value); %#ok<ST2NM>
                    d4 = den_val(1);
                    r = cplxpair(roots(den_val / d4), 1e-4);
                    Q1_poly = real(poly(r(1:2))); Q2_poly = real(poly(r(3:4)));
                    A = Q1_poly(2); B = Q1_poly(3); C = Q2_poly(2); E = Q2_poly(3);
                    if A == 0, q1 = inf; else, q1 = sqrt(B) / A; end
                    if C == 0, q2 = inf; else, q2 = sqrt(E) / C; end
                    q_log_str = sprintf('System Q: %.1f (Res1 Q: %.1f, Res2 Q: %.1f)', Q_input, q1, q2);
                catch
                    q_log_str = sprintf('System Q: %.1f', Q_input);
                end
            elseif strcmp(app.swCustomTF.Value, 'On') && Order == 2
                q_log_str = sprintf('System Q: %.1f', Q_input);
            else
                q_log_str = sprintf('Resonator Q: %.1f', Q_input);
            end

            app.txtArea.Value = [app.txtArea.Value; ...
                q_log_str; ...
                sprintf('Min Rec. Gain (20x): %.1f dB', app.efMinGain.Value); ...
                '--------------------------------'; ...
                sprintf('Actual Integrator Gain: %.1f dB', SimGainDB)];
            
            if strcmp(app.swOverride.Value, 'On')
                app.txtArea.Value = [app.txtArea.Value; '(Manual Override Active)'];
            end
            
            Q_crash_limit = A_vol_sim / 2;
            if Q_input > Q_crash_limit
                app.txtArea.Value = [app.txtArea.Value; ...
                    ''; 'CRITICAL: Target Q exceeds stability limit of Integrator!'; ...
                    'Filter will be UNSTABLE in simulation.'];
            elseif Q_input > (A_vol_sim / 20)
                app.txtArea.Value = [app.txtArea.Value; ...
                    ''; 'WARNING: Integrator Gain is low relative to Target Q.'; ...
                    'Expect bandwidth widening (Q-droop).'];
            else
                app.txtArea.Value = [app.txtArea.Value; ''; 'PASS: Integrator Gain is sufficient.'];
            end
            app.txtArea.Value = [app.txtArea.Value; ''];
            
            app.lblStatus.Text = 'Computing...';
            drawnow;

            % --- EXTRACT CUSTOM PARAMETERS ---
            customParams = [];
            if strcmp(app.swCustomTF.Value, 'On') && (Order == 2 || Order == 4)
                [customParams, isValid, errMsg] = app.parseCustomTF(Order);
                if ~isValid
                    app.lblStatus.Text = 'Analysis Failed';
                    app.txtArea.Value = [app.txtArea.Value; errMsg];
                    uialert(app.UIFigure, errMsg, 'Custom TF Error');
                    return;
                end
                num_val = str2num(app.efCustomNum.Value); %#ok<ST2NM>
                den_val = str2num(app.efCustomDen.Value); %#ok<ST2NM>
                H_Normalized = tf(num_val, den_val); %#ok<NASGU>
            else
                if Order == 6
                    num_norm = [0.8, 0.9, 0.9, 0.9, 0.9, 0.8];
                    den_norm = [1, 0, 3, 0, 3, 0, 1];
                    H_Normalized = tf(num_norm, den_norm); %#ok<NASGU>
                elseif Order == 4
                    num_norm = [0.3, 0.9, 1.2, 1.2];
                    den_norm = [1, 0, 2, 0, 1];
                    H_Normalized = tf(num_norm, den_norm); %#ok<NASGU>
                else
                    Stages = struct('coeffs', {});
                    Stages(1).coeffs = [0.00, 0.69, 1.01];
                    H_Normalized = app.constructTF(Stages, 1, inf, 0); %#ok<NASGU>
                end
            end
            
            try
                rawStr = evalc('H_Normalized');
                normStr = regexprep(rawStr, '<[^>]*>', '');
                % Strip out the standard Model Properties text
                normStr = regexprep(normStr, 'Continuous-time transfer function\.\s*Model Properties', '');
                
                % Un-wrap terms by eating trailing spaces, newlines, and leading spaces
                normStr = regexprep(normStr, '[ \t]*\r?\n[ \t]*([+-]\s)', ' $1');

                % Eat the empty trailing lines
                normStr = deblank(normStr);
            catch
                normStr = 'Error capturing TF display.';
            end
            
            % Generate the Tap Information String
            tapStr = '';
            if Order == 2
                if strcmp(app.swCustomTF.Value, 'On')
                    C1 = customParams.C1; C3 = customParams.C3; C2 = customParams.C2; Kdamp = customParams.K_damp;
                else
                    C1 = 0.69; C3 = 1.01; C2 = -1; Kdamp = -1/Q_input;
                end
                tapStr = sprintf('\n\n--- 2nd Order Tap Coefficients ---\nC1 (BP Feedforward) : %.4f\nC3 (LP Feedforward) : %.4f\nC2 (Resonant FB)    : %.4f\nKdamp (Damping FB)  : %.4f', C1, C3, C2, Kdamp);
            elseif Order == 4
                if strcmp(app.swCustomTF.Value, 'On')
                    C1 = customParams.C1; C2 = customParams.C2; C3 = customParams.C3; C4 = customParams.C4;
                    C5 = customParams.C5; C6 = customParams.C6;
                    Kdamp1 = customParams.K_damp1; Kdamp2 = customParams.K_damp2;
                else
                    [g_res, c_taps] = app.calcCRFF_Coeffs(4);
                    C1 = c_taps(1); C2 = c_taps(2); C3 = c_taps(3); C4 = c_taps(4);
                    C5 = -g_res(1); C6 = -g_res(2);
                    Kdamp1 = -1/Q_input; Kdamp2 = -1/Q_input;
                end
                tapStr = sprintf('\n\n--- 4th Order Tap Coefficients ---\nC1 (Tap 1) : %.4f\nC2 (Tap 2) : %.4f\nC3 (Tap 3) : %.4f\nC4 (Tap 4) : %.4f\nC5 (Resonator 1 FB) : %.4f\nC6 (Resonator 2 FB) : %.4f\nKdamp1 (Resonator 1 Damping Factor) : %.4f\nKdamp2 (Resonator 2 Damping Factor) : %.4f', C1, C2, C3, C4, C5, C6, Kdamp1, Kdamp2);
            end

            app.txtNorm.Value = [normStr, tapStr];

            % 2. CONSTRUCT REALISTIC MODEL
            [g_res, c_taps] = app.calcCRFF_Coeffs(Order);
            sys_real = app.getCRFF_SS(Order, w0, Q_input, A_vol_sim, g_res, c_taps, customParams);
            H_Actual = sys_real; 

            try
                H_Real_TF = tf(H_Actual); %#ok<NASGU>
                rawStr = evalc('H_Real_TF'); 
                realStr = regexprep(rawStr, '<[^>]*>', '');
                % Strip out the standard Model Properties text
                realStr = regexprep(realStr, 'Continuous-time transfer function\.\s*Model Properties', '');
                
                % Un-wrap terms by eating trailing spaces, newlines, and leading spaces
                realStr = regexprep(realStr, '[ \t]*\r?\n[ \t]*([+-]\s)', ' $1');

                % Eat the empty trailing lines
                realStr = deblank(realStr);
            catch ME
                realStr = sprintf('Error capturing TF:\n%s', ME.message);
            end
            
            app.txtReal.Value = [realStr, tapStr];

            % 3. PLOTTING
            poles_sys = pole(H_Actual);
            is_stable = all(real(poles_sys) < 0);
            if is_stable
                stab_str = 'System is STABLE (Realized)';
                stab_col = [0 0.8 0]; 
            else
                stab_str = 'System is UNSTABLE';
                stab_col = [1 0 0]; 
            end
            app.txtArea.Value = [app.txtArea.Value; '=== POLE CHECK (Realized) ==='; stab_str; ''];

            % --- DYNAMIC PASSBAND TRACKING ---
            % Find true resonant peak from system poles to track Custom TF shifts
            p_sys = pole(H_Actual);
            p_cplx = p_sys(imag(p_sys) > 0);
            if ~isempty(p_cplx)
                f_plot_center = exp(mean(log(abs(p_cplx) / (2*pi)))); % Geometric mean of resonant peaks (Might be wrong)
            else
                f_plot_center = f0;
            end

            half_span_raw = 3.5 * BW_target_hz; 
            round_step = 10^floor(log10(BW_target_hz)); 
            f_start_clean = floor((f_plot_center - half_span_raw)/round_step) * round_step;
            f_stop_clean  = ceil((f_plot_center + half_span_raw)/round_step) * round_step;
            
            % Safety floor
            if f_start_clean <= 0, f_start_clean = max(f_plot_center * 0.05, round_step); end
            
            freqs = linspace(f_start_clean, f_stop_clean, 50000); 
            w_sweep = 2 * pi * freqs;
            [mag, phase, ~] = bode(H_Actual, w_sweep);
            mag_db = 20*log10(squeeze(mag));
            phase_deg = squeeze(phase);
            
            % Determine the dynamic scale for the plots based on f0
            [fScale, fUnit] = app.getFreqScale(f0);

            cla(app.axMag);
            plot(app.axMag, freqs/fScale, mag_db, 'Color', app.CustomBlue, 'LineWidth', app.Plot_Line_Width);
            hold(app.axMag, 'on');
            xline(app.axMag, f0/fScale, 'm--', 'Label', 'f0','FontSize', app.Font_Annotations, 'FontWeight', 'bold');
            [max_val, max_idx] = max(mag_db);
            target_3db = max_val - 3;
            yline(app.axMag, target_3db, 'r--', 'Label', '-3dB','FontSize', app.Font_Annotations, 'FontWeight', 'bold');
            idx_L = find(mag_db(1:max_idx) >= target_3db, 1, 'first');
            idx_R = find(mag_db(max_idx:end) <= target_3db, 1, 'first');
            bw_meas = 0;
            if ~isempty(idx_L) && ~isempty(idx_R)
                y1 = mag_db(idx_L-1); y2 = mag_db(idx_L);
                x1 = freqs(idx_L-1); x2 = freqs(idx_L);
                f_L = x1 + (target_3db - y1) * (x2 - x1) / (y2 - y1);
                y1 = mag_db(max_idx + idx_R - 2); y2 = mag_db(max_idx + idx_R - 1);
                x1 = freqs(max_idx + idx_R - 2); x2 = freqs(max_idx + idx_R - 1);
                f_H = x1 + (target_3db - y1) * (x2 - x1) / (y2 - y1);
                bw_meas = f_H - f_L;
                plot(app.axMag, [f_L, f_H]/fScale, [target_3db, target_3db], 'ro', 'MarkerFaceColor','r', 'MarkerSize', app.Plot_Marker_Size);
            end
            xlim(app.axMag, [f_start_clean/fScale, f_stop_clean/fScale]);
            grid(app.axMag, 'on'); 
            title(app.axMag, sprintf('Zoomed Magnitude (Peak=%.2fdB, BW_{meas}=%s, Q_{meas}=%.2f)', max_val, app.formatFreq(bw_meas), f0/bw_meas));
            xlabel(app.axMag, sprintf('Frequency (%s)', fUnit)); ylabel(app.axMag, 'Gain (dB)');
            hold(app.axMag, 'off');
            
            % Dynamic tracking for the Wideband Plot bounds
            f_lower_raw = f_plot_center / 100;
            f_lower_decade = 10^ceil(log10(f_lower_raw));
            f_upper_raw = f_plot_center * 100;
            f_upper_decade = 10^floor(log10(f_upper_raw));
            if f_lower_decade >= f_upper_decade, f_lower_decade = f_plot_center/100; f_upper_decade = f_plot_center*100; end
            
            % Hybrid Coarse/Dense sweep ensuring passband isn't missed
            f_coarse = logspace(log10(f_lower_decade), log10(f_upper_decade), 500);
            f_dense  = linspace(f_start_clean, f_stop_clean, 1500);
            freqs_wide = unique(sort([f_coarse, f_dense]));
            
            w_sweep_wide = 2 * pi * freqs_wide;
            [mag_wide, ~, ~] = bode(H_Actual, w_sweep_wide);
            mag_db_wide = 20*log10(squeeze(mag_wide));
            
            cla(app.axMagWide);
            semilogx(app.axMagWide, freqs_wide, mag_db_wide, 'Color', app.CustomBlue, 'LineWidth', app.Plot_Line_Width);
            hold(app.axMagWide, 'on');
            xline(app.axMagWide, f0, 'm--', 'Label', 'f0','FontSize', app.Font_Annotations, 'FontWeight', 'bold');
            
            w_new = (f_stop_clean - f_start_clean) * 1.2;
            h_new = (max(mag_db) - min(mag_db)) * 1.2; 
            % Safety net for completely flat responses
            if w_new <= 0, w_new = 1e-6; end
            if h_new <= 0, h_new = 1e-6; end
            
            rectangle(app.axMagWide, 'Position', [f_start_clean, min(mag_db), w_new, h_new], ...
                'EdgeColor', 'r', 'LineStyle', '--', 'LineWidth', 1.0);
            grid(app.axMagWide, 'on'); 
            title(app.axMagWide, 'Wideband Response');
            xlabel(app.axMagWide, 'Frequency (Hz)'); ylabel(app.axMagWide, 'Gain (dB)');
            hold(app.axMagWide, 'off');

            cla(app.axPhase);
            plot(app.axPhase, freqs/fScale, phase_deg, 'Color', app.CustomBlue, 'LineWidth', app.Plot_Line_Width);
            grid(app.axPhase, 'on'); 
            xline(app.axPhase, f0/fScale, 'm--', 'Label', 'f0','FontSize', app.Font_Annotations, 'FontWeight', 'bold');
            title(app.axPhase, 'Phase Response');
            xlabel(app.axPhase, sprintf('Frequency (%s)', fUnit)); ylabel(app.axPhase, 'Phase (deg)');

            cla(app.axPZ);
            p = pole(H_Actual);
            z = tzero(H_Actual);
            plot(app.axPZ, real(p), imag(p), 'x', 'MarkerSize', app.Plot_Marker_Size, 'LineWidth', app.Plot_Line_Width, 'Color', 'r');
            hold(app.axPZ, 'on');
            if ~isempty(z)
                plot(app.axPZ, real(z), imag(z), 'o', 'MarkerSize', app.Plot_Marker_Size, 'LineWidth', app.Plot_Line_Width, 'Color', app.CustomBlue);
            end
            grid(app.axPZ, 'on'); 
            
            xl = xlim(app.axPZ); yl = ylim(app.axPZ);
            x_txt = xl(1) + 0.05 * (xl(2)-xl(1));
            y_txt = yl(2) - 0.1 * (yl(2)-yl(1));
            text(app.axPZ, x_txt, y_txt, stab_str, 'Color', stab_col, ...             
                'BackgroundColor', 'black', 'EdgeColor', 'white', ...          
                'FontSize', app.Font_Annotations, 'FontWeight', 'bold');
            title(app.axPZ, 'Pole-Zero Map');
            xlabel(app.axPZ, 'Real Axis (seconds^{-1})'); 
            ylabel(app.axPZ, 'Imag Axis (rad/s)');
            hold(app.axPZ, 'off');
            
            app.txtArea.Value = [app.txtArea.Value; ...
                ''; ...
                sprintf('Measured Bandwidth: %s', app.formatFreq(bw_meas)); ...
                sprintf('Measured System Q : %.2f', f0/bw_meas); ...
                'Analysis Complete.'];
            
            app.TabGroup.SelectedTab = app.tMag;
            app.lblStatus.Text = 'Analysis Finished!';
            app.lblStatus.FontColor = [0 0.6 0]; 
            
            app.applyGlobalFonts();
            drawnow;
        end
        
        % =================================================================
        % GENERATE VERILOG-A & UNIFIED SKILL SCRIPT WITH SYMBOL GENERATOR
        % =================================================================
        function onGenVerilogA(app, ~, ~)
            if strcmp(app.swOverride.Value, 'On')
                target_gain_db = app.efIntGain.Value;
                mode_str = 'Manual Input';
            else
                target_gain_db = app.efMinGain.Value;
                mode_str = 'Min DC Gain';
            end
            A_lin = 10^(target_gain_db/20);
            Order = str2double(app.ddOrder.Value);
            f0 = app.efFreq.Value;
            Q_input = app.efQ.Value; %Unused, but could be put into the .va code

            % -------------------------------------------------------------
            % 1. Generate & Save the Base Integrator (integratorA.va)
            % -------------------------------------------------------------
            va_code = [ ...
                '// VerilogA for integratorA, veriloga' newline ...
                '`include "disciplines.vams"' newline ...
                '`include "constants.vams"' newline ...
                newline ...
                'module integratorA(Vip, Vin, Vout_a1p, Vout_a1n, Vout_b1p, Vout_b1n, Vout_c1p, Vout_c1n, VDD, VSS);' newline ...
                '    inout Vip, Vin, Vout_a1p, Vout_a1n, Vout_b1p, Vout_b1n, Vout_c1p, Vout_c1n, VDD, VSS;' newline ...
                '    electrical Vip, Vin, Vout_a1p, Vout_a1n, Vout_b1p, Vout_b1n, Vout_c1p, Vout_c1n, VDD, VSS;' newline ...
                newline ...
                '    // --- Parameters ---' newline ...
                '    parameter real ugf = 64.0e6 from (0:10T);' newline ...
                '    parameter real gain_coeff_b = 1.0;     // Applies to output B (Feedback)' newline ...
                '    parameter real gain_coeff_c = 2.0;     // Applies to output C (Feedforward)' newline ...
                '    parameter real q_tun = 10T from (0:10T); // Q-Factor (10T defaults to structural damping)' newline ...
                newline ...
                '    // --- Finite Gain (Parasitic) ---' newline ...
                sprintf('    // Source: %s (%.1f dB)\n', mode_str, target_gain_db) ...
                sprintf('    parameter real dc_gain = %.5e from (0:10T);\n', A_lin) ...
                newline ...
                '    parameter real rin = 1.0;' newline ...
                '    parameter real rout = 100.0e9;' newline ...
                newline ...
                '    // --- Variables ---' newline ...
                '    real tau, i_in_val, i_processed, out_a_val, out_b_val, out_c_val, damping_tot;' newline ...
                '    real num[0:0];' newline ...
                '    real den[0:1];' newline ...
                newline ...
                '    analog begin' newline ...
                '        tau = 1.0 / (`M_TWO_PI * ugf);' newline ...
                '        I(Vip, Vin) <+ V(Vip, Vin) / rin;' newline ...
                '        i_in_val = V(Vip, Vin) / rin;' newline ...
                newline ...
                '        // Combined Damping: (1/System Q) + (1/A_vol)' newline ...
                '        damping_tot = 0.0;' newline ...
                '        if (q_tun < 9.9e12) damping_tot = damping_tot + (1.0/q_tun);' newline ...
                '        if (dc_gain < 9.9e12) damping_tot = damping_tot + (1.0/dc_gain);' newline ...
                newline ...
                '        num[0] = 1.0;' newline ...
                '        den[0] = damping_tot;' newline ...
                '        den[1] = tau;' newline ...
                '        i_processed = laplace_nd(i_in_val, num, den);' newline ...
                newline ...
                '        out_a_val = i_processed;' newline ...
                '        out_b_val = i_processed * gain_coeff_b;' newline ...
                '        out_c_val = i_processed * gain_coeff_c;' newline ...
                newline ...
                '        I(Vout_a1p, Vout_a1n) <+ -out_a_val;' newline ...
                '        I(Vout_a1p, Vout_a1n) <+ V(Vout_a1p, Vout_a1n) / rout;' newline ...
                '        I(Vout_b1p, Vout_b1n) <+ -out_b_val;' newline ...
                '        I(Vout_b1p, Vout_b1n) <+ V(Vout_b1p, Vout_b1n) / rout;' newline ...
                '        I(Vout_c1p, Vout_c1n) <+ -out_c_val;' newline ...
                '        I(Vout_c1p, Vout_c1n) <+ V(Vout_c1p, Vout_c1n) / rout;' newline ...
                '    end' newline ...
                'endmodule' ...
            ];

            try
                fid = fopen('integratorA.va', 'w');
                fprintf(fid, '%s', va_code);
                fclose(fid);
            catch
                uialert(app.UIFigure, 'Could not save integratorA.va to disk.', 'File Write Error');
                return;
            end

            % -------------------------------------------------------------
            % 2. Generate & Save Structural Top-Level String (Bandpass)
            % -------------------------------------------------------------
            customParams = [];
            if strcmp(app.swCustomTF.Value, 'On') && (Order == 2 || Order == 4)
                [customParams, isValid, errMsg] = app.parseCustomTF(Order);
                if ~isValid
                    uialert(app.UIFigure, errMsg, 'Custom TF Error');
                    return;
                end
            end

            bp_code = '';
            topCellName = '';

            if Order == 2
                if ~isempty(customParams)
                    C1 = customParams.C1; C3 = customParams.C3; C2 = customParams.C2;
                    a1 = customParams.a1; a2 = customParams.a2;
                else
                    C1 = 0.69; C3 = 1.01; C2 = -1; %The implementation was not done using C2
                    a1 = 1; a2 = 1;
                end
                topCellName = 'bandpassA_top_2nd';
                bp_code = [ ...
                    '// VerilogA for 2nd Order CRFF Bandpass Filter (Cascading Resonators with Feedforward)' newline ...
                    '`include "disciplines.vams"' newline ...
                    '`include "constants.vams"' newline ...
                    newline ...
                    'module bandpassA_top_2nd(Iip, Iin, Ioutp, Ioutn, VDD, VSS);' newline ...
                    '    inout Iip, Iin, Ioutp, Ioutn, VDD, VSS;' newline ...
                    '    electrical Iip, Iin, Ioutp, Ioutn, VDD, VSS;' newline ...
                    newline ...
                    '    // --- Integrator Q-Tuning Parameters ---' newline ...
                    '    parameter real q_tun1 = 10T;' newline ...
                    '    parameter real q_tun2 = 10T;' newline ...
                    newline ...
                    '    // --- Global Integrator Parameters ---' newline ...
                    sprintf('    parameter real dc_gain = %.5e;', A_lin) newline ...
                    '    parameter real r_in = 1.0;' newline ...
                    '    parameter real r_out = 100.0e9;' newline ...
                    newline ...
                    '    // --- Solver Convergence Caps ---' newline ...
                    '    parameter real c_conv = 10.0e-15;' newline ...
                    newline ...
                    '    // --- Internal Differential Nodes ---' newline ...
                    '    electrical int2_in_p, int2_in_n;' newline ...
                    newline ...
                    '    analog begin' newline ...
                    '        I(Iip, VSS)       <+ c_conv * ddt(V(Iip, VSS));' newline ...
                    '        I(Iin, VSS)       <+ c_conv * ddt(V(Iin, VSS));' newline ...
                    '        I(Ioutp, VSS)     <+ c_conv * ddt(V(Ioutp, VSS));' newline ...
                    '        I(Ioutn, VSS)     <+ c_conv * ddt(V(Ioutn, VSS));' newline ...
                    '        I(int2_in_p, VSS) <+ c_conv * ddt(V(int2_in_p, VSS));' newline ...
                    '        I(int2_in_n, VSS) <+ c_conv * ddt(V(int2_in_n, VSS));' newline ...
                    '    end' newline ...
                    newline ...
                    sprintf('    integratorA #(.ugf(%.5e), .gain_coeff_b(0.0), .gain_coeff_c(%.5e), .dc_gain(dc_gain), .q_tun(q_tun1), .rin(r_in), .rout(r_out)) int1 (', f0*a1, C1) newline ...
                    '        .Vip(Iip), .Vin(Iin), .Vout_a1p(int2_in_p), .Vout_a1n(int2_in_n), .Vout_b1p(VSS), .Vout_b1n(VSS), .Vout_c1p(Ioutp), .Vout_c1n(Ioutn), .VDD(VDD), .VSS(VSS)' newline ...
                    '    );' newline ...
                    newline ...
                    sprintf('    integratorA #(.ugf(%.5e), .gain_coeff_b(0.0), .gain_coeff_c(%.5e), .dc_gain(dc_gain), .q_tun(q_tun2), .rin(r_in), .rout(r_out)) int2 (', f0*a2, C3) newline ...
                    '        .Vip(int2_in_p), .Vin(int2_in_n), .Vout_a1p(Iin), .Vout_a1n(Iip), .Vout_b1p(VSS), .Vout_b1n(VSS), .Vout_c1p(Ioutp), .Vout_c1n(Ioutn), .VDD(VDD), .VSS(VSS)' newline ...
                    '    );' newline ...
                    'endmodule' newline ...
                ];

            elseif Order == 4
                if ~isempty(customParams)
                    C1 = customParams.C1; C2 = customParams.C2; C3 = customParams.C3; C4 = customParams.C4;
                    C5 = customParams.C5; C6 = customParams.C6;
                    a1 = customParams.a1; a2 = customParams.a2; a3 = customParams.a3; a4 = customParams.a4;
                else
                    [g_res, c_taps] = app.calcCRFF_Coeffs(4);
                    C1 = c_taps(1); C2 = c_taps(2); C3 = c_taps(3); C4 = c_taps(4);
                    C5 = -g_res(1); C6 = -g_res(2);
                    a1 = 1; a2 = 1; a3 = 1; a4 = 1;
                end

                topCellName = 'bandpassA_top_4th';
                bp_code = [ ...
                    '// VerilogA for 4th Order CRFF Bandpass Filter (Cascading Resonators with Feedforward)' newline ...
                    '`include "disciplines.vams"' newline ...
                    '`include "constants.vams"' newline ...
                    newline ...
                    'module bandpassA_top_4th(Iip, Iin, Ioutp, Ioutn, VDD, VSS);' newline ...
                    '    inout Iip, Iin, Ioutp, Ioutn, VDD, VSS;' newline ...
                    '    electrical Iip, Iin, Ioutp, Ioutn, VDD, VSS;' newline ...
                    newline ...
                    '    // --- Integrator Q-Tuning Parameters ---' newline ...
                    '    parameter real q_tun1 = 10T;' newline ...
                    '    parameter real q_tun2 = 10T;' newline ...
                    '    parameter real q_tun3 = 10T;' newline ...
                    '    parameter real q_tun4 = 10T;' newline ...
                    newline ...
                    '    // --- Global Integrator Parameters ---' newline ...
                    sprintf('    parameter real dc_gain = %.5e;', A_lin) newline ...
                    '    parameter real r_in = 1.0;' newline ...
                    '    parameter real r_out = 100.0e9;' newline ...
                    newline ...
                    '    // --- Solver Convergence Caps ---' newline ...
                    '    parameter real c_conv = 10.0e-15;' newline ...
                    newline ...
                    '    // --- Internal Differential Nodes ---' newline ...
                    '    electrical int2_in_p, int2_in_n, int3_in_p, int3_in_n, int4_in_p, int4_in_n;' newline ...
                    newline ...
                    '    analog begin' newline ...
                    '        I(Iip, VSS)       <+ c_conv * ddt(V(Iip, VSS));' newline ...
                    '        I(Iin, VSS)       <+ c_conv * ddt(V(Iin, VSS));' newline ...
                    '        I(Ioutp, VSS)     <+ c_conv * ddt(V(Ioutp, VSS));' newline ...
                    '        I(Ioutn, VSS)     <+ c_conv * ddt(V(Ioutn, VSS));' newline ...
                    '        I(int2_in_p, VSS) <+ c_conv * ddt(V(int2_in_p, VSS));' newline ...
                    '        I(int2_in_n, VSS) <+ c_conv * ddt(V(int2_in_n, VSS));' newline ...
                    '        I(int3_in_p, VSS) <+ c_conv * ddt(V(int3_in_p, VSS));' newline ...
                    '        I(int3_in_n, VSS) <+ c_conv * ddt(V(int3_in_n, VSS));' newline ...
                    '        I(int4_in_p, VSS) <+ c_conv * ddt(V(int4_in_p, VSS));' newline ...
                    '        I(int4_in_n, VSS) <+ c_conv * ddt(V(int4_in_n, VSS));' newline ...
                    '    end' newline ...
                    newline ...
                    sprintf('    integratorA #(.ugf(%.5e), .gain_coeff_b(0.0), .gain_coeff_c(%.5e), .dc_gain(dc_gain), .q_tun(q_tun1), .rin(r_in), .rout(r_out)) int1 (', f0*a1, C1) newline ...
                    '        .Vip(Iip), .Vin(Iin), .Vout_a1p(int2_in_p), .Vout_a1n(int2_in_n), .Vout_b1p(VSS), .Vout_b1n(VSS), .Vout_c1p(Ioutp), .Vout_c1n(Ioutn), .VDD(VDD), .VSS(VSS)' newline ...
                    '    );' newline ...
                    newline ...
                    sprintf('    integratorA #(.ugf(%.5e), .gain_coeff_b(%.5e), .gain_coeff_c(%.5e), .dc_gain(dc_gain), .q_tun(q_tun2), .rin(r_in), .rout(r_out)) int2 (', f0*a2, -C5, C2) newline ...
                    '        .Vip(int2_in_p), .Vin(int2_in_n), .Vout_a1p(Iin), .Vout_a1n(Iip), .Vout_b1p(int3_in_p), .Vout_b1n(int3_in_n), .Vout_c1p(Ioutp), .Vout_c1n(Ioutn), .VDD(VDD), .VSS(VSS)' newline ...
                    '    );' newline ...
                    newline ...
                    sprintf('    integratorA #(.ugf(%.5e), .gain_coeff_b(0.0), .gain_coeff_c(%.5e), .dc_gain(dc_gain), .q_tun(q_tun3), .rin(r_in), .rout(r_out)) int3 (', f0*a3, C3) newline ...
                    '        .Vip(int3_in_p), .Vin(int3_in_n), .Vout_a1p(int4_in_p), .Vout_a1n(int4_in_n), .Vout_b1p(VSS), .Vout_b1n(VSS), .Vout_c1p(Ioutp), .Vout_c1n(Ioutn), .VDD(VDD), .VSS(VSS)' newline ...
                    '    );' newline ...
                    newline ...
                    sprintf('    integratorA #(.ugf(%.5e), .gain_coeff_b(0.0), .gain_coeff_c(%.5e), .dc_gain(dc_gain), .q_tun(q_tun4), .rin(r_in), .rout(r_out)) int4 (', f0*a4, C4) newline ...
                    '        .Vip(int4_in_p), .Vin(int4_in_n), .Vout_a1p(int3_in_n), .Vout_a1n(int3_in_p), .Vout_b1p(VSS), .Vout_b1n(VSS), .Vout_c1p(Ioutp), .Vout_c1n(Ioutn), .VDD(VDD), .VSS(VSS)' newline ...
                    '    );' newline ...
                    'endmodule' newline ...
                ];

            elseif Order == 6
                [g_res, c_taps] = app.calcCRFF_Coeffs(6);
                topCellName = 'bandpassA_top_6th';
                bp_code = [ ...
                    '// VerilogA for 6th Order CRFF Bandpass Filter (Cascading Resonators with Feedforward)' newline ...
                    '`include "disciplines.vams"' newline ...
                    '`include "constants.vams"' newline ...
                    newline ...
                    'module bandpassA_top_6th(Iip, Iin, Ioutp, Ioutn, VDD, VSS);' newline ...
                    '    inout Iip, Iin, Ioutp, Ioutn, VDD, VSS;' newline ...
                    '    electrical Iip, Iin, Ioutp, Ioutn, VDD, VSS;' newline ...
                    newline ...
                    '    // --- Integrator Q-Tuning Parameters ---' newline ...
                    '    parameter real q_tun1 = 10T;' newline ...
                    '    parameter real q_tun2 = 10T;' newline ...
                    '    parameter real q_tun3 = 10T;' newline ...
                    '    parameter real q_tun4 = 10T;' newline ...
                    '    parameter real q_tun5 = 10T;' newline ...
                    '    parameter real q_tun6 = 10T;' newline ...
                    newline ...
                    '    // --- Global Integrator Parameters ---' newline ...
                    sprintf('    parameter real dc_gain = %.5e;', A_lin) newline ...
                    '    parameter real r_in = 1.0;' newline ...
                    '    parameter real r_out = 100.0e9;' newline ...
                    newline ...
                    '    // --- Solver Convergence Caps ---' newline ...
                    '    parameter real c_conv = 10.0e-15;' newline ...
                    newline ...
                    '    // --- Internal Differential Nodes ---' newline ...
                    '    electrical int2_in_p, int2_in_n, int3_in_p, int3_in_n, int4_in_p, int4_in_n, int5_in_p, int5_in_n, int6_in_p, int6_in_n;' newline ...
                    newline ...
                    '    analog begin' newline ...
                    '        I(Iip, VSS)       <+ c_conv * ddt(V(Iip, VSS));' newline ...
                    '        I(Iin, VSS)       <+ c_conv * ddt(V(Iin, VSS));' newline ...
                    '        I(Ioutp, VSS)     <+ c_conv * ddt(V(Ioutp, VSS));' newline ...
                    '        I(Ioutn, VSS)     <+ c_conv * ddt(V(Ioutn, VSS));' newline ...
                    '        I(int2_in_p, VSS) <+ c_conv * ddt(V(int2_in_p, VSS));' newline ...
                    '        I(int2_in_n, VSS) <+ c_conv * ddt(V(int2_in_n, VSS));' newline ...
                    '        I(int3_in_p, VSS) <+ c_conv * ddt(V(int3_in_p, VSS));' newline ...
                    '        I(int3_in_n, VSS) <+ c_conv * ddt(V(int3_in_n, VSS));' newline ...
                    '        I(int4_in_p, VSS) <+ c_conv * ddt(V(int4_in_p, VSS));' newline ...
                    '        I(int4_in_n, VSS) <+ c_conv * ddt(V(int4_in_n, VSS));' newline ...
                    '        I(int5_in_p, VSS) <+ c_conv * ddt(V(int5_in_p, VSS));' newline ...
                    '        I(int5_in_n, VSS) <+ c_conv * ddt(V(int5_in_n, VSS));' newline ...
                    '        I(int6_in_p, VSS) <+ c_conv * ddt(V(int6_in_p, VSS));' newline ...
                    '        I(int6_in_n, VSS) <+ c_conv * ddt(V(int6_in_n, VSS));' newline ...
                    '    end' newline ...
                    newline ...
                    sprintf('    integratorA #(.ugf(%.5e), .gain_coeff_b(0.0), .gain_coeff_c(%.5e), .dc_gain(dc_gain), .q_tun(q_tun1), .rin(r_in), .rout(r_out)) int1 (', f0, c_taps(1)) newline ...
                    '        .Vip(Iip), .Vin(Iin), .Vout_a1p(int2_in_p), .Vout_a1n(int2_in_n), .Vout_b1p(VSS), .Vout_b1n(VSS), .Vout_c1p(Ioutp), .Vout_c1n(Ioutn), .VDD(VDD), .VSS(VSS)' newline ...
                    '    );' newline ...
                    sprintf('    integratorA #(.ugf(%.5e), .gain_coeff_b(%.5e), .gain_coeff_c(%.5e), .dc_gain(dc_gain), .q_tun(q_tun2), .rin(r_in), .rout(r_out)) int2 (', f0, g_res(1), c_taps(2)) newline ...
                    '        .Vip(int2_in_p), .Vin(int2_in_n), .Vout_a1p(Iin), .Vout_a1n(Iip), .Vout_b1p(int3_in_p), .Vout_b1n(int3_in_n), .Vout_c1p(Ioutp), .Vout_c1n(Ioutn), .VDD(VDD), .VSS(VSS)' newline ...
                    '    );' newline ...
                    sprintf('    integratorA #(.ugf(%.5e), .gain_coeff_b(0.0), .gain_coeff_c(%.5e), .dc_gain(dc_gain), .q_tun(q_tun3), .rin(r_in), .rout(r_out)) int3 (', f0, c_taps(3)) newline ...
                    '        .Vip(int3_in_p), .Vin(int3_in_n), .Vout_a1p(int4_in_p), .Vout_a1n(int4_in_n), .Vout_b1p(VSS), .Vout_b1n(VSS), .Vout_c1p(Ioutp), .Vout_c1n(Ioutn), .VDD(VDD), .VSS(VSS)' newline ...
                    '    );' newline ...
                    sprintf('    integratorA #(.ugf(%.5e), .gain_coeff_b(%.5e), .gain_coeff_c(%.5e), .dc_gain(dc_gain), .q_tun(q_tun4), .rin(r_in), .rout(r_out)) int4 (', f0, g_res(2), c_taps(4)) newline ...
                    '        .Vip(int4_in_p), .Vin(int4_in_n), .Vout_a1p(int3_in_n), .Vout_a1n(int3_in_p), .Vout_b1p(int5_in_p), .Vout_b1n(int5_in_n), .Vout_c1p(Ioutp), .Vout_c1n(Ioutn), .VDD(VDD), .VSS(VSS)' newline ...
                    '    );' newline ...
                    sprintf('    integratorA #(.ugf(%.5e), .gain_coeff_b(0.0), .gain_coeff_c(%.5e), .dc_gain(dc_gain), .q_tun(q_tun5), .rin(r_in), .rout(r_out)) int5 (', f0, c_taps(5)) newline ...
                    '        .Vip(int5_in_p), .Vin(int5_in_n), .Vout_a1p(int6_in_p), .Vout_a1n(int6_in_n), .Vout_b1p(VSS), .Vout_b1n(VSS), .Vout_c1p(Ioutp), .Vout_c1n(Ioutn), .VDD(VDD), .VSS(VSS)' newline ...
                    '    );' newline ...
                    sprintf('    integratorA #(.ugf(%.5e), .gain_coeff_b(0.0), .gain_coeff_c(%.5e), .dc_gain(dc_gain), .q_tun(q_tun6), .rin(r_in), .rout(r_out)) int6 (', f0, c_taps(6)) newline ...
                    '        .Vip(int6_in_p), .Vin(int6_in_n), .Vout_a1p(int5_in_n), .Vout_a1n(int5_in_p), .Vout_b1p(VSS), .Vout_b1n(VSS), .Vout_c1p(Ioutp), .Vout_c1n(Ioutn), .VDD(VDD), .VSS(VSS)' newline ...
                    '    );' newline ...
                    'endmodule' newline ...
                ];
            end
            
            % Save the top-level Bandpass .va file locally
            fileNameBP = [topCellName '.va'];
            try
                fid = fopen(fileNameBP, 'w');
                fprintf(fid, '%s', bp_code);
                fclose(fid);
            catch
                uialert(app.UIFigure, sprintf('Could not save %s to disk.', fileNameBP), 'File Write Error');
                return;
            end

            % -------------------------------------------------------------
            % 3. Generate the Unified SKILL Payload
            % -------------------------------------------------------------
            skill_fileName = 'import_beta_tool.il';

            % Safely escape Verilog-A code strings for SKILL embedding
            skill_va_code = strrep(va_code, '\', '\\');
            skill_bp_code = strrep(bp_code, '\', '\\');
            skill_va_code = strrep(skill_va_code, '"', '\"');
            skill_bp_code = strrep(skill_bp_code, '"', '\"');
            skill_va_code = strrep(skill_va_code, char(10), '\n');
            skill_bp_code = strrep(skill_bp_code, char(10), '\n');

            % SKILL payload containing physical graphic drawing procedures
            skill_symbol_code = [ ...
                ';; --- Custom Symbol Generation Procedures ---' newline ...
                'procedure( drawBetaPin(cv name dir side offset u ext w h)' newline ...
                '    let((px py lx ly lblX lblY just fig net term)' newline ...
                '        if(side == "L" then px = 0.0 py = ext + offset*u lx = ext ly = py lblX = lx+0.2*u lblY = py just = "centerLeft"' newline ...
                '        else if(side == "R" then px = 2.0*ext+w py = ext + offset*u lx = ext+w ly = py lblX = lx-0.2*u lblY = py just = "centerRight"' newline ...
                '        else if(side == "T" then px = ext+w/2.0 py = 2.0*ext+h lx = px ly = ext+h lblX = px lblY = ly-0.2*u just = "upperCenter"' newline ...
                '        else px = ext+w/2.0 py = 0.0 lx = px ly = ext lblX = px lblY = ly+0.2*u just = "lowerCenter"' newline ...
                '        )))' newline ...
                '        dbCreateLine(cv list("device" "drawing") list(px:py lx:ly))' newline ...
                '        fig = dbCreateRect(cv list("pin" "drawing") list((px-0.0125):(py-0.0125) (px+0.0125):(py+0.0125)))' newline ...
                '        net = dbCreateNet(cv name)' newline ...
                '        term = dbCreateTerm(net name dir)' newline ...
                '        dbCreatePin(net fig name term)' newline ...
                '        dbCreateLabel(cv list("pin" "drawing") lblX:lblY name just "R0" "roman" 0.05)' newline ...
                '    )' newline ...
                ')' newline ...
                newline ...
                'procedure( createBetaSymbol(libName cellName type)' newline ...
                '    let((cv u ext w h)' newline ...
                '        cv = dbOpenCellViewByType(libName cellName "symbol" "schematicSymbol" "w")' newline ...
                '        u = 0.0625' newline ...
                '        ext = 2.0 * u' newline ...
                '        w = 10.0 * u' newline ...
                '        if(type == "integrator" then' newline ...
                '            h = 20.0 * u' newline ...
                '        else' newline ...
                '            h = 16.0 * u' newline ...
                '        )' newline ...
                '        ;; Draw Box' newline ...
                '        dbCreateRect(cv list("device" "drawing") list(ext:ext (ext+w):(ext+h)))' newline ...
                '        ;; Draw Labels' newline ...
                '        dbCreateLabel(cv list("annotate" "drawing8") (ext + w/2.0):(ext+h+ext/2.0) "[@instanceName]" "centerLeft" "R0" "roman" 0.0625)' newline ...
                '        dbCreateLabel(cv list("annotate" "drawing8") (ext + w/2.0):(ext+h-2.0*u) "[@partName]" "centerCenter" "R0" "roman" 0.0625)' newline ...
                '        ;; Draw Order Label for Bandpass' newline ...
                '        if(type == "bandpass" then' newline ...
                '            dbCreateLabel(cv list("annotate" "drawing8") (ext + w/2.0):(ext+8.0*u) "Filter Block" "centerCenter" "R0" "roman" 0.0625)' newline ...
                '        )' newline ...
                '        ;; Draw Pins based on type (ALL defined as inputOutput to match VA inout)' newline ...
                '        if(type == "integrator" then' newline ...
                '            drawBetaPin(cv "VDD" "inputOutput" "T" 0.0 u ext w h)' newline ...
                '            drawBetaPin(cv "VSS" "inputOutput" "B" 0.0 u ext w h)' newline ...
                '            drawBetaPin(cv "Vip" "inputOutput" "L" 13.0 u ext w h)' newline ...
                '            drawBetaPin(cv "Vin" "inputOutput" "L" 5.0 u ext w h)' newline ...
                '            drawBetaPin(cv "Vout_a1p" "inputOutput" "R" 15.0 u ext w h)' newline ...
                '            drawBetaPin(cv "Vout_a1n" "inputOutput" "R" 13.0 u ext w h)' newline ...
                '            drawBetaPin(cv "Vout_b1p" "inputOutput" "R" 10.0 u ext w h)' newline ...
                '            drawBetaPin(cv "Vout_b1n" "inputOutput" "R" 8.0 u ext w h)' newline ...
                '            drawBetaPin(cv "Vout_c1p" "inputOutput" "R" 5.0 u ext w h)' newline ...
                '            drawBetaPin(cv "Vout_c1n" "inputOutput" "R" 3.0 u ext w h)' newline ...
                '        else' newline ...
                '            drawBetaPin(cv "VDD" "inputOutput" "T" 0.0 u ext w h)' newline ...
                '            drawBetaPin(cv "VSS" "inputOutput" "B" 0.0 u ext w h)' newline ...
                '            drawBetaPin(cv "Iip" "inputOutput" "L" 12.0 u ext w h)' newline ...
                '            drawBetaPin(cv "Iin" "inputOutput" "L" 4.0 u ext w h)' newline ...
                '            drawBetaPin(cv "Ioutp" "inputOutput" "R" 12.0 u ext w h)' newline ...
                '            drawBetaPin(cv "Ioutn" "inputOutput" "R" 4.0 u ext w h)' newline ...
                '        )' newline ...
                '        ;; Draw Selection Box' newline ...
                '        dbCreateRect(cv list("instance" "drawing") list(0.0:0.0 (2.0*ext+w):(2.0*ext+h)))' newline ...
                '        dbSave(cv)' newline ...
                '        dbClose(cv)' newline ...
                '        printf("Successfully generated %s/%s/symbol\n" libName cellName)' newline ...
                '    )' newline ...
                ')' newline ...
            ];

            % Construct the full SKILL string
            skill_code = sprintf([...
                ';; Cadence SKILL script generated by BETA Tool\n' ...
                ';; This single script embeds all Verilog-A code and auto-generates the cell views.\n\n' ...
                'procedure( createBetaVerilogA(libName cellName codeContent)\n' ...
                '    let((libId fileId destFile outPort)\n' ...
                '        ;; 1. Ensure Library Exists\n' ...
                '        libId = ddGetObj(libName)\n' ...
                '        unless(libId\n' ...
                '            libId = ddCreateLib(libName)\n' ...
                '            printf("Created new library: %%s\\n" libName)\n' ...
                '        )\n\n' ...
                '        ;; 2. Create veriloga.va file object directly\n' ...
                '        fileId = ddGetObj(libName cellName "veriloga" "veriloga.va" nil "w")\n' ...
                '        if(fileId then\n' ...
                '            destFile = fileId~>writePath\n' ...
                '            ;; 3. Write embedded string to file\n' ...
                '            outPort = outfile(destFile)\n' ...
                '            if(outPort then\n' ...
                '                fprintf(outPort "%%s" codeContent)\n' ...
                '                close(outPort)\n' ...
                '                printf("Successfully generated %%s/%%s/veriloga\\n" libName cellName)\n' ...
                '            else\n' ...
                '                printf("ERROR: Could not write to %%s\\n" destFile)\n' ...
                '            )\n' ...
                '        else\n' ...
                '            printf("ERROR: Could not allocate Cadence database object for %%s/%%s\\n" libName cellName)\n' ...
                '        )\n' ...
                '    )\n' ...
                ')\n\n' ...
                '%s\n' ... 
                ';; --- Embedded Verilog-A Code Strings ---\n' ...
                'integratorCode = "%s"\n' ...
                'bandpassCode = "%s"\n\n' ...
                ';; --- Execute Generation ---\n' ...
                'createBetaVerilogA("BETA_tool" "integratorA" integratorCode)\n' ...
                'createBetaSymbol("BETA_tool" "integratorA" "integrator")\n' ...
                'createBetaVerilogA("BETA_tool" "%s" bandpassCode)\n' ...
                'createBetaSymbol("BETA_tool" "%s" "bandpass")\n' ...
            ], skill_symbol_code, skill_va_code, skill_bp_code, topCellName, topCellName);

            try
                fid = fopen(skill_fileName, 'w');
                fprintf(fid, '%s', skill_code);
                fclose(fid);

                app.lblStatus.Text = 'Files & Script Exported!';
                app.lblStatus.FontColor = [0 0.6 0];
                app.txtArea.Value = [app.txtArea.Value; ''; ...
                    sprintf('Exported Local Reference: "integratorA.va"'); ...
                    sprintf('Exported Local Reference: "%s"', fileNameBP); ...
                    sprintf('Exported SKILL payload:   "%s"', skill_fileName); ...
                    '-> Run ''load("import_beta_tool.il")'' in your Cadence CIW.'; ...
                    sprintf('Used DC Gain: %.1f dB', target_gain_db)];
            catch
                app.lblStatus.Text = 'Export Failed';
                app.lblStatus.FontColor = [1 0 0];
                uialert(app.UIFigure, 'Could not write the SKILL script file to disk.', 'Export Error');
            end
        end

        % =================================================================
        % GENERATE SIMULINK
        % =================================================================
        function onGenSimulink(app, ~, ~)
            Order = str2double(app.ddOrder.Value);
            f0 = app.efFreq.Value;
            Q = app.efQ.Value; 
            w0 = 2 * pi * f0;
            GainDB = app.efIntGain.Value;
            A_lin = 10^(GainDB/20);
            
            app.lblStatus.Text = 'Generating Simulink...';
            app.lblStatus.FontColor = [0.85 0.5 0];
            drawnow;

            if Order == 4 || Order == 6
                modelName = sprintf('Filter_Gen_%dth_Order_CRFF', Order);
            else
                modelName = sprintf('Filter_Gen_%dnd_Order', Order);
            end
            
            gain_damping = -1/Q; 
            gain_res = -1;

            try
                if bdIsLoaded(modelName)
                    close_system(modelName, 0);
                end
                new_system(modelName);
                open_system(modelName);
                
                set_param(modelName, 'SolverType', 'Fixed-step');
                set_param(modelName, 'Solver', 'ode4');
                set_param(modelName, 'FixedStep', '1e-9'); 
                set_param(modelName, 'StopTime', '2e-6');
                
                x_start = 50;

                if Order == 2
                    if strcmp(app.swCustomTF.Value, 'On')
                        [customParams, isValid, errMsg] = app.parseCustomTF(2);
                        if ~isValid
                            app.lblStatus.Text = 'Generation Failed';
                            uialert(app.UIFigure, errMsg, 'Custom TF Error');
                            return;
                        end
                        taps.hp = 0.00; taps.bp = customParams.C1; taps.lp = customParams.C3;
                        app.buildSimulinkSection(modelName, 'Sec1', x_start, w0, customParams.K_damp, customParams.C2, taps, A_lin, customParams.a1, customParams.a2);
                    else
                        taps.hp = 0.00; taps.bp = 0.69; taps.lp = 1.01;
                        app.buildSimulinkSection(modelName, 'Sec1', x_start, w0, gain_damping, gain_res, taps, A_lin, 1, 1);
                    end
                    
                    add_block('simulink/Sources/Sine Wave', [modelName '/Input_Signal'], ...
                        'Position', [10, 290, 40, 320], 'Frequency', num2str(w0), 'Amplitude', '1');
                    add_line(modelName, 'Input_Signal/1', 'Sec1_Sum/2');

                    add_block('simulink/Sinks/Scope', [modelName '/Final_Scope'], ...
                        'Position', [x_start + 600, 150, x_start + 630, 180]);
                    add_line(modelName, 'Sec1_OutSum/1', 'Final_Scope/1');

                elseif Order == 4 || Order == 6
                    [g_res, c_taps] = app.calcCRFF_Coeffs(Order);
                    if Order == 4
                        customParams = [];
                        if strcmp(app.swCustomTF.Value, 'On')
                            [customParams, isValid, errMsg] = app.parseCustomTF(4);
                            if ~isValid
                                app.lblStatus.Text = 'Generation Failed';
                                uialert(app.UIFigure, errMsg, 'Custom TF Error');
                                return;
                            end
                        end
                        app.buildCRFF4(modelName, x_start, 300, w0, gain_damping, A_lin, g_res, c_taps, customParams);
                    else
                        app.buildCRFF6(modelName, x_start, 300, w0, gain_damping, A_lin, g_res, c_taps);
                    end
                    
                    add_block('simulink/Sources/Sine Wave', [modelName '/Input_Signal'], ...
                        'Position', [10, 300, 40, 330], 'Frequency', num2str(w0), 'Amplitude', '1');
                    add_line(modelName, 'Input_Signal/1', 'Sum1/1');
                    
                    add_block('simulink/Sinks/Scope', [modelName '/Final_Scope'], ...
                        'Position', [x_start + 1200, 300, x_start + 1230, 330]);
                    add_line(modelName, 'Output_Sum/1', 'Final_Scope/1');
                end

                Simulink.BlockDiagram.arrangeSystem(modelName);
                app.lblStatus.Text = 'Model Generated!';
                app.lblStatus.FontColor = [0 0.6 0];
                app.txtArea.Value = [app.txtArea.Value; ...
                    ''; sprintf('Simulink Model "%s" created successfully.', modelName); ...
                    sprintf('Used Integrator DC Gain: %.1f dB', GainDB)];
                
            catch ME
                app.lblStatus.Text = 'Generation Failed';
                app.lblStatus.FontColor = [1 0 0];
                uialert(app.UIFigure, ME.message, 'Simulink Error');
            end
        end
        
        % --- HELPER: Build 4th Order CRFF Chain ---
        function buildCRFF4(~, model, x, y, w0, damp, A_lin, g_res, c_taps, customParams)
            if nargin < 10 || isempty(customParams)
                a1=1; a2=1; a3=1; a4=1;
                K_damp1=damp; K_damp2=damp;
                C5=-g_res(1); C6=-g_res(2);
                C1=c_taps(1); C2=c_taps(2); C3=c_taps(3); C4=c_taps(4);
            else
                a1=customParams.a1; a2=customParams.a2; a3=customParams.a3; a4=customParams.a4;
                K_damp1=customParams.K_damp1; K_damp2=customParams.K_damp2;
                C5=customParams.C5; C6=customParams.C6;
                C1=customParams.C1; C2=customParams.C2; C3=customParams.C3; C4=customParams.C4;
            end
            
            leak = -1/A_lin;
            
            add_block('simulink/Math Operations/Sum', [model '/Sum1'], 'Position', [x, y, x+20, y+40], 'Inputs', '|++++'); 
            add_block('simulink/Math Operations/Gain', [model '/G_w0_1'], 'Position', [x+50, y, x+100, y+30], 'Gain', num2str(a1*w0));
            add_block('simulink/Continuous/Integrator', [model '/Int1'], 'Position', [x+120, y, x+150, y+30]);
            
            add_block('simulink/Math Operations/Sum', [model '/Sum2'], 'Position', [x+200, y, x+220, y+40], 'Inputs', '|++');
            add_block('simulink/Math Operations/Gain', [model '/G_w0_2'], 'Position', [x+250, y, x+300, y+30], 'Gain', num2str(a2*w0));
            add_block('simulink/Continuous/Integrator', [model '/Int2'], 'Position', [x+320, y, x+350, y+30]);
            
            add_block('simulink/Math Operations/Sum', [model '/Sum3'], 'Position', [x+450, y, x+470, y+40], 'Inputs', '|++++'); 
            add_block('simulink/Math Operations/Gain', [model '/G_w0_3'], 'Position', [x+500, y, x+550, y+30], 'Gain', num2str(a3*w0));
            add_block('simulink/Continuous/Integrator', [model '/Int3'], 'Position', [x+570, y, x+600, y+30]);
            
            add_block('simulink/Math Operations/Sum', [model '/Sum4'], 'Position', [x+650, y, x+670, y+40], 'Inputs', '|++');
            add_block('simulink/Math Operations/Gain', [model '/G_w0_4'], 'Position', [x+700, y, x+750, y+30], 'Gain', num2str(a4*w0));
            add_block('simulink/Continuous/Integrator', [model '/Int4'], 'Position', [x+770, y, x+800, y+30]);
            
            add_line(model, 'Sum1/1', 'G_w0_1/1'); add_line(model, 'G_w0_1/1', 'Int1/1');
            add_line(model, 'Int1/1', 'Sum2/1');
            add_line(model, 'Sum2/1', 'G_w0_2/1'); add_line(model, 'G_w0_2/1', 'Int2/1');
            add_line(model, 'Int2/1', 'Sum3/1');
            add_line(model, 'Sum3/1', 'G_w0_3/1'); add_line(model, 'G_w0_3/1', 'Int3/1');
            add_line(model, 'Int3/1', 'Sum4/1');
            add_line(model, 'Sum4/1', 'G_w0_4/1'); add_line(model, 'G_w0_4/1', 'Int4/1');
            
            add_block('simulink/Math Operations/Gain', [model '/Fb_Res1'], 'Position', [x+150, y+100, x+200, y+130], 'Gain', num2str(C5), 'Orientation', 'left');
            add_line(model, 'Int2/1', 'Fb_Res1/1', 'autorouting', 'on'); add_line(model, 'Fb_Res1/1', 'Sum1/2', 'autorouting', 'on');
            
            add_block('simulink/Math Operations/Gain', [model '/Fb_Res2'], 'Position', [x+600, y+100, x+650, y+130], 'Gain', num2str(C6), 'Orientation', 'left');
            add_line(model, 'Int4/1', 'Fb_Res2/1', 'autorouting', 'on'); add_line(model, 'Fb_Res2/1', 'Sum3/2', 'autorouting', 'on');
            
            add_block('simulink/Math Operations/Gain', [model '/Fb_Damp1'], 'Position', [x+50, y+150, x+100, y+180], 'Gain', num2str(K_damp1), 'Orientation', 'left');
            add_line(model, 'Int1/1', 'Fb_Damp1/1', 'autorouting', 'on'); add_line(model, 'Fb_Damp1/1', 'Sum1/3', 'autorouting', 'on');
            
            add_block('simulink/Math Operations/Gain', [model '/Fb_Damp2'], 'Position', [x+500, y+150, x+550, y+180], 'Gain', num2str(K_damp2), 'Orientation', 'left');
            add_line(model, 'Int3/1', 'Fb_Damp2/1', 'autorouting', 'on'); add_line(model, 'Fb_Damp2/1', 'Sum3/3', 'autorouting', 'on');
            
            ints = {'Int1', 'Int2', 'Int3', 'Int4'};
            sums = {'Sum1', 'Sum2', 'Sum3', 'Sum4'};
            ports = [4, 2, 4, 2];
            for i=1:4
               bk = [model '/Fb_Leak' num2str(i)];
               add_block('simulink/Math Operations/Gain', bk, 'Position', [x+(i-1)*200, y+200, x+(i-1)*200+40, y+230], 'Gain', num2str(leak), 'Orientation', 'left');
               add_line(model, [ints{i} '/1'], ['Fb_Leak' num2str(i) '/1'], 'autorouting', 'on');
               add_line(model, ['Fb_Leak' num2str(i) '/1'], [sums{i} '/' num2str(ports(i))], 'autorouting', 'on');
            end
            
            add_block('simulink/Math Operations/Sum', [model '/Output_Sum'], 'Position', [x+900, y, x+920, y+120], 'Inputs', '++++');
            
            add_block('simulink/Math Operations/Gain', [model '/Tap1'], 'Position', [x+850, y, x+880, y+20], 'Gain', num2str(C1));
            add_block('simulink/Math Operations/Gain', [model '/Tap2'], 'Position', [x+850, y+30, x+880, y+50], 'Gain', num2str(C2));
            add_block('simulink/Math Operations/Gain', [model '/Tap3'], 'Position', [x+850, y+60, x+880, y+80], 'Gain', num2str(C3));
            add_block('simulink/Math Operations/Gain', [model '/Tap4'], 'Position', [x+850, y+90, x+880, y+110], 'Gain', num2str(C4));
            
            for i=1:4
                add_line(model, [ints{i} '/1'], ['Tap' num2str(i) '/1'], 'autorouting', 'on');
                add_line(model, ['Tap' num2str(i) '/1'], ['Output_Sum/' num2str(i)], 'autorouting', 'on');
            end
        end

        % --- HELPER: Build 6th Order CRFF Chain ---
        function buildCRFF6(~, model, x, y, w0, damp, A_lin, g_res, c_taps)
            leak = -1/A_lin;
            ints = {'Int1', 'Int2', 'Int3', 'Int4', 'Int5', 'Int6'};
            sums = {'Sum1', 'Sum2', 'Sum3', 'Sum4', 'Sum5', 'Sum6'};
            
            for i = 1:6
                x_curr = x + (i-1)*150; 
                if mod(i, 2) == 1, signs = '|++++'; else, signs = '|++'; end
                
                add_block('simulink/Math Operations/Sum', [model '/' sums{i}], ...
                    'Position', [x_curr, y, x_curr+20, y+40], 'Inputs', signs);
                add_block('simulink/Math Operations/Gain', [model '/G_w0_' num2str(i)], ...
                    'Position', [x_curr+40, y, x_curr+90, y+30], 'Gain', num2str(w0));
                add_block('simulink/Continuous/Integrator', [model '/' ints{i}], ...
                    'Position', [x_curr+110, y, x_curr+140, y+30]);
                
                add_line(model, [sums{i} '/1'], ['G_w0_' num2str(i) '/1']);
                add_line(model, ['G_w0_' num2str(i) '/1'], [ints{i} '/1']);
                if i > 1, add_line(model, [ints{i-1} '/1'], [sums{i} '/1'], 'autorouting', 'on'); end
            end
            
            for k = 1:3
                odd_idx = (k-1)*2 + 1; even_idx = odd_idx + 1; 
                x_base = x + (odd_idx-1)*150;
                
                bkRes = [model '/Fb_Res' num2str(k)];
                add_block('simulink/Math Operations/Gain', bkRes, ...
                    'Position', [x_base+150, y+80, x_base+200, y+110], ...
                    'Gain', num2str(-g_res(k)), 'Orientation', 'left');
                add_line(model, [ints{even_idx} '/1'], ['Fb_Res' num2str(k) '/1'], 'autorouting', 'on');
                add_line(model, ['Fb_Res' num2str(k) '/1'], [sums{odd_idx} '/2'], 'autorouting', 'on');
                
                bkDamp = [model '/Fb_Damp' num2str(k)];
                add_block('simulink/Math Operations/Gain', bkDamp, ...
                    'Position', [x_base+50, y+130, x_base+100, y+160], ...
                    'Gain', num2str(damp), 'Orientation', 'left');
                add_line(model, [ints{odd_idx} '/1'], ['Fb_Damp' num2str(k) '/1'], 'autorouting', 'on');
                add_line(model, ['Fb_Damp' num2str(k) '/1'], [sums{odd_idx} '/3'], 'autorouting', 'on');
            end
            
            for i = 1:6
                x_curr = x + (i-1)*150;
                bkLeak = [model '/Fb_Leak' num2str(i)];
                add_block('simulink/Math Operations/Gain', bkLeak, ...
                    'Position', [x_curr+20, y+180, x_curr+60, y+210], ...
                    'Gain', num2str(leak), 'Orientation', 'left');
                add_line(model, [ints{i} '/1'], ['Fb_Leak' num2str(i) '/1'], 'autorouting', 'on');
                if mod(i, 2) == 1, port = 4; else, port = 2; end
                add_line(model, ['Fb_Leak' num2str(i) '/1'], [sums{i} '/' num2str(port)], 'autorouting', 'on');
            end
            
            add_block('simulink/Math Operations/Sum', [model '/Output_Sum'], ...
                'Position', [x+1000, y, x+1020, y+150], 'Inputs', '++++++');
                
            for i = 1:6
                bkTap = [model '/Tap' num2str(i)];
                y_tap = y + (i-1)*25;
                add_block('simulink/Math Operations/Gain', bkTap, ...
                    'Position', [x+900, y_tap, x+940, y_tap+20], 'Gain', num2str(c_taps(i)));
                add_line(model, [ints{i} '/1'], ['Tap' num2str(i) '/1'], 'autorouting', 'on');
                add_line(model, ['Tap' num2str(i) '/1'], ['Output_Sum/' num2str(i)], 'autorouting', 'on');
            end
        end


        % =================================================================
        % RUN SIMULINK SIMULATION
        % =================================================================
        function onRunSimulink(app, ~, ~)
            Order = str2double(app.ddOrder.Value);
            f0 = app.efFreq.Value;
            Q = app.efQ.Value; 
            w0 = 2 * pi * f0;
            GainDB = app.efIntGain.Value; 
            A_lin = 10^(GainDB/20);
            
            if Order == 4 || Order == 6
                modelName = sprintf('Filter_Gen_%dth_Order_CRFF', Order);
            else
                modelName = sprintf('Filter_Gen_%dnd_Order', Order);
            end
            
            if ~bdIsLoaded(modelName)
                uialert(app.UIFigure, ...
                    sprintf('Model "%s" is not open. Please click "Generate Simulink Model" first.', modelName), ...
                    'Model Not Found');
                return;
            end
            
            app.lblStatus.Text = 'Running Simulation...';
            app.lblStatus.FontColor = [0.85 0.5 0]; 
            app.TabGroup.SelectedTab = app.tSim;
            
            cla(app.axSimTime); cla(app.axSimFreq); cla(app.axSimWide);
            drawnow;
            
            try
                if strcmp(get_param(modelName, 'Dirty'), 'off'), set_param(modelName, 'Lock', 'off'); end
                
                if Order == 4 || Order == 6
                    outportPath = [modelName '/Out1'];
                    try get_param(outportPath, 'Handle'); catch
                        add_block('simulink/Sinks/Out1', outportPath, 'Position', [2000, 300, 2030, 320]); 
                        add_line(modelName, 'Output_Sum/1', 'Out1/1', 'autorouting', 'on');
                    end
                else
                    if Order == 2, srcBlock = [modelName '/Sec1_OutSum']; else, srcBlock = [modelName '/Sec2_OutSum']; end
                    outportPath = [modelName '/Out1'];
                    try get_param(outportPath, 'Handle'); catch
                        add_block('simulink/Sinks/Out1', outportPath, 'Position', [2000, 150, 2030, 170]); 
                        add_line(modelName, [srcBlock(length(modelName)+2:end) '/1'], 'Out1/1', 'autorouting', 'on');
                    end
                end
                
                set_param(modelName, 'SaveOutput', 'on');
                set_param(modelName, 'OutputSaveName', 'yout');
                set_param(modelName, 'SaveTime', 'on');
                set_param(modelName, 'TimeSaveName', 'tout');
                
                app.txtArea.Value = [app.txtArea.Value; ''; 'Running Transient Analysis...'];
                set_param(modelName, 'FixedStep', '1e-9'); 
                set_param(modelName, 'StopTime', '4e-6');
                set_param([modelName '/Input_Signal'], 'Frequency', num2str(2*pi*f0));
                
                simOut = sim(modelName);
                ds = simOut.yout; sig = ds.get(1);
                t_vals = sig.Values.Time; y_vals = sig.Values.Data;
                
                cla(app.axSimTime);
                plot(app.axSimTime, t_vals*1e6, y_vals, 'Color', app.CustomBlue, 'LineWidth', 1.5);
                grid(app.axSimTime, 'on');
                title(app.axSimTime, sprintf('Transient Response with Input Amplitude=1 @ %s', app.formatFreq(f0)));
                xlabel(app.axSimTime, 'Time (\mus)'); ylabel(app.axSimTime, 'Output');
                xlim(app.axSimTime, [3.5, 4.0]);
                
                app.txtArea.Value = [app.txtArea.Value; 'Running Narrow Sweep...'];
                drawnow;

                % --- DYNAMIC PASSBAND TRACKING ---
                % Safely build sys_real here to extract its poles
                customParams = [];
                if (Order == 2 || Order == 4) && strcmp(app.swCustomTF.Value, 'On')
                    [customParams, ~, ~] = app.parseCustomTF(Order);
                end
                [g_res, c_taps] = app.calcCRFF_Coeffs(Order);
                sys_real_temp = app.getCRFF_SS(Order, w0, Q, A_lin, g_res, c_taps, customParams);
                
                p_sim = pole(sys_real_temp);
                p_cplx_sim = p_sim(imag(p_sim) > 0);
                if ~isempty(p_cplx_sim)
                    f_plot_center_sim = exp(mean(log(abs(p_cplx_sim) / (2*pi))));
                else
                    f_plot_center_sim = f0;
                end
                
                bw_hz = app.efBW.Value * 1e6;
                % Adaptive span tied to the dynamically tracked center
                f_start = max(f_plot_center_sim * 0.1, f_plot_center_sim - (1.5 * bw_hz)); 
                f_stop  = f_plot_center_sim + (1.5 * bw_hz);
                freq_steps = linspace(f_start, f_stop, 120); 
                mags_db = zeros(size(freq_steps));
                d = uiprogressdlg(app.UIFigure, 'Title', 'Simulating', 'Message', 'Narrow Sweep...', 'Cancelable', false);
                
                set_param(modelName, 'FastRestart', 'on');
                for i = 1:length(freq_steps)
                    w_curr = 2 * pi * freq_steps(i);
                    set_param([modelName '/Input_Signal'], 'Frequency', num2str(w_curr));
                    simOut = sim(modelName);
                    sig = simOut.yout.get(1); data_slice = sig.Values.Data;
                    n_samp = length(data_slice); ss_data = data_slice(floor(n_samp*0.7):end);
                    peak_val = (max(ss_data) - min(ss_data)) / 2;
                    if peak_val < 1e-9, peak_val = 1e-9; end
                    mags_db(i) = 20 * log10(peak_val);
                    d.Value = 0.3 * (i/length(freq_steps)); 
                end
                set_param(modelName, 'FastRestart', 'off');
                
                % Grab the dynamic scale
                [fScale, fUnit] = app.getFreqScale(f0);

                cla(app.axSimFreq);
                plot(app.axSimFreq, freq_steps/fScale, mags_db, 'ro-', 'MarkerFaceColor', 'r');
                hold(app.axSimFreq, 'on');
                xline(app.axSimFreq, f0/fScale, 'm--', 'Label', 'f0','FontSize', app.Font_Annotations, 'FontWeight', 'bold');
                [max_val, max_idx] = max(mags_db);
                target_3db = max_val - 3;
                yline(app.axSimFreq, target_3db, '--', 'Color', app.CustomBlue, 'Label', '-3dB','FontSize', app.Font_Annotations, 'FontWeight', 'bold');
                idx_L = find(mags_db(1:max_idx) >= target_3db, 1, 'first');
                idx_R = find(mags_db(max_idx:end) <= target_3db, 1, 'first');
                bw_meas_sim = 0;
                if ~isempty(idx_L) && ~isempty(idx_R)
                    y1 = mags_db(idx_L-1); y2 = mags_db(idx_L);
                    x1 = freq_steps(idx_L-1); x2 = freq_steps(idx_L);
                    f_L = x1 + (target_3db - y1) * (x2 - x1) / (y2 - y1);
                    y1 = mags_db(max_idx + idx_R - 2); y2 = mags_db(max_idx + idx_R - 1);
                    x1 = freq_steps(max_idx + idx_R - 2); x2 = freq_steps(max_idx + idx_R - 1);
                    f_H = x1 + (target_3db - y1) * (x2 - x1) / (y2 - y1);
                    bw_meas_sim = f_H - f_L;
                    plot(app.axSimFreq, [f_L, f_H]/fScale, [target_3db, target_3db], 'o', 'Color', app.CustomBlue, 'MarkerFaceColor', app.CustomBlue, 'MarkerSize', app.Plot_Marker_Size);
                end
                grid(app.axSimFreq, 'on');
                title(app.axSimFreq, sprintf('Narrow Response (Peak=%.2fdB, BW_{sim}=%s, Q_{sim}=%.2f)', max_val, app.formatFreq(bw_meas_sim), f0/bw_meas_sim));
                xlabel(app.axSimFreq, sprintf('Frequency (%s)', fUnit)); ylabel(app.axSimFreq, 'Gain (dB)');
                hold(app.axSimFreq, 'off');

                app.txtArea.Value = [app.txtArea.Value; 'Running Wide AC Sweep...'];
                app.lblStatus.Text = 'Wide Sweep...';
                drawnow;
                set_param(modelName, 'FixedStep', '1e-10'); 
                
                f_lower_raw = f_plot_center_sim / 100;
                f_lower_decade = 10^ceil(log10(f_lower_raw));
                f_upper_raw = f_plot_center_sim * 100;
                f_upper_decade = 10^floor(log10(f_upper_raw));
                if f_lower_decade >= f_upper_decade, f_lower_decade = f_plot_center_sim / 100; f_upper_decade = f_plot_center_sim * 100; end
                
                f_coarse = logspace(log10(f_lower_decade), log10(f_upper_decade), 50); 
                
                f_dense_start = max(f_plot_center_sim * 0.1, f_plot_center_sim - (4 * bw_hz));
                f_dense_stop  = f_plot_center_sim + (4 * bw_hz);
                f_dense  = linspace(f_dense_start, f_dense_stop, 60); 
                
                freq_wide = unique(sort([f_coarse, f_dense]));
                wide_mags = zeros(size(freq_wide));
                
                set_param(modelName, 'FastRestart', 'on');
                for i = 1:length(freq_wide)
                    f_c = freq_wide(i);
                    w_c = 2 * pi * f_c;
                    t_stop = max(4e-6, 10/f_c);
                    set_param(modelName, 'StopTime', num2str(t_stop));
                    set_param([modelName '/Input_Signal'], 'Frequency', num2str(w_c));
                    simOut = sim(modelName);
                    sig = simOut.yout.get(1); data_w = sig.Values.Data;
                    n_s = length(data_w); ss_w = data_w(floor(n_s*0.8):end);
                    peak_val = (max(ss_w) - min(ss_w)) / 2;
                    if peak_val < 1e-12, peak_val = 1e-12; end
                    wide_mags(i) = 20 * log10(peak_val);
                    d.Value = 0.3 + 0.7 * (i/length(freq_wide));
                end
                close(d);
                set_param(modelName, 'FastRestart', 'off');

                cla(app.axSimWide);
                semilogx(app.axSimWide, freq_wide, wide_mags, 'r.-', 'LineWidth', app.Plot_Line_Width, 'MarkerSize', app.Plot_Marker_Size);
                xlim(app.axSimWide, [f_lower_decade, f_upper_decade]); 
                grid(app.axSimWide, 'on');
                title(app.axSimWide, 'Wideband Response (Simulated)');
                xlabel(app.axSimWide, 'Frequency (Hz)'); ylabel(app.axSimWide, 'Gain (dB)');
                xline(app.axSimWide, f0, 'm--', 'Label', 'f0','FontSize', app.Font_Annotations, 'FontWeight', 'bold');

                set_param([modelName '/Input_Signal'], 'Frequency', num2str(2*pi*f0));
                set_param(modelName, 'FixedStep', '1e-9'); 
                set_param(modelName, 'StopTime', '4e-6');  
                
                app.lblStatus.Text = 'Plotting Realized Pole/Zero...'; drawnow;
                
                customParams = [];
                if (Order == 2 || Order == 4) && strcmp(app.swCustomTF.Value, 'On')
                    [customParams, isValid, errMsg] = app.parseCustomTF(Order);
                    if ~isValid
                        uialert(app.UIFigure, errMsg, 'Custom TF Error');
                        return;
                    end
                end

                [g_res, c_taps] = app.calcCRFF_Coeffs(Order);
                sys_real = app.getCRFF_SS(Order, w0, Q, A_lin, g_res, c_taps, customParams);
                
                half_span_real = 3.5 * (app.efBW.Value * 1e6);
                f_real_start = max(f0 * 0.05, f0 - half_span_real); % Safety floor applied
                f_real_stop = f0 + half_span_real;
                freqs_real = linspace(f_real_start, f_real_stop, 50000);
                [~, ph_real] = bode(sys_real, 2*pi*freqs_real);
                
                cla(app.axPhaseSim);
                plot(app.axPhaseSim, freqs_real/fScale, squeeze(ph_real), 'Color', 'r', 'LineWidth', app.Plot_Line_Width);
                grid(app.axPhaseSim, 'on');
                title(app.axPhaseSim, sprintf('Realized Phase Response (DC Gain=%.1fdB)', GainDB));
                xlabel(app.axPhaseSim, sprintf('Frequency (%s)', fUnit));
                ylabel(app.axPhaseSim, 'Phase (deg)');
                xline(app.axPhaseSim, f0/fScale, 'm--', 'Label', 'f0','FontSize', app.Font_Annotations, 'FontWeight', 'bold');
                
                cla(app.axPZSim);
                p_real = pole(sys_real); z_real = tzero(sys_real); 
                plot(app.axPZSim, real(p_real), imag(p_real), 'x', 'MarkerSize', app.Plot_Marker_Size, 'LineWidth', app.Plot_Line_Width, 'Color', 'r');
                hold(app.axPZSim, 'on');
                if ~isempty(z_real)
                    plot(app.axPZSim, real(z_real), imag(z_real), 'o', 'MarkerSize', app.Plot_Marker_Size, 'LineWidth', app.Plot_Line_Width, 'Color', app.CustomBlue);
                end
                hold(app.axPZSim, 'off');
                grid(app.axPZSim, 'on');
                title(app.axPZSim, 'Realized Pole-Zero Map (Finite Gain)');
                xlabel(app.axPZSim, 'Real Axis'); ylabel(app.axPZSim, 'Imag Axis');
                
                app.applyGlobalFonts();

                app.lblStatus.Text = 'Simulation Done!';
                app.lblStatus.FontColor = [0 0.6 0]; 
                app.txtArea.Value = [app.txtArea.Value; 'Wide Sweep & Realized Plots Complete.'];
                
            catch ME
                if exist('d', 'var'), close(d); end
                try set_param(modelName, 'FastRestart', 'off'); catch, end 
                app.lblStatus.Text = 'Sim Failed';
                app.lblStatus.FontColor = [1 0 0];
                uialert(app.UIFigure, ME.message, 'Simulation Error');
            end
        end

        % Helper: Build Simulink Section (With Custom a1, a2)
        function buildSimulinkSection(~, model, prefix, x_pos, w0, damping, res, taps, A_lin, a1, a2)
            if nargin < 10, a1 = 1; a2 = 1; end
            
            y_m = 300; y_f = 450; y_d = 200; y_o = 100;
            y_leak = 380; 
            leak_gain = -1/A_lin; 
            
            add_block('simulink/Math Operations/Sum', [model '/' prefix '_Sum'], ...
                'Position', [x_pos, y_m-15, x_pos+20, y_m+15], 'Inputs', '|++++'); 
            add_block('simulink/Math Operations/Gain', [model '/' prefix '_Gain_w0_1'], ...
                'Position', [x_pos+80, y_m-15, x_pos+130, y_m+15], 'Gain', num2str(a1 * w0));
            add_block('simulink/Continuous/Integrator', [model '/' prefix '_Int1'], ...
                'Position', [x_pos+150, y_m-15, x_pos+180, y_m+15]);
            add_block('simulink/Math Operations/Gain', [model '/' prefix '_FB_Leak1'], ...
                'Position', [x_pos+80, y_leak, x_pos+130, y_leak+30], 'Gain', num2str(leak_gain), 'Orientation', 'left');
                
            add_block('simulink/Math Operations/Sum', [model '/' prefix '_Sum_Int2'], ...
                'Position', [x_pos+210, y_m-15, x_pos+230, y_m+15], 'Inputs', '|++');
            add_block('simulink/Math Operations/Gain', [model '/' prefix '_Gain_w0_2'], ...
                'Position', [x_pos+250, y_m-15, x_pos+300, y_m+15], 'Gain', num2str(a2 * w0));
            add_block('simulink/Continuous/Integrator', [model '/' prefix '_Int2'], ...
                'Position', [x_pos+320, y_m-15, x_pos+350, y_m+15]);
            add_block('simulink/Math Operations/Gain', [model '/' prefix '_FB_Leak2'], ...
                'Position', [x_pos+250, y_leak, x_pos+300, y_leak+30], 'Gain', num2str(leak_gain), 'Orientation', 'left');
            
            add_block('simulink/Math Operations/Gain', [model '/' prefix '_FB_Res'], ...
                'Position', [x_pos+180, y_f, x_pos+230, y_f+30], 'Gain', num2str(res), 'Orientation', 'left');
            add_block('simulink/Math Operations/Gain', [model '/' prefix '_FB_Damp'], ...
                'Position', [x_pos+80, y_d, x_pos+130, y_d+30], 'Gain', num2str(damping), 'Orientation', 'left');
                
            add_block('simulink/Math Operations/Gain', [model '/' prefix '_Tap_BP'], ...
                'Position', [x_pos+200, y_o+50, x_pos+250, y_o+80], 'Gain', num2str(taps.bp));
            add_block('simulink/Math Operations/Gain', [model '/' prefix '_Tap_LP'], ...
                'Position', [x_pos+350, y_o+50, x_pos+400, y_o+80], 'Gain', num2str(taps.lp));
            if isfield(taps, 'hp')
                add_block('simulink/Math Operations/Gain', [model '/' prefix '_Tap_HP'], ...
                    'Position', [x_pos+50, y_o+50, x_pos+100, y_o+80], 'Gain', num2str(taps.hp));
            end
            
            sum_inputs = '|++';
            if isfield(taps, 'hp'), sum_inputs = '|+++'; end
            
            add_block('simulink/Math Operations/Sum', [model '/' prefix '_OutSum'], ...
                'Position', [x_pos+500, y_o+50, x_pos+520, y_o+90], 'Inputs', sum_inputs);
                
            add_line(model, [prefix '_Sum/1'], [prefix '_Gain_w0_1/1']);
            add_line(model, [prefix '_Gain_w0_1/1'], [prefix '_Int1/1']);
            add_line(model, [prefix '_Int1/1'], [prefix '_FB_Leak1/1'], 'autorouting', 'on');
            add_line(model, [prefix '_FB_Leak1/1'], [prefix '_Sum/4'], 'autorouting', 'on');
            
            add_line(model, [prefix '_Int1/1'], [prefix '_Sum_Int2/1']);
            add_line(model, [prefix '_Sum_Int2/1'], [prefix '_Gain_w0_2/1']);
            add_line(model, [prefix '_Gain_w0_2/1'], [prefix '_Int2/1']);
            add_line(model, [prefix '_Int2/1'], [prefix '_FB_Leak2/1'], 'autorouting', 'on');
            add_line(model, [prefix '_FB_Leak2/1'], [prefix '_Sum_Int2/2'], 'autorouting', 'on');
            
            add_line(model, [prefix '_Int2/1'], [prefix '_FB_Res/1'], 'autorouting', 'on');
            add_line(model, [prefix '_FB_Res/1'], [prefix '_Sum/3'], 'autorouting', 'on'); 
            add_line(model, [prefix '_Int1/1'], [prefix '_FB_Damp/1'], 'autorouting', 'on');
            add_line(model, [prefix '_FB_Damp/1'], [prefix '_Sum/1'], 'autorouting', 'on'); 
            
            add_line(model, [prefix '_Int1/1'], [prefix '_Tap_BP/1'], 'autorouting', 'on');
            add_line(model, [prefix '_Tap_BP/1'], [prefix '_OutSum/2'], 'autorouting', 'on');
            add_line(model, [prefix '_Int2/1'], [prefix '_Tap_LP/1'], 'autorouting', 'on');
            add_line(model, [prefix '_Tap_LP/1'], [prefix '_OutSum/1'], 'autorouting', 'on'); 
            if isfield(taps, 'hp')
                add_line(model, [prefix '_Sum/1'], [prefix '_Tap_HP/1'], 'autorouting', 'on');
                add_line(model, [prefix '_Tap_HP/1'], [prefix '_OutSum/3'], 'autorouting', 'on');
            end
        end
        
        function H = constructTF(~, Stages, w0, ~, alpha)
            H = tf(1,1);
            for s = 1:length(Stages)
                g_hp = Stages(s).coeffs(1); g_bp = Stages(s).coeffs(2); g_lp = Stages(s).coeffs(3);
                den = [1, 2*alpha, (alpha^2 + w0^2)];
                n_s2 = g_hp; n_s1 = g_bp * w0; n_s0 = (g_bp * w0 * alpha) + (g_lp * w0^2);
                H_Stage = tf([n_s2, n_s1, n_s0], den);
                H = H * H_Stage;
            end
        end
    end

    % =================================================================
    % UI SETUP
    % =================================================================
    methods (Access = public)
        function app = BETA_Bandpass_Tool_alpha
            createComponents(app);
            registerApp(app, app.UIFigure);
            if nargout == 0, clear app; end
        end

        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Name = 'BETA Filter Design & Analysis Tool';
            screenSize = get(0, 'ScreenSize'); 
            figW = screenSize(3)*0.85; figH = screenSize(4)*0.85;
            app.UIFigure.Position = [(screenSize(3)-figW)/2, (screenSize(4)-figH)/2, figW, figH];

            app.GridLayout = uigridlayout(app.UIFigure);
            %app.GridLayout.ColumnWidth = {280, '1x'}; app.GridLayout.RowHeight = {'1x'};
            % CHANGE 1: Make a 3-column grid (Left Panel, 5px Splitter, Right Plots)
            app.GridLayout.ColumnWidth = {280, 5, '1x'}; 
            app.GridLayout.RowHeight = {'1x'};

            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Title = 'Filter Settings';
            app.LeftPanel.Layout.Row = 1; app.LeftPanel.Layout.Column = 1;
            app.LeftPanel.FontSize = app.Font_UI_Labels; app.LeftPanel.FontWeight = 'bold';

            % CHANGE 2: Create the Splitter Panel in Column 2
            app.SplitterPanel = uipanel(app.GridLayout);
            app.SplitterPanel.Layout.Row = 1; 
            app.SplitterPanel.Layout.Column = 2;
            app.SplitterPanel.BorderType = 'none';
            app.SplitterPanel.BackgroundColor = [0.8 0.8 0.8]; % Light grey visual cue

            % CHANGE 3: Assign drag callbacks to the UIFigure and Splitter
            app.UIFigure.WindowButtonMotionFcn = createCallbackFcn(app, @onDragSplitter, true);
            app.UIFigure.WindowButtonUpFcn = createCallbackFcn(app, @onStopDrag, true);
            app.SplitterPanel.ButtonDownFcn = createCallbackFcn(app, @onStartDrag, true);
            
            app.InputGrid = uigridlayout(app.LeftPanel);
            app.InputGrid.ColumnWidth = {'fit', '1x'};
            
            app.InputGrid.RowHeight = {30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 40, 40, 40, 40, 30, '1x'};
            app.InputGrid.RowSpacing = app.Font_UI_Spacing; 

            % CHANGE 4: Move the TabGroup to Column 3
            app.TabGroup = uitabgroup(app.GridLayout); 
            app.TabGroup.Layout.Row = 1; 
            app.TabGroup.Layout.Column = 3; % Was previously 2

            % --- Standard Inputs (Rows 1 to 7) ---
            app.lblFreq = uilabel(app.InputGrid); app.lblFreq.Text = 'Center Freq (Hz)';
            app.lblFreq.Layout.Row = 1; app.lblFreq.Layout.Column = 1;
            app.efFreq = uieditfield(app.InputGrid, 'numeric');
            app.efFreq.Value = 64e6; app.efFreq.ValueChangedFcn = createCallbackFcn(app, @onFreqChanged, true);
            app.efFreq.BackgroundColor = '#2D2D2D'; app.efFreq.FontColor = [1 1 1];
            app.efFreq.Layout.Row = 1; app.efFreq.Layout.Column = 2;

            app.lblOrder = uilabel(app.InputGrid); app.lblOrder.Text = 'Filter Order';
            app.lblOrder.Layout.Row = 2; app.lblOrder.Layout.Column = 1;
            app.ddOrder = uidropdown(app.InputGrid); app.ddOrder.Items = {'2', '4', '6'}; app.ddOrder.Value = '4';
            app.ddOrder.ValueChangedFcn = createCallbackFcn(app, @onOrderChanged, true);
            app.ddOrder.BackgroundColor = '#2D2D2D'; app.ddOrder.FontColor = [1 1 1];
            app.ddOrder.Layout.Row = 2; app.ddOrder.Layout.Column = 2;

            app.lblQ = uilabel(app.InputGrid); app.lblQ.Text = 'Resonator Q';
            app.lblQ.FontWeight = 'bold'; app.lblQ.Layout.Row = 3; app.lblQ.Layout.Column = 1;
            app.efQ = uieditfield(app.InputGrid, 'numeric');
            app.efQ.Value = 50.00; app.efQ.ValueChangedFcn = createCallbackFcn(app, @onQChanged, true);
            app.efQ.BackgroundColor = '#2D2D2D'; app.efQ.FontColor = [1 1 1];
            app.efQ.Layout.Row = 3; app.efQ.Layout.Column = 2;

            app.lblBW = uilabel(app.InputGrid); app.lblBW.Text = 'Target BW (MHz)';
            app.lblBW.FontWeight = 'bold'; app.lblBW.Layout.Row = 4; app.lblBW.Layout.Column = 1;
            app.efBW = uieditfield(app.InputGrid, 'numeric');
            app.efBW.Value = 0.83; app.efBW.ValueChangedFcn = createCallbackFcn(app, @onBWChanged, true);
            app.efBW.BackgroundColor = '#2D2D2D'; app.efBW.FontColor = [1 1 1];
            app.efBW.Layout.Row = 4; app.efBW.Layout.Column = 2;

            app.lblMinGain = uilabel(app.InputGrid); app.lblMinGain.Text = 'Min DC Gain (dB)';
            app.lblMinGain.FontWeight = 'bold'; app.lblMinGain.Layout.Row = 5; app.lblMinGain.Layout.Column = 1;
            app.efMinGain = uieditfield(app.InputGrid, 'numeric');
            app.efMinGain.Value = 60.00; app.efMinGain.ValueChangedFcn = createCallbackFcn(app, @onMinGainChanged, true);
            app.efMinGain.BackgroundColor = '#2D2D2D'; app.efMinGain.FontColor = [1 1 1];
            app.efMinGain.Layout.Row = 5; app.efMinGain.Layout.Column = 2;

            app.lblOverride = uilabel(app.InputGrid); app.lblOverride.Text = 'Manual Gain';
            app.lblOverride.Layout.Row = 6; app.lblOverride.Layout.Column = 1;
            app.swOverride = uiswitch(app.InputGrid, 'slider');
            app.swOverride.Layout.Row = 6; app.swOverride.Layout.Column = 2;
            app.swOverride.ValueChangedFcn = createCallbackFcn(app, @onOverrideChanged, true);

            app.lblIntGain = uilabel(app.InputGrid); app.lblIntGain.Text = 'Integrator Gain (dB)';
            app.lblIntGain.Layout.Row = 7; app.lblIntGain.Layout.Column = 1;
            app.efIntGain = uieditfield(app.InputGrid, 'numeric');
            app.efIntGain.Value = 60.00; app.efIntGain.Editable = 'off';
            app.efIntGain.BackgroundColor = '#2D2D2D'; app.efIntGain.FontColor = [1 1 1];
            app.efIntGain.Layout.Row = 7; app.efIntGain.Layout.Column = 2;
            
            % --- CUSTOM TF CONTROLS (Rows 8 to 11) ---
            app.lblCustomTF = uilabel(app.InputGrid); app.lblCustomTF.Text = 'Custom TF (4th)';
            app.lblCustomTF.Layout.Row = 8; app.lblCustomTF.Layout.Column = 1;
            app.swCustomTF = uiswitch(app.InputGrid, 'slider');
            app.swCustomTF.Layout.Row = 8; app.swCustomTF.Layout.Column = 2;
            app.swCustomTF.ValueChangedFcn = createCallbackFcn(app, @onCustomTFChanged, true);
            
            app.lblCustomNum = uilabel(app.InputGrid); app.lblCustomNum.Text = 'Num [s^3..s^0]';
            app.lblCustomNum.Layout.Row = 9; app.lblCustomNum.Layout.Column = 1;
            app.efCustomNum = uieditfield(app.InputGrid, 'text');
            app.efCustomNum.Value = '[0.3, 0.9, 1.2, 1.2]'; 
            app.efCustomNum.BackgroundColor = '#2D2D2D'; app.efCustomNum.FontColor = [1 1 1];
            app.efCustomNum.Layout.Row = 9; app.efCustomNum.Layout.Column = 2;
            app.efCustomNum.Enable = 'off';
            
            app.lblCustomDen = uilabel(app.InputGrid); app.lblCustomDen.Text = 'Den [s^4..s^0]';
            app.lblCustomDen.Layout.Row = 10; app.lblCustomDen.Layout.Column = 1;
            app.efCustomDen = uieditfield(app.InputGrid, 'text');
            app.efCustomDen.Value = '[1, 0.04, 2.0004, 0.04, 1]'; 
            app.efCustomDen.ValueChangedFcn = createCallbackFcn(app, @onCustomDenChanged, true);
            app.efCustomDen.ValueChangingFcn = createCallbackFcn(app, @onCustomDenChanged, true);
            app.efCustomDen.BackgroundColor = '#2D2D2D'; app.efCustomDen.FontColor = [1 1 1];
            app.efCustomDen.Layout.Row = 10; app.efCustomDen.Layout.Column = 2;
            app.efCustomDen.Enable = 'off';
            
            app.lblCustomInt = uilabel(app.InputGrid); app.lblCustomInt.Text = 'Int [a1..a4]';
            app.lblCustomInt.Layout.Row = 11; app.lblCustomInt.Layout.Column = 1;
            app.efCustomInt = uieditfield(app.InputGrid, 'text');
            app.efCustomInt.Value = '[1, 1, 1, 1]'; 
            app.efCustomInt.BackgroundColor = '#2D2D2D'; app.efCustomInt.FontColor = [1 1 1];
            app.efCustomInt.Layout.Row = 11; app.efCustomInt.Layout.Column = 2;
            app.efCustomInt.Enable = 'off';

            % --- Buttons (Rows 12 to 15) ---
            app.btnRun = uibutton(app.InputGrid, 'push');
            app.btnRun.Text = 'Analyze Filter';
            app.btnRun.FontSize = app.Font_UI_Labels; app.btnRun.FontWeight = 'bold';
            app.btnRun.BackgroundColor = app.CustomBlue; app.btnRun.FontColor = [1 1 1];
            app.btnRun.Layout.Row = 12; app.btnRun.Layout.Column = [1, 2];
            app.btnRun.ButtonPushedFcn = createCallbackFcn(app, @onRunButton, true);
            
            app.btnGenSim = uibutton(app.InputGrid, 'push');
            app.btnGenSim.Text = 'Generate Simulink Model';
            app.btnGenSim.FontSize = app.Font_UI_Labels; app.btnGenSim.FontWeight = 'bold';
            app.btnGenSim.BackgroundColor = [1.0 0.5 0.0]; app.btnGenSim.FontColor = [1 1 1];
            app.btnGenSim.Layout.Row = 13; app.btnGenSim.Layout.Column = [1, 2];
            app.btnGenSim.ButtonPushedFcn = createCallbackFcn(app, @onGenSimulink, true);

            app.btnRunSim = uibutton(app.InputGrid, 'push');
            app.btnRunSim.Text = 'Run Simulink Sim';
            app.btnRunSim.FontSize = app.Font_UI_Labels; app.btnRunSim.FontWeight = 'bold';
            app.btnRunSim.BackgroundColor = [0.1 0.7 0.3]; app.btnRunSim.FontColor = [1 1 1];
            app.btnRunSim.Layout.Row = 14; app.btnRunSim.Layout.Column = [1, 2];
            app.btnRunSim.ButtonPushedFcn = createCallbackFcn(app, @onRunSimulink, true);
            
            app.btnGenVA = uibutton(app.InputGrid, 'push');
            app.btnGenVA.Text = 'Generate Verilog-A';
            app.btnGenVA.FontSize = app.Font_UI_Labels; app.btnGenVA.FontWeight = 'bold';
            app.btnGenVA.BackgroundColor = [0.6 0.2 0.6]; app.btnGenVA.FontColor = [1 1 1];
            app.btnGenVA.Layout.Row = 15; app.btnGenVA.Layout.Column = [1, 2];
            app.btnGenVA.ButtonPushedFcn = createCallbackFcn(app, @onGenVerilogA, true);
            
            % --- Status (Row 16) ---
            app.lblStatus = uilabel(app.InputGrid);
            app.lblStatus.Text = 'Ready'; app.lblStatus.HorizontalAlignment = 'center';
            app.lblStatus.FontColor = [0.5 0.5 0.5];
            app.lblStatus.Layout.Row = 16; app.lblStatus.Layout.Column = [1, 2];

            %app.TabGroup = uitabgroup(app.GridLayout); app.TabGroup.Layout.Row = 1; app.TabGroup.Layout.Column = 2;
            
            app.tMag = uitab(app.TabGroup, 'Title', 'Magnitude');
            app.gMag = uigridlayout(app.tMag); app.gMag.ColumnWidth = {'1x'}; app.gMag.RowHeight = {'65x', '35x'}; 
            app.axMag = uiaxes(app.gMag); app.axMag.Layout.Row = 1; app.axMag.Layout.Column = 1;
            app.axMagWide = uiaxes(app.gMag); app.axMagWide.Layout.Row = 2; app.axMagWide.Layout.Column = 1;
            
            app.tPhase = uitab(app.TabGroup, 'Title', 'Phase');
            app.gPhase = uigridlayout(app.tPhase); app.gPhase.ColumnWidth = {'1x'}; app.gPhase.RowHeight = {'1x', '1x'};
            app.axPhase = uiaxes(app.gPhase); app.axPhase.Layout.Row = 1; app.axPhase.Layout.Column = 1; app.axPhase.Title.String = 'Phase Response';
            app.axPhaseSim = uiaxes(app.gPhase); app.axPhaseSim.Layout.Row = 2; app.axPhaseSim.Layout.Column = 1; app.axPhaseSim.Title.String = 'Realized Phase Response (Simulated)';
            
            app.tPZ = uitab(app.TabGroup, 'Title', 'Pole-Zero Map');
            app.gPZ = uigridlayout(app.tPZ); app.gPZ.ColumnWidth = {'1x'}; app.gPZ.RowHeight = {'1x', '1x'};
            app.axPZ = uiaxes(app.gPZ); app.axPZ.Layout.Row = 1; app.axPZ.Layout.Column = 1; app.axPZ.Title.String = 'Pole-Zero Map';
            app.axPZSim = uiaxes(app.gPZ); app.axPZSim.Layout.Row = 2; app.axPZSim.Layout.Column = 1; app.axPZSim.Title.String = 'Realized Pole-Zero Map (Simulated)';
            
            app.tEq = uitab(app.TabGroup, 'Title', 'Equations');
            app.gEq = uigridlayout(app.tEq); app.gEq.ColumnWidth = {'1x'}; app.gEq.RowHeight = {'1x', '1x'}; 
            app.pnlNorm = uipanel(app.gEq); app.pnlNorm.Title = 'Normalized Transfer Function';
            app.pnlNorm.Layout.Row = 1; app.pnlNorm.Layout.Column = 1; app.pnlNorm.FontWeight = 'bold';
            normLayout = uigridlayout(app.pnlNorm); normLayout.ColumnWidth = {'1x'}; normLayout.RowHeight = {'1x'};
            app.txtNorm = uitextarea(normLayout); app.txtNorm.Layout.Row = 1; app.txtNorm.Layout.Column = 1;
            app.txtNorm.FontName = 'Courier New'; app.txtNorm.FontSize = app.Font_Annotations; app.txtNorm.Editable = 'off'; app.txtNorm.WordWrap = 'off'; 
            app.pnlReal = uipanel(app.gEq); app.pnlReal.Title = 'Realized Transfer Function';
            app.pnlReal.Layout.Row = 2; app.pnlReal.Layout.Column = 1; app.pnlReal.FontWeight = 'bold';
            realLayout = uigridlayout(app.pnlReal); realLayout.ColumnWidth = {'1x'}; realLayout.RowHeight = {'1x'};
            app.txtReal = uitextarea(realLayout); app.txtReal.Layout.Row = 1; app.txtReal.Layout.Column = 1;
            app.txtReal.FontName = 'Courier New'; app.txtReal.FontSize = app.Font_Annotations; app.txtReal.Editable = 'off'; app.txtReal.WordWrap = 'off';
            
            app.tSim = uitab(app.TabGroup, 'Title', 'Simulink Results');
            app.gSim = uigridlayout(app.tSim); app.gSim.ColumnWidth = {'1x'}; app.gSim.RowHeight = {'1x', '1x', '1x'};
            app.axSimTime = uiaxes(app.gSim); app.axSimTime.Layout.Row = 1; app.axSimTime.Layout.Column = 1; app.axSimTime.Title.String = 'Transient Response (Time)';
            app.axSimFreq = uiaxes(app.gSim); app.axSimFreq.Layout.Row = 2; app.axSimFreq.Layout.Column = 1; app.axSimFreq.Title.String = 'Narrow Frequency Response (Sweep)';
            app.axSimWide = uiaxes(app.gSim); app.axSimWide.Layout.Row = 3; app.axSimWide.Layout.Column = 1; app.axSimWide.Title.String = 'Wide Frequency Response (Sweep)';

            app.tText = uitab(app.TabGroup, 'Title', 'Output Log');
            app.gText = uigridlayout(app.tText); app.gText.ColumnWidth = {'1x'}; app.gText.RowHeight = {'1x'};
            app.txtArea = uitextarea(app.gText); app.txtArea.Layout.Row = 1; app.txtArea.Layout.Column = 1; app.txtArea.FontName = 'Monospaced';

            app.applyGlobalFonts();
            app.UIFigure.Visible = 'on';
        end
    end
end