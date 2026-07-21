%% Setup- und Initialisierungsfunktionen

function CV_ECSA(referenceFolder)
    % Hauptfunktion, die den gesamten Ablauf steuert.
    % Diese Funktion richtet die GUI ein und fügt erforderliche Pfade hinzu.
    %
    % Args:
    %    referenceFolder (string): Pfad zum Ordner mit den Referenzdaten
    try
        %Abruf der config.json und vervollständigen des Pfades zum Referenzordner
        currentRef = referenceFolder;
        configFile = fullfile(currentRef, 'config.json');
        fid = fopen(configFile, 'r');
        jsonData = fscanf(fid, '%c');
        fclose(fid);
        configData = jsondecode(jsonData);
        cv_config = configData.CV_ECSA;
        assignin("base", "currentRef", currentRef)
        assignin("base", "config", cv_config)

        referenceFolder = fullfile(referenceFolder, 'CV_ECSA');
        
        % Aktuelles Fenster laden und benennen
        fig = evalin('base', 'fig'); 
        fig.Name = 'CV-ECSA';

        % Setup des GUI
        delete(fig.Children);
        createBackButton(fig); 
        setupFigure(fig); 
        createParameterFields(fig);
        createConfigBtn(fig); 

        % GUI neu laden um Änderungen sicher anzuzeigen
        drawnow;

        % Event-Listener für die Größenänderung des Fensters hinzufügen
        fig.SizeChangedFcn = @(src, event) resizeUIComponents(fig);
        fig.AutoResizeChildren = 'off';  % Deaktivieren der automatischen Größenanpassung

        % Anpassung der Objekte an die Fenstergröße
        resizeUIComponents(fig);

        % Referenzdaten einlesen
        assignin("base", 'referenceFolder', referenceFolder)
        getReferences(fig);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Öffnen des CV-ECSA-Fensters.')
        disp(ME.message)
    end
end

function setupFigure(fig)
    % Setup des Fensters
    %
    % Args:
    %    fig (handle): Handle des Fensters
    try
        % Plotbereich einfügen
        ax = uiaxes(fig, ...
            'Position', [20, 130, fig.Position(3) - 200, fig.Position(4) - 140], ...
            'Tag', 'plotAxes');

        % Achsenlimits und Label setzen
        ax.XLim = [0, 0.9];
        ax.YLim = [-2, 2];
        xlabel(ax, 'Voltage [V]');  
        ylabel(ax, 'Current [A]'); 
        legend(ax, 'Location', 'southeast');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Plotfensters.')
        disp(ME.message)
    end
end

function createConfigBtn(fig)
    try
        uibutton(fig, 'Text', 'CV-ECSA config', 'Position', [fig.Position(3) - 175, fig.Position(4) - 40, 155, 22], ...
            'ButtonPushedFcn', @(btn, event) runMethodScript('CV_ECSA', fig), 'Tag', 'configButton');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Config-Buttons.')
        disp(ME.message)
    end
end

function runMethodScript(method, fig)
    try
        % Diese Funktion führt das Auswertungsskript aus.
        referenceFolder = getappdata(0, 'currentReference');

        % Pfad zum Methodenskript
        scriptDir = fileparts(fileparts(mfilename('fullpath')));
        scriptPath = fullfile(scriptDir, 'Referenzen', 'editAllConfig.m');

        % Speichere das Figur-Handle und den Referenzordner im Base Workspace
        assignin('base', 'referenceFolder', referenceFolder);

        % Extrahiere den Dateinamen ohne Pfad und Erweiterung
        [scriptDir, scriptName, ~] = fileparts(scriptPath);

        % Erstelle einen Funktionshandle aus dem Dateinamen und Verzeichnis
        functionHandle = str2func(scriptName);

        % Sicherstellen, dass das Skript eine Funktion ist und existiert
        if exist(scriptPath, 'file') == 2
            % Wechsle in das Verzeichnis des Skripts
            originalDir = cd(scriptDir);

            % Rufe die Funktion auf
            feval(functionHandle, method, referenceFolder);

            % Wechsle zurück in das ursprüngliche Verzeichnis
            cd(originalDir);

            % Fenster-Griff (Handle) holen
            config_fig = findall(0, 'Type', 'figure', 'Name', 'CV-ECSA Einstellungen'); 

            % Setze den CloseRequestFcn-Callback
            addlistener(config_fig, 'ObjectBeingDestroyed', @(src, event) onCloseCallback(src, event, fig));
        else
            error('Das Skript %s existiert nicht.', scriptPath);
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Öffnen der Config.')
        disp(ME.message)
    end
end

function onCloseCallback(src, ~, fig)
    try
        disp('closed')
        currentRef = evalin("base", 'currentRef');

        configFile = fullfile(currentRef, 'config.json');
        fid = fopen(configFile, 'r');
        jsonData = fscanf(fid, '%c');
        fclose(fid);
        configData = jsondecode(jsonData);
        cv_config = configData.CV_ECSA;
        assignin("base", "config", cv_config)

        recalcRef(fig)

        % Vermeiden Sie rekursive Aufrufe, indem Sie src löschen
        if isvalid(src)
            delete(src);
        end
    catch ME
        if ~exist("fig") %#ok<EXIST>
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Schließen des Fensters.')
        disp(ME.message)
    end
end

function createParameterFields(fig)
    % Parameterfelder und Buttons einfügen
    %
    % Args:
    %    fig (handle): Handle des Fensters
    try
        % config laden
        config = evalin("base", 'config');

        % Definieren der Standardwerte
        defaultTitle1 = config.Titel1;
        defaultTitle2 = config.Titel2;
        StartIntCath = config.StartIntCath;
        StartIntAn = config.StartIntAn;
        PtLoading = config.PtLoading;
        Area = config.Flaeche;
        showReference = config.checkRef;
        showDUT = config.checkDUT;
        showFast = config.checkFast;
        showSlow = config.checkSlow;
        showECSA = config.checkECSA;

        % Textfelder und Label einfügen
        createTextFields(fig, defaultTitle1{1} , defaultTitle2{1}, StartIntCath, StartIntAn, PtLoading, Area);

        % Checkboxen einfügen
        createCheckboxes(fig, showReference, showDUT, showFast, showSlow, showECSA);

        % Ergebnisbereiche einfügen
        createResultsArea(fig);

        % Dropdown einfügen
        createCycleDropdown(fig);

        % Buttons einfügen
        createDataButtons(fig);

        uibutton(fig, 'push', 'Text', 'Help', ...
            'Position', [656.5, 100, 55, 22], ...
            'ButtonPushedFcn', @(btn, event) helpButton(), ...
            'Tag', 'Help');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen der Parameterfelder.')
        disp(ME.message)
    end
end

function createTextFields(fig, defaultTitle1, defaultTitle2, StartIntCath, StartIntAn, PtLoading, Area)
    % Textfelder und Label einfügen
    %
    % Args:
    %    fig (handle): Handle des Fensters
    %    defaultTitle1 (str): Standardtitelzeile 1
    %    defaultTitle2 (str): Standardtitelzeile 2
    %    StartIntCath (str): Standardintegrationsstart Kathodisch
    %    StartIntAn (str): Standardintegrationsstart Anodisch
    %    PtLoading (str): Standardwert für Pt loading
    %    Area (str): Standardwert für die Fläche
    try
        % Titeleingabefelder mit Label einfügen
        uilabel(fig, 'Position', [20, 100, 65, 22], 'Text', 'Titel Zeile 1:', 'Tag', 'title1Label'); 
        uieditfield(fig, 'text', 'Position', [95, 100, fig.Position(3) - 342.5, 22], 'Value', defaultTitle1, 'Tag', 'title1');

        uilabel(fig, 'Position', [20, 70, 65, 22], 'Text', 'Titel Zeile 2:', 'Tag', 'title2Label');
        uieditfield(fig, 'text', 'Position', [95, 70, fig.Position(3) - 282.5, 22], 'Value', defaultTitle2, 'Tag', 'title2');

        % Breite der Parameterfelder
        width = 155;

        % Parameterfelder mit Labels einfügen
        uilabel(fig, 'Position', [fig.Position(3) - 175, 454, width, 22], 'Text', 'Start integration cathodic [V]:', 'Tag', 'StartIntCathLabel');
        uieditfield(fig, 'numeric', 'Position', [fig.Position(3) - 175, 434, width, 22], 'Value', StartIntCath, 'Tag', 'StartIntCath', 'ValueChangedFcn', @(src, event) loadData(fig));

        uilabel(fig, 'Position', [fig.Position(3) - 175, 411, width, 22], 'Text', 'Start integration anodic [V]:', 'Tag', 'StartIntAnLabel');
        uieditfield(fig, 'numeric', 'Position', [fig.Position(3) - 175, 391, width, 22], 'Value', StartIntAn, 'Tag', 'StartIntAn', 'ValueChangedFcn', @(src, event) loadData(fig));

        uilabel(fig, 'Position', [fig.Position(3) - 175, 368, width, 22], 'Text', 'Pt loading [mg/cm²]:', 'Tag', 'PtLoadingLabel');
        uieditfield(fig, 'numeric', 'Position', [fig.Position(3) - 175, 348, width, 22], 'Value', PtLoading, 'Tag', 'PtLoading', 'ValueChangedFcn', @(src, event) loadData(fig), 'ValueDisplayFormat', '%11.5g');

        uilabel(fig, 'Position', [fig.Position(3) - 175, 328, width, 22], 'Text', 'Active area [cm²]:', 'Tag', 'AreaLabel');
        uieditfield(fig, 'numeric', 'Position', [fig.Position(3) - 175, 308, width, 22], 'Value', Area, 'Tag', 'Area', 'ValueChangedFcn', @(src, event) loadData(fig));
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen der Textfelder.')
        disp(ME.message)
    end
end

function createCheckboxes(fig, showReference, showDUT, showFast, showSlow, showECSA)
    % Checkboxen für die Plotoptionen einfügen
    %
    % Args:
    %    fig (handle): Handle des Fensters
    %    showReference (logical): Standardwert ob Referenzdaten gezeigt werden sollen
    %    showDUT (logical): Standardwert ob DUT-Daten gezeigt werden sollen
    %    showFast (logical): Standardwert ob schnelle Daten gezeigt werden sollen
    %    showSlow (logical): Standardwert ob langsame Daten gezeigt werden sollen
    try
        width = 155;

        uicheckbox(fig, 'Text', 'Referenzdaten anzeigen', 'Position', [fig.Position(3) - 175, 130, width, 22], 'Value', showReference, 'Tag', 'showReference');

        uicheckbox(fig, 'Text', 'DUT anzeigen', 'Position', [fig.Position(3) - 175, 110, width, 22], 'Value', showDUT, 'Tag', 'showDUT');

        uicheckbox(fig, 'Text', 'fast Data anzeigen', 'Position', [fig.Position(3) - 175, 85, width, 22], 'Value', showFast, 'Tag', 'showFast');

        uicheckbox(fig, 'Text', 'slow Data anzeigen', 'Position', [fig.Position(3) - 175, 65, width, 22], 'Value', showSlow, 'Tag', 'showSlow');

        uicheckbox(fig, 'Text', 'ECSA-Ø anzeigen', 'Position', [fig.Position(3) - 175, 40, width, 22], 'Value', showECSA, 'Tag', 'showECSA');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen der Checkboxen.')
        disp(ME.message)
    end
end

function createResultsArea(fig)
    % Textbereich für Ergebnisse einfügen
    %
    % Args:
    %    fig (handle): Handle des Fensters
    try
        % config laden
        config = evalin("base", 'config');
        decimal = config.Nachkommastellen;
        width = 50;
        distance = 2.5;
        uilabel(fig, 'Position', [fig.Position(3) - 175, 285, 3*width, 22], 'Text', 'ECSA [m²/gPt]:', 'Tag', 'All_ECSALabel');

        formatstring = sprintf('%%.%df', decimal);

        uilabel(fig, 'Position', [fig.Position(3) - (175 - 0 * (width + distance)), 270, width, 22], 'Text', 'Ref - Ø:', 'Tag', 'Ref_ECSALabel');
        uilabel(fig, 'Position', [fig.Position(3) - (175 - 1 * (width + distance)), 270, width, 22], 'Text', 'ads:', 'Tag', 'Ref_ads_ECSALabel');
        uilabel(fig, 'Position', [fig.Position(3) - (175 - 2 * (width + distance)), 270, width, 22], 'Text', 'des:', 'Tag', 'Ref_des_ECSALabel');
        uieditfield(fig, "numeric", 'Position', [fig.Position(3) - (175 - 0 * (width + distance)), 250, width, 22], 'Tag', 'ECSA_Ref', ...
            'Editable', 'off', 'ValueDisplayFormat', formatstring, 'ValueChangedFcn', @(~,~) recalcLoss(fig));
        uieditfield(fig, "numeric", 'Position', [fig.Position(3) - (175 - 1 * (width + distance)), 250, width, 22], 'Tag', 'ECSA_Ref_ads', ...
            'Editable', 'off', 'ValueDisplayFormat', formatstring, 'ValueChangedFcn', @(~,~) recalcLoss(fig));
        uieditfield(fig, "numeric", 'Position', [fig.Position(3) - (175 - 2 * (width + distance)), 250, width, 22], 'Tag', 'ECSA_Ref_des', ...
            'Editable', 'off', 'ValueDisplayFormat', formatstring, 'ValueChangedFcn', @(~,~) recalcLoss(fig));

        uilabel(fig, 'Position', [fig.Position(3) - (175 - 0 * (width + distance)), 225, width, 22], 'Text', 'DUT - Ø:', 'Tag', 'DUT_ECSALabel');
        uilabel(fig, 'Position', [fig.Position(3) - (175 - 1 * (width + distance)), 225, width, 22], 'Text', 'ads:', 'Tag', 'DUT_ads_ECSALabel');
        uilabel(fig, 'Position', [fig.Position(3) - (175 - 2 * (width + distance)), 225, width, 22], 'Text', 'des:', 'Tag', 'DUT_des_ECSALabel');
        uieditfield(fig, "numeric", 'Position', [fig.Position(3) - (175 - 0 * (width + distance)), 205, width, 22], 'Tag', 'ECSA_DUT', ...
            'Editable', 'off', 'ValueDisplayFormat', formatstring, 'ValueChangedFcn', @(~,~) recalcLoss(fig));
        uieditfield(fig, "numeric", 'Position', [fig.Position(3) - (175 - 1 * (width + distance)), 205, width, 22], 'Tag', 'ECSA_DUT_ads', ...
            'Editable', 'off', 'ValueDisplayFormat', formatstring, 'ValueChangedFcn', @(~,~) recalcLoss(fig));
        uieditfield(fig, "numeric", 'Position', [fig.Position(3) - (175 - 2 * (width + distance)), 205, width, 22], 'Tag', 'ECSA_DUT_des', ...
            'Editable', 'off', 'ValueDisplayFormat', formatstring, 'ValueChangedFcn', @(~,~) recalcLoss(fig));

        formatstring = ['%.', num2str(decimal), 'f%%'];

        uilabel(fig, 'Position', [fig.Position(3) - (175 - 0 * (width + distance)), 180, width, 22], 'Text', 'Verlust:', 'Tag', '%_ECSALabel');
        uilabel(fig, 'Position', [fig.Position(3) - (175 - 1 * (width + distance)), 180, width, 22], 'Text', 'ads:', 'Tag', '%_ads_ECSALabel');
        uilabel(fig, 'Position', [fig.Position(3) - (175 - 2 * (width + distance)), 180, width, 22], 'Text', 'des:', 'Tag', '%_des_ECSALabel');
        uieditfield(fig, "numeric", 'Position', [fig.Position(3) - (175 - 0 * (width + distance)), 160, width, 22], 'Tag', 'ECSA_%', ...
            'Editable', 'off',  "ValueDisplayFormat", formatstring);
        uieditfield(fig, "numeric", 'Position', [fig.Position(3) - (175 - 1 * (width + distance)), 160, width, 22], 'Tag', 'ECSA_%_ads', ...
            'Editable', 'off',  "ValueDisplayFormat", formatstring);
        uieditfield(fig, "numeric", 'Position', [fig.Position(3) - (175 - 2 * (width + distance)), 160, width, 22], 'Tag', 'ECSA_%_des', ...
            'Editable', 'off',  "ValueDisplayFormat", formatstring);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen der Ergebnisfelder.')
        disp(ME.message)
    end
end

function createCycleDropdown(fig)
    % Dropdown zur Zyklusauswahl einfügen
    %
    % Args:
    %    fig (handle): Handle des Fensters
    try
        width = 155;

        uidropdown(fig, ...
            'Position', [fig.Position(3) - 175, 477, width, 22], ...
            'Items', {'Cycle 1', 'Cycle 2', 'Cycle 3', 'Cycle 4'}, ... 
            'ValueChangedFcn', @(dd, event) updatePlot(fig, dd.Value), ...
            'Tag', 'cycleDropdown', 'Value', 'Cycle 4');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen der Dropdownliste.')
        disp(ME.message)
    end
end

function createDataButtons(fig)
    % Buttons zum Laden der schnellen und langsamen Daten, sowie Plotbutton
    % einfügen
    %
    % Args:
    %    fig (handle): Handle des Fensters
    %    standardPath (str): Standardpfad zur Datenauswahl
    try
        width = 155;

        % Load fast Data Button
        uibutton(fig, 'push', ...
            'Text', 'Load fast Data', ...
            'Position', [fig.Position(3) - 175, fig.Position(4) - 67, width, 22], ...
            'ButtonPushedFcn', @(btn, event) fastData(fig, []), ...
            'Tag', 'fastData');

        % Load slow Data Button
        uibutton(fig, 'push', ...
            'Text', 'Load slow Data', ...
            'Position', [fig.Position(3) - 175, fig.Position(4) - 94, width, 22], ...
            'ButtonPushedFcn', @(btn, event) slowData(fig, []), ...
            'Tag', 'slowData');

        % Plot Multiple Scans Button
        uibutton(fig, 'push', ...
            'Text', 'Plot Multiple Scans', ...
            'Position', [fig.Position(3) - 175, 504, width, 22], ...
            'ButtonPushedFcn', @(btn, event) multiplePlots(), ...
            'Tag', 'multiplePlots');

        % Plot Button
        uibutton(fig, 'push', ...
            'Text', 'Plot', ...
            'Position', [(fig.Position(3) / 2) - 210, 10, 200, 50], ...
            'ButtonPushedFcn', @(btn, event) PlotDataWrapper(fig), ...
            'Tag', 'plotButton');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen der Buttons.')
        disp(ME.message)
    end
end

function createBackButton(fig)
    % Erstellen des Zurück-Buttons
    %
    % Args:
    %    fig (handle): Handle des Fensters
    try
        uibutton(fig, 'push', ...
            'Text', 'Zurück zur Auswahl', ...
            'Position', [(fig.Position(3) / 2) + 10, 10, 200, 50], ...
            'ButtonPushedFcn', @(btn, event) backToSelection(fig), ...
            'Tag', 'backButton');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des zurück-Buttons.')
        disp(ME.message)
    end
end

%% Event-Handler und Callback-Funktionen

function resizeUIComponents(fig)
    % Größenanpassung aller Objekte im Fenster an die Fenstergröße
    %
    % Args:
    %    fig (handle): Handle des Fensters
    try
        % Aktuelle Fenstergröße bestimmen
        windowWidth = fig.Position(3);
        windowHeight = fig.Position(4);

        % Skalierungsfaktoren zur normalen Fenstergröße bestimmen
        widthScaleFactor = windowWidth / 900;
        heightScaleFactor = windowHeight / 625;
        margin = 20 * widthScaleFactor;
        width = 155 * widthScaleFactor;
        height = 22 * heightScaleFactor;
        resultWidth = 50 * widthScaleFactor;
        standard_x = 725 * widthScaleFactor;

        % Plotbereich skalieren
        resizeComponent(fig, 'plotAxes', [margin, 130 * heightScaleFactor, windowWidth - 200 * widthScaleFactor, windowHeight-140 * heightScaleFactor])

        % Titelzeilen skalieren
        resizeComponent(fig, 'title1Label',             [margin,                    100 * heightScaleFactor,     65 * widthScaleFactor, height])
        resizeComponent(fig, 'title1',                  [ 95 * widthScaleFactor,    100 * heightScaleFactor,    557.5*widthScaleFactor, height])
        resizeComponent(fig, 'title2Label',             [margin,                     70 * heightScaleFactor,     65 * widthScaleFactor, height])
        resizeComponent(fig, 'title2',                  [ 95 * widthScaleFactor,     70 * heightScaleFactor,    617.5*widthScaleFactor, height])

        % Parameterfelder und Dropdown skalieren
        resizeComponent(fig, 'configButton',            [standard_x,                585 * heightScaleFactor,    width,                  height])
        resizeComponent(fig, 'cycleDropdown',           [standard_x,                477 * heightScaleFactor,    width,                  height])
        resizeComponent(fig, 'StartIntCathLabel',       [standard_x,                454 * heightScaleFactor,    width,                  height])
        resizeComponent(fig, 'StartIntCath',            [standard_x,                434 * heightScaleFactor,    width,                  height])
        resizeComponent(fig, 'StartIntAnLabel',         [standard_x,                411 * heightScaleFactor,    width,                  height])
        resizeComponent(fig, 'StartIntAn',              [standard_x,                391 * heightScaleFactor,    width,                  height])
        resizeComponent(fig, 'PtLoadingLabel',          [standard_x,                368 * heightScaleFactor,    width,                  height])
        resizeComponent(fig, 'PtLoading',               [standard_x,                348 * heightScaleFactor,    width,                  height])
        resizeComponent(fig, 'AreaLabel',               [standard_x,                328 * heightScaleFactor,    width,                  height])
        resizeComponent(fig, 'Area',                    [standard_x,                308 * heightScaleFactor,    width,                  height])

        % Ergebnisfelder skalieren
        standard_x2 = 777.5 * widthScaleFactor;
        standard_x3 = 830 * widthScaleFactor;
        resizeComponent(fig, 'All_ECSALabel',           [standard_x,                285 * heightScaleFactor,    150 * widthScaleFactor, height])

        ECSA_y = 270 * heightScaleFactor;
        resizeComponent(fig, 'Ref_ECSALabel',           [standard_x,                ECSA_y,                     resultWidth,            height])
        resizeComponent(fig, 'Ref_ads_ECSALabel',       [standard_x2,               ECSA_y,                     resultWidth,            height])
        resizeComponent(fig, 'Ref_des_ECSALabel',       [standard_x3,               ECSA_y,                     resultWidth,            height])

        ECSA_y = 250 * heightScaleFactor;
        resizeComponent(fig, 'ECSA_Ref',                [standard_x,                ECSA_y,                     resultWidth,            height])
        resizeComponent(fig, 'ECSA_Ref_ads',            [standard_x2,               ECSA_y,                     resultWidth,            height])
        resizeComponent(fig, 'ECSA_Ref_des',            [standard_x3,               ECSA_y,                     resultWidth,            height])

        ECSA_y = 225 * heightScaleFactor;
        resizeComponent(fig, 'DUT_ECSALabel',           [standard_x,                ECSA_y,                     resultWidth,            height])
        resizeComponent(fig, 'DUT_ads_ECSALabel',       [standard_x2,               ECSA_y,                     resultWidth,            height])
        resizeComponent(fig, 'DUT_des_ECSALabel',       [standard_x3,               ECSA_y,                     resultWidth,            height])

        ECSA_y = 205 * heightScaleFactor;
        resizeComponent(fig, 'ECSA_DUT',                [standard_x,                ECSA_y,                     resultWidth,            height])
        resizeComponent(fig, 'ECSA_DUT_ads',            [standard_x2,               ECSA_y,                     resultWidth,            height])
        resizeComponent(fig, 'ECSA_DUT_des',            [standard_x3,               ECSA_y,                     resultWidth,            height])

        ECSA_y = 180 * heightScaleFactor;
        resizeComponent(fig, '%_ECSALabel',             [standard_x,                ECSA_y,                     resultWidth,            height])
        resizeComponent(fig, '%_ads_ECSALabel',         [standard_x2,               ECSA_y,                     resultWidth,            height])
        resizeComponent(fig, '%_des_ECSALabel',         [standard_x3,               ECSA_y,                     resultWidth,            height])

        ECSA_y = 160 * heightScaleFactor;
        resizeComponent(fig, 'ECSA_%',                  [standard_x,                ECSA_y,                     resultWidth,            height])
        resizeComponent(fig, 'ECSA_%_ads',              [standard_x2,               ECSA_y,                     resultWidth,            height])
        resizeComponent(fig, 'ECSA_%_des',              [standard_x3,               ECSA_y,                     resultWidth,            height])

        % Checkboxen skalieren
        resizeComponent(fig, 'showReference',           [standard_x,                130 * heightScaleFactor,    width,                  height])
        resizeComponent(fig, 'showDUT',                 [standard_x,                110 * heightScaleFactor,    width,                  height])
        resizeComponent(fig, 'showFast',                [standard_x,                 85 * heightScaleFactor,    width,                  height])
        resizeComponent(fig, 'showSlow',                [standard_x,                 65 * heightScaleFactor,    width,                  height])
        resizeComponent(fig, 'showECSA',                [standard_x,                 40 * heightScaleFactor,    width,                  height])

        % Buttons skalieren
        btn_y = 10 * heightScaleFactor;
        btn_width = 200 * widthScaleFactor;
        btn_height = 50 * heightScaleFactor;

        resizeComponent(fig, 'plotButton',              [240 * widthScaleFactor,    btn_y,                      btn_width,              btn_height])
        resizeComponent(fig, 'backButton',              [460 * widthScaleFactor,    btn_y,                      btn_width,              btn_height])
        resizeComponent(fig, 'fastData',                [standard_x,                558 * heightScaleFactor,    width,                  height])
        resizeComponent(fig, 'slowData',                [standard_x,                531 * heightScaleFactor,    width,                  height])
        resizeComponent(fig, 'multiplePlots',           [standard_x,                504 * heightScaleFactor,    width,                  height])
        resizeComponent(fig, 'Help',                    [656.5*widthScaleFactor,    100 * heightScaleFactor,     55 * widthScaleFactor, height])
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Anpassen der Objektgrößen.')
        disp(ME.message)
    end
end

function resizeComponent(fig, tag, position)
    try
        component = findobj(fig, 'Tag', tag);
        if ~isempty(component)
            component.Position = position;
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, ['Fehler beim Anpassen der Größe von ', tag])
        disp(ME.message)
    end
end

function loadData(fig)
    % Daten laden und Plot aktualisieren
    %
    % Args:
    %    fig (handle):  Handle des Fensters
    try
        % Zugriff auf das Plotfenster im Fenster
        ax = findobj(fig, 'Tag', 'plotAxes');
        hold(ax, 'on');  % Erlaube mehrere Plots im Plotfenster

        cycleDropdown = findobj(fig, 'Tag', 'cycleDropdown');
        if evalin('base', 'exist(''lengthInd'', ''var'')') == 1
            l = evalin('base', 'lengthInd');

            % Dropdown aktualisieren, wenn sich die Größe ändert
            cycleItems = arrayfun(@(x) sprintf('Cycle %d', x), 1:l, 'UniformOutput', false);
            cycleDropdown.Items = cycleItems;
        end

        % Initialer Plot
        updatePlot(fig, cycleDropdown.Value);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Laden der Plotdaten.')
        disp(ME.message)
    end
end

function updatePlot(fig, selectedCycle)
    % Plot im Fenster mit aktuellem Zyklus aktualisieren
    %
    % Args:
    %    fig (handle):  Handle des Fensters
    %    selectedCycle (str): Ausgewählter Zyklus
    try
        config = evalin("base", 'config');
        decimal = config.Nachkommastellen;
        formatstring = sprintf('%%.%df', decimal);
        lineWidth = config.lineWidth;
        % Zugriff auf das Plotfenster im Fenster
        ax = findobj(fig, 'Tag', 'plotAxes');
        hold(ax, 'off'); % leeren des Plotfensters
        cla(ax);

        % Falls schnelle Daten existieren, diese einlesen und plotten
        fastCheck = evalin('base', 'exist(''cyclesX'', ''var'')');
        if fastCheck
            % gespeicherte Daten aus Base Workspace abrufen
            cyclesX = evalin('base', 'cyclesX');
            cyclesY = evalin('base', 'cyclesY');

            % Startindex aus Zyklus-Dropdown auslesen
            cycle = str2double(regexp(selectedCycle, '\d+', 'match'));

            plot(ax, cyclesX{cycle}, cyclesY{cycle}, '--', 'Color', 'b', 'linewidth', lineWidth, 'DisplayName', 'fast Data');
        end

        hold(ax, 'on');
        % Falls langsame Daten existieren, diese einlesen und plotten
        slowCheck = evalin('base', 'exist(''slowX'', ''var'')');
        if slowCheck
            slowX = evalin('base', 'slowX');
            slowY = evalin('base', 'slowY');
            plot(ax, slowX, slowY, ':', 'Color', 'b', 'linewidth', lineWidth, 'DisplayName', 'slow Data');
        end

        % Falls sowohl schnelle als auch langsame Daten existieren, Differenz
        % bilden, darstellen, double layers finden und darstellen, ECSA
        % berechnen und ausgeben
        if fastCheck && slowCheck
            [newX, newY] = compareFastAndSlow(cyclesX{cycle}, cyclesY{cycle}, slowX, slowY);
            plot(ax, newX, newY, '-', 'Color', 'b', 'linewidth', lineWidth, 'DisplayName', 'corrected Data');
            [I_DL_Forward, I_DL_Backward] = findDL(newX, newY);
            yline(ax, I_DL_Backward, 'DisplayName', sprintf('I DL Backward = %.3f', I_DL_Backward), 'Color', 'g', 'LineStyle',':');
            yline(ax, I_DL_Forward, 'DisplayName', sprintf('I DL Forward = %.3f', I_DL_Forward), 'Color', 'r', 'LineStyle',':');
            try
                v = evalin('base', 'fastSlewrate'); % Slewrate in mV/s
            catch
                v = config.refFastSlewRate(1);
                uialert(fig, 'ECSA von DUT mit FastSlew Rate aus config berechnet, da sie nicht in der Datei gefunden wurde.', 'ECSA-Berechnung', 'Icon', 'info');
            end
            PtLoading = findobj(fig, 'Tag', 'PtLoading').Value;
            Area = findobj(fig, 'Tag', 'Area').Value;
            [ecsa_ads, ecsa_des, ecsa] = ECSA(newX, newY, I_DL_Forward, I_DL_Backward, fig, v, PtLoading, Area);

            results = findobj(fig, 'Tag', 'ECSA_DUT_ads');
            results.ValueDisplayFormat = formatstring;
            results.Value = ecsa_ads;
            results = findobj(fig, 'Tag', 'ECSA_DUT_des');
            results.ValueDisplayFormat = formatstring;
            results.Value = ecsa_des;
            results = findobj(fig, 'Tag', 'ECSA_DUT');
            results.ValueDisplayFormat = formatstring;
            results.Value = ecsa;
        end
        
        recalcRef(fig)
        legend(ax, 'Location','southeast');
        hold(ax, 'off');  % Keine weiteren Daten im Plotfenster erlauben
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Aktualisieren des Plots.')
        disp(ME.message)
    end
end

%% Datenverarbeitungsfunktionen

function [ecsa_ads, ecsa_des, ecsa] = ECSA(X, Y, I_DL_Forward, I_DL_Backward, fig, v, PtLoading, Area)
    % Berechnung der electrochemisch aktiven Oberfläche (ECSA)
    %
    % Args:
    %    X (array): Array der X-Daten
    %    Y (array): Array der Y-Daten
    %    I_DL_Forward (float): Vorwärts double layer Kapazitätsstrom
    %    I_DL_Backward (float): Rückwärts double layer Kapazitätsstrom
    %    fig (handle):  Handle des Fensters
    %
    % Returns:
    %    ecsa_ads (float): ECSA der Adsorption
    %    ecsa_des (float): ECSA der Desorption
    %    ecsa (float): Durchschnittlicher ECSA-Wert
    try
        % Parameter auslesen/definieren
        StartIntCath = findobj(fig, 'Tag', 'StartIntCath').Value;
        if isnan(StartIntCath)
            StartIntCath = 0;
        end
        StartIntAn = findobj(fig, 'Tag', 'StartIntAn').Value;
        if isnan(StartIntAn)
            StartIntAn = 0;
        end
        H2SurfaceCharge = 210e-6; % in C/cm^2

        % Daten in Vorwärts- und Rückwärtsteil einteilen
        [~, maxIndex] = max(X);
        Y1 = Y(1:maxIndex);
        Y2 = Y(maxIndex+1:end);
        X1 = X(1:maxIndex);
        X2 = X(maxIndex+1:end);

        % Double layer von Y abziehen
        diff1 = (Y1 - I_DL_Forward) / Area;
        diff2 = (Y2 - I_DL_Backward) / Area;

        % Indizes zur Integration suchen
        index11 = find(X1 >= StartIntAn);
        index12 = find(Y1 == I_DL_Forward);
        index21 = find(X2 >= StartIntCath);
        index22 = find(Y2 == I_DL_Backward);

        % Ladungen für Adsorption und Desorption berechnen, falls sinnvolle
        % Grenzen angegeben wurden
        if isempty(index11)
            Q_des = NaN;
        else
            Q_des = trapz(X1(index11(1):index12), diff1(index11(1):index12)) / v;
        end
        if isempty(index21)
            Q_ads = NaN;
        else
            Q_ads = trapz(X2(index22:index21(end)), diff2(index22:index21(end))) / v;
        end

        % ECSA-Werte berechnen
        ecsa_des = Q_des / (H2SurfaceCharge * PtLoading) * 100;
        ecsa_ads = Q_ads / (H2SurfaceCharge * PtLoading) * 100;
        ecsa = (abs(ecsa_des) + ecsa_ads) / 2;
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Berechnen des ECSA.')
        disp(ME.message)
    end
end

function [newX, newY] = compareFastAndSlow(cyclesX, cyclesY, slowX, slowY)
    % Langsame Daten von schnellen Daten abziehen und als newX/newY
    % zurückgeben
    %
    % Args:
    %    cyclesX (array): Schneller Scan der X-Daten
    %    cyclesY (array): Langsamer Scan Y-Daten
    %    slowX (array): Langsamer Scan der X-Daten
    %    slowY (array): Langsamer Scan Y-Daten
    %
    % Returns:
    %    newX (array): Korrigierte X-Daten
    %    newY (array): Korrigierte Y-Daten
    try
        % Index der double Layer finden
        [~, maxIndexCyclesX] = max(cyclesX);
        [~, maxIndexSlowX] = max(slowX);

        % slowX und slowY in zwei Teile aufteilen
        slowX1 = slowX(1:maxIndexSlowX);
        slowY1 = slowY(1:maxIndexSlowX);
        slowX2 = slowX(maxIndexSlowX+1:end);
        slowY2 = slowY(maxIndexSlowX+1:end);

        % Filtern der Werte, damit jeder x-Wert nur ein mal vorkommt (nötig für Interpolation)
        [uniqueSlowX1, uniqueIndex1] = unique(slowX1, 'last');
        uniqueSlowY1 = slowY1(uniqueIndex1);
        [uniqueSlowX2, uniqueIndex2] = unique(slowX2, 'last');
        uniqueSlowY2 = slowY2(uniqueIndex2);

        % Interpolieren der Arrays
        InterpY1 = interp1(uniqueSlowX1, uniqueSlowY1, cyclesX(1:maxIndexCyclesX), 'pchip');
        InterpY2 = interp1(uniqueSlowX2, uniqueSlowY2, cyclesX(maxIndexCyclesX+1:end), 'pchip');

        % Initialisieren neuer Arrays
        newX = zeros(1, length(cyclesX));
        newY = zeros(1, length(cyclesX));

        % Kombinieren der zwei Teile und Abzug des langsamen Scans vom schnellen Scan
        for i = 1:maxIndexCyclesX
            x = cyclesX(i);
            y = cyclesY(i);
            newY(i) = y - InterpY1(i);
            newX(i) = x;
        end

        for i = maxIndexCyclesX+1:length(cyclesX)
            x = cyclesX(i);
            y = cyclesY(i);
            newY(i) = y - InterpY2(i - maxIndexCyclesX);
            newX(i) = x;
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Vergleichen der langsamen und der schnellen Daten.')
        disp(ME.message)
    end
end

function [I_DL_Forward, I_DL_Backward] = findDL(X, Y)
    % Bestimmung der double layer Kapazitätsströme, durch suche des
    % Maximums/Minimums (50 Messungen Abstand vom Rand)
    %
    % Args:
    %    X (array): Array der X-Daten
    %    Y (array): Array der Y-Daten
    %
    % Returns:
    %    I_DL_Forward (float): Vorwärts double layer Kapazitätsströme
    %    I_DL_Backward (float): Rückwärts double layer Kapazitätsströme
    try
        % config laden
        config = evalin("base", 'config');
        limits = config.SpannungsbereichFuerDLSuche;

        [~, maxIndex] = max(X);

        X1 = X(1:maxIndex);
        X2 = X(maxIndex+1:end);

        firstIndexX1 = find(X1 >= limits(1), 1, 'first');
        lastIndexX1 = find(X1 <= limits(2), 1, 'last');

        firstIndexX2 = find(X2 <= limits(2), 1, 'first');
        lastIndexX2 = find(X2 >= limits(1), 1, 'last');

        Y1 = Y(firstIndexX1:lastIndexX1);
        Y2 = Y(maxIndex + firstIndexX2 : maxIndex + lastIndexX2);

        I_DL_Forward = min(Y1);
        I_DL_Backward = max(Y2);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Suchen der Double Layer.')
        disp(ME.message)
    end
end

function PlotDUT(fig, showFast, showSlow)
    % DUT-Daten plotten
    %
    % Args:
    %    fig (handle): Handle des Fensters
    %    showFast (logical): Auswahl ob schnelle Daten gezeigt werden sollen
    %    showSlow (logical): Auswahl ob langsame Daten gezeigt werden sollen
    try
        % schnelle Daten und gewählten Zyklus einlesen und plotten
        config = evalin("base", 'config');
        lineWidth = config.lineWidth;

        if evalin('base', 'exist(''cyclesX'', ''var'')') && showFast
            cyclesX = evalin('base', 'cyclesX');
            cyclesY = evalin('base', 'cyclesY');
            fastSlewrate = evalin('base', 'fastSlewrate');
            name = strcat('DUT\_', num2str(fastSlewrate), 'mVs');
            selectedCycle = findobj(fig, 'Tag', 'cycleDropdown').Value;
            cycle = str2double(regexp(selectedCycle, '\d+', 'match'));
            plot(cyclesX{cycle}, cyclesY{cycle}, '.-', 'LineWidth', lineWidth, 'MarkerSize', 10, 'DisplayName', name, 'Color', 'b');
        end
        % langsame Daten einlesen und plotten
        if evalin('base', 'exist(''slowX'', ''var'')') && showSlow
            slowX = evalin('base', 'slowX');
            slowY = evalin('base', 'slowY');
            slowSlewrate = evalin('base', 'slowSlewrate');
            name = strcat('DUT\_', num2str(slowSlewrate), 'mVs');
            plot(slowX, slowY, '.-', 'LineWidth', lineWidth, 'MarkerSize', 10, 'DisplayName', name, 'Color', 'b');
            % Achsenlimits neu setzen, falls nur langsame Daten dargestellt werden
            if ~showFast
                ax = gca;
                ax.YLim = [0.4 1];
            end
        end

        showECSA = findobj(fig, 'Tag', 'showECSA').Value;
        if showECSA
            decimal = config.Nachkommastellen;
            hAx = gca;
            ECSA = findobj(fig, 'Tag', 'ECSA_DUT').Value;
            ECSA = num2str(round(ECSA, decimal));
            formattedText = sprintf('ECSA-Ø ≈ %s m²/gPt', strrep(ECSA, '.', ','));
            % Berechneten H2-Crossover im Plot zeigen
            hCross = text(0.5, -1, formattedText, 'Color', [192/255 0 0], 'BackgroundColor', [200/255 200/255 200/255], 'FontSize', config.ECSALabelFontSize, 'FontWeight', 'bold', 'EdgeColor', [165/255 165/255 165/255]);
            % Verschieben der H2-Crossover Textbox ermöglichen
            hCross.ButtonDownFcn = @(src, event) startDragFcn(src, event, hAx);
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Plotten der DUT-Daten.')
        disp(ME.message)
    end
end

function PlotRefData(fig, showDUT, showFast, showSlow)
    % Referenzdaten plotten
    %
    % Args:
    %    fig (handle): Handle des Fensters
    %    showDUT (logical): Auswahl ob DUT-Daten gezeigt werden sollen
    %    showFast (logical): Auswahl ob schnelle Daten gezeigt werden sollen
    %    showSlow (logical): Auswahl ob langsame Daten gezeigt werden sollen
    try
        fastReferenceData = evalin('base', 'fastReferenceDataArray');
        slowReferenceData = evalin('base', 'slowReferenceDataArray');
        if length(fastReferenceData) > length(slowReferenceData)
            l = length(fastReferenceData);
        else
            l = length(slowReferenceData);
        end
        % nötige Parameter definieren
        colors = jet(l);
        numColors = size(colors, 1);
        config = evalin("base", 'config');
        lineWidth = config.lineWidth;

        alpha = 0.25;
        refcolor = [0.01, 0.01, 0.01] * alpha + [1, 1, 1] * (1 - alpha);

        % schnelle Referenzdaten und gewählten Zyklus einlesen
        if showFast
            selectedCycle = findobj(fig, 'Tag', 'cycleDropdown').Value;
            cycle = str2double(regexp(selectedCycle, '\d+', 'match'));

            allFastRefX = cell(1:length(fastReferenceData));
            allFastRefY = cell(1:length(fastReferenceData));
            % Daten aller Referenzdateien in Zyklen einteilen 
            for i = 1:length(fastReferenceData)
                [~, ~] = fastData(fig, fastReferenceData(i));
                fastRefX = evalin('base', 'fastRefX');
                allFastRefX{i} = fastRefX;
                fastRefY = evalin('base', 'fastRefY');
                allFastRefY{i} = fastRefY;
                refName = sprintf('Referenz#%d', i);

                % Daten des gewählten Zyklus plotten (grau falls DUT angezeigt wird)
                if showDUT
                    plot(fastRefX{cycle}, fastRefY{cycle}, '.-', 'MarkerFaceColor', 'auto', 'MarkerSize', lineWidth * 21, 'LineWidth', lineWidth * 6, 'Color', refcolor, 'HandleVisibility', 'off');
                else
                    colorIndex = mod(i - 1, numColors) + 1;
                    plot(fastRefX{cycle}, fastRefY{cycle}, '.-', 'LineWidth', lineWidth, 'MarkerSize', 10, 'DisplayName', refName, 'Color', colors(colorIndex, :));
                end
            end
        end
        
        % langasme Referenzdaten einlesen
        if showSlow
            allslowRefX = cell(1:length(slowReferenceData));
            allslowRefY = cell(1:length(slowReferenceData));
            for i = 1:length(slowReferenceData)
                [~, ~] = slowData(fig, slowReferenceData(i));
                slowRefX = evalin('base', 'slowRefX');
                allslowRefX{i} = slowRefX;
                slowRefY = evalin('base', 'slowRefY');
                allslowRefY{i} = slowRefY;
                refName = sprintf('Referenz#%d', i);

                % Daten plotten (grau falls DUT angezeigt wird)
                if showDUT
                    plot(slowRefX, slowRefY, '.-', 'MarkerFaceColor', 'auto', 'MarkerSize', lineWidth * 21, 'LineWidth', lineWidth * 6, 'Color', refcolor, 'HandleVisibility', 'off');
                else
                    colorIndex = mod(i - 1, numColors) + 1;
                    if showFast
                        plot(slowRefX, slowRefY, '.-', 'LineWidth', lineWidth, 'MarkerSize', 10, 'HandleVisibility', 'off', 'Color', colors(colorIndex, :));
                    else
                        % Achsenlimits neu setzen, falls nur langsame Daten dargestellt werden
                        plot(slowRefX, slowRefY, '.-', 'LineWidth', lineWidth, 'MarkerSize', 10, 'DisplayName', refName, 'Color', colors(colorIndex, :));
                        ax = gca;
                        ax.YLim = [0.4 1];
                    end
                end
            end
        end

        if showFast && showSlow && length(fastReferenceData) == length(slowReferenceData) && ~showDUT
            all_ecsa_ads = NaN(1, length(fastReferenceData));
            all_ecsa_des = NaN(1, length(fastReferenceData));
            all_ecsa = NaN(1, length(fastReferenceData));
            for i = 1:length(fastReferenceData)
                fastRefX = allFastRefX{i};
                fastRefY = allFastRefY{i};
                slowRefX = allslowRefX{i};
                slowRefY = allslowRefY{i};
                [refNewX, refNewY] = compareFastAndSlow(fastRefX{cycle}, fastRefY{cycle}, slowRefX, slowRefY);
                [ref_I_DL_Forward, ref_I_DL_Backward] = findDL(refNewX, refNewY);
                v = config.refFastSlewRate(i);
                PtLoading = config.refPtLoading(i);
                Area = config.refActiveArea(i);
                [all_ecsa_ads(i), all_ecsa_des(i), all_ecsa(i)] = ECSA(refNewX, refNewY, ref_I_DL_Forward, ref_I_DL_Backward, fig, v, PtLoading, Area);
            end
            tableFig = uifigure('Name', 'ECSA der Referenzdateien');
            data = [all_ecsa_ads', all_ecsa_des', all_ecsa'];
            uitable(tableFig, 'Data', data, 'ColumnName', {'ECSA_ads', 'ECSA_des', 'ECSA'}, 'Position', [20 20 tableFig.Position(3)-40 tableFig.Position(4)-40]);
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Ploten der Referenzdaten.')
        disp(ME.message)
    end
end

%% Helfer- und Dienstprogramme

function configurePlot(fig)
    % Plotfenster konfigurieren
    %
    % Args:
    %    fig (handle): Handle des Fensters
    try
        % config laden
        config = evalin("base", 'config'); 
        fig = evalin("base", 'fig');
        xLim = config.xAchsenLimits;
        yLim = config.yAchsenLimits;

        % Titel anpassen und einfügen
        replacement = getReplacementString();
        t1 = strrep(char(findobj(fig, 'Tag', 'title1').Value), 'xx&x', replacement);
        t2 = char(findobj(fig, 'Tag', 'title2').Value);
        replaceSpecialChars = @(str) regexprep(regexprep(str, '_(?!{)', '\\_'), '\^(?!{)', '\\^');
        t1 = replaceSpecialChars(t1);
        t2 = replaceSpecialChars(t2);

        % Plotfensterdesign einstellen
        ax = gca;
        ax.XGrid = 'on'; 
        ax.YGrid = 'on'; 
        ax.GridLineStyle = '-'; 
        ax.GridColor = [0.5, 0.5, 0.5]; 
        ax.GridAlpha = 0.7; 
        ax.XLim = xLim; 
        ax.YLim = yLim; 
        ax.Layer = 'top'; 
        ax.XAxisLocation = 'origin'; 
        ax.YAxisLocation = 'origin'; 
        xlabel(config.xlabel, 'Position', ...
            [mean(config.xAchsenLimits) + diff(config.xAchsenLimits) * 0.018, config.yAchsenLimits(1) - diff(config.yAchsenLimits) * 0.035], ...
            'FontWeight', 'bold');
        ylabel(config.ylabel, 'FontWeight', 'bold');
        title(t1, t2);

        % Legende aktivieren
        l = legend('Location', 'southeast');
        l.FontSize = config.legendFontSize;

        % Achsenbeschriftungen mit Komma als Dezimaltrennzeichen
        updateTickLabels(ax);

        ax.XAxis.FontSize = config.xTickSize;
        ax.YAxis.FontSize = config.yTickSize;

        % Listener hinzufügen, um die Y-Achsenbeschriftungen zu aktualisieren, wenn sich die YLim ändert
        addlistener(ax, 'XLim', 'PostSet', @(src, event) updateTickLabels(ax));
        addlistener(ax, 'YLim', 'PostSet', @(src, event) updateTickLabels(ax));
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Konfigurieren des Plots.')
        disp(ME.message)
    end
end

function updateTickLabels(ax)
    try
        ax.XTickLabels = strrep(cellstr(num2str(ax.XTick')), '.', ',');
        ax.YTickLabel = strrep(cellstr(num2str(ax.YTick')), '.', ',');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Anpassen der Ticklabels.')
        disp(ME.message)
    end
end

function replacement = getReplacementString()
    % Titelstring des Plots anpassen (slew Rates aus DUT-Daten auslesen)
    %
    % Returns:
    %    replacement (str): Neuer Titelstring
    try
        if evalin('base', 'exist(''fastSlewrate'', ''var'')') && evalin('base', 'exist(''slowSlewrate'', ''var'')')
            fastSlewrate = evalin('base', 'fastSlewrate');
            slowSlewrate = evalin('base', 'slowSlewrate');
            replacement = sprintf('%d&%d', fastSlewrate, slowSlewrate);
        elseif evalin('base', 'exist(''fastSlewrate'', ''var'')')
            fastSlewrate = evalin('base', 'fastSlewrate');
            replacement = sprintf('%d', fastSlewrate);
        elseif evalin('base', 'exist(''slowSlewrate'', ''var'')')
            slowSlewrate = evalin('base', 'slowSlewrate');
            replacement = sprintf('%d', slowSlewrate);
        else
            replacement = 'xx&x';
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Anpassen des Titels.')
        disp(ME.message)
    end
end

function clearVariables()
    % Lösche alle Methodenspezifischen Variablen

    if evalin('base', 'exist(''slowX'', ''var'')') == 1
        evalin('base', 'clear slowX slowY slowSlewrate');
    end

    if evalin('base', 'exist(''cyclesX'', ''var'')') == 1
        evalin('base', 'clear cyclesX cyclesY length fastSlewrate');
    end

    if evalin('base', 'exist("slowRefX", "var")') == 1 
        evalin('base', 'clear fastRefX fastRefY slowRefX slowRefY');
    end

    if evalin('base', 'exist("fastReferenceDataArray", "var")') == 1 
        evalin('base', 'clear fastReferenceDataArray');
    end

    if evalin('base', 'exist("slowReferenceDataArray", "var")') == 1 
        evalin('base', 'clear slowReferenceDataArray');
    end

    if evalin('base', 'exist("referenceDataArray", "var")') == 1 
        evalin('base', 'clear referenceDataArray');
    end
end

function backToSelection(fig)
    % Lösche alle Methodenspezifischen Variablen und gehe zurück zum Auswahlfenster
    %
    % Args:
    %    fig (handle): Handle des Fensters
    try
        % Workspace leeren
        clearVariables();
        evalin("base", 'clear config')
        evalin('base', 'clear referenceFolder');
        evalin('base', 'clear fig');
        clc;

        % Auswahl öffnen
        Auswahl(fig);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Schließen der Methode.')
        disp(ME.message)
    end
end

function recalcLoss(fig)
    try
        tags = {'ECSA_DUT', 'ECSA_Ref', 'ECSA_DUT_ads', 'ECSA_Ref_ads', 'ECSA_DUT_des', 'ECSA_Ref_des'};

        for i = 1:2:length(tags)
            ref = findobj(fig, 'Tag', tags{i+1}).Value;
            dut = findobj(fig, 'Tag', tags{i}).Value;
            loss = (ref-dut)/ref *100;
            switch i
                case 1
                    obj = findobj(fig, 'Tag', 'ECSA_%');
                case 3
                    obj = findobj(fig, 'Tag', 'ECSA_%_ads');
                case 5
                    obj = findobj(fig, 'Tag', 'ECSA_%_des');
            end
            if isnan(loss)
                obj.Value = 0;
            else
                obj.Value = loss;
            end
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Berechnen des ECSA-Verlustes.')
        disp(ME.message)
    end
end

function startDragFcn(src, ~, hAx)
    try
        % Initiale Mausposition speichern und Drag-Funktion setzen. (Verschiebung der Gleichungstexte)
        initialMousePos = get(hAx, 'CurrentPoint');
        initialTextPos = get(src, 'Position');
        
        % Setzen der WindowButtonMotionFcn und WindowButtonUpFcn
        set(gcf, 'WindowButtonMotionFcn', @(~,~) draggingFcn(src, hAx, initialMousePos, initialTextPos));
        set(gcf, 'WindowButtonUpFcn', @stopDragFcn);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Verschieben (1).')
        disp(ME.message)
    end
end

function draggingFcn(src, hAx, initialMousePos, initialTextPos)
    try
        % Aktuelle Mausposition und Verschiebung berechnen und Textposition
        % aktualisieren. (Verschiebung der Gleichungstexte)
        currentMousePos = get(hAx, 'CurrentPoint');
        deltaX = currentMousePos(1,1) - initialMousePos(1,1);
        deltaY = currentMousePos(1,2) - initialMousePos(1,2);
        newX = initialTextPos(1) + deltaX;
        newY = initialTextPos(2) + deltaY;
        set(src, 'Position', [newX, newY, 0]);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Verschieben (2).')
        disp(ME.message)
    end
end

function stopDragFcn(~, ~)
    try
        % Zurücksetzen der WindowButtonMotionFcn und WindowButtonUpFcn. (Verschiebung der Gleichungstexte)
        set(gcf, 'WindowButtonMotionFcn', '');
        set(gcf, 'WindowButtonUpFcn', '');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Verschieben (3).')
        disp(ME.message)
    end
end

%% Eingabe-/Ausgabefunktionen

function PlotDataWrapper(fig)
    % Wrapperfunktion um Daten zu laden und darzustellen
    %
    % Args:
    %    fig (handle):  Handle des Fensters
    try
        % Daten laden und Darstellungsoptionen einlesen
        showReference = findobj(fig, 'Tag', 'showReference').Value;
        showDUT = findobj(fig, 'Tag', 'showDUT').Value;
        if ~showReference && ~showDUT
            return;
        end

        showFast = findobj(fig, 'Tag', 'showFast').Value;
        showSlow = findobj(fig, 'Tag', 'showSlow').Value;
        if ~showFast && ~showSlow
            return;
        end

        d = uiprogressdlg(fig,'Title','Bitte Warten',...
        'Message','Plot wird erstellt');

        loadData(fig);

        d.Value = 0.1;

        % Daten basierend auf der Auswahl darstellen und Plotdesign anpassen
        if showReference && showDUT && (showFast || showSlow)
            if evalin('base', 'exist(''cyclesX'', ''var'')') || evalin('base', 'exist(''slowX'', ''var'')')
                figure('Units', 'normalized', 'OuterPosition', [0 0 1 1]);
                hold on;
                configurePlot(fig);

                d.Value = 0.2;

                PlotRefData(fig, showDUT, showFast, showSlow);

                d.Value = 0.5;

                PlotDUT(fig, showFast, showSlow);

                d.Value = 0.9;
            else
                return;
            end
        elseif showReference && (showFast || showSlow)
            figure('Units', 'normalized', 'OuterPosition', [0 0 1 1]);
            hold on;
            configurePlot(fig);

            d.Value = 0.4;

            PlotRefData(fig, showDUT, showFast, showSlow);

            d.Value = 0.9;
        elseif showDUT && (showFast || showSlow)
            if evalin('base', 'exist(''cyclesX'', ''var'')') || evalin('base', 'exist(''slowX'', ''var'')')
                figure('Units', 'normalized', 'OuterPosition', [0 0 1 1]);
                hold on;
                configurePlot(fig);

                d.Value = 0.4;

                PlotDUT(fig, showFast, showSlow);

                d.Value = 0.9;
            else
                return;
            end
        else
            return;
        end
        d.Value = 1;
        close(d)
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Plotten der Daten.')
        disp(ME.message)
    end
end

function [cyclesX, cyclesY] = fastData(fig, data)
    % Laden der schnellen Daten aus Datei (normal) oder gegebenen Daten (bei
    % Referenz)
    %
    % Args:
    %    standardPath (str): Standardpfad für Dateiauswahl
    %    fig (handle):  Handle des Fensters
    %    data (cell array): Übergebene Daten (bei Referenz)
    try
        % config laden
        config = evalin("base", 'config');
        columns = config.Spalten;
        standardPath = evalin("base", 'standardPath');

        % Neue Datei einlesen, falls keine Daten übergeben werden
        if isempty(data)
            try
                oldFolder = cd(standardPath);
                [fileName, filePath] = uigetfile('*.txt', 'Wählen Sie eine Datei zur Auswertung aus');
                cd(oldFolder);
            catch ME
                fig = evalin('base', 'fig');
                uialert(fig, [ME.message], 'Standardordner nicht gültig, bitte in der config anpassen.', 'Icon', 'warning');
                [fileName, filePath] = uigetfile('*.txt', 'Wählen Sie eine Datei zur Auswertung aus');
            end
            if isequal(fileName, 0)
                disp('Keine Datei ausgewählt');
                return;
            end

            assignin("base",'standardPath', filePath)

            dataFile = fullfile(filePath, fileName);
            currentRef = evalin("base", 'currentRef');
            [dataArray, slewRate] = read_txt({dataFile}, currentRef);
            assignin('base', 'fastSlewrate', slewRate)
        else
            dataArray = data;
        end

        % Datenarray in x und y einteilen
        datax = dataArray{1}(:, columns(1));
        datay = dataArray{1}(:, columns(2));

        % Aufteilen der Daten in die Zyklen
        differences = diff(datax);
        indexArray = find(differences(1:end-1) < 0 & differences(2:end) > 0) + 1;
        l = length(indexArray) + 1;
        cyclesX = cell(1, l);
        cyclesY = cell(1, l);
        cyclesX{1} = datax(1:indexArray(1));
        cyclesY{1} = datay(1:indexArray(1));
        for i = 2:length(indexArray)
            cyclesX{i} = datax(indexArray(i-1) + 1:indexArray(i));
            cyclesY{i} = datay(indexArray(i-1) + 1:indexArray(i));
        end
        cyclesX{end} = datax(indexArray(end) + 1:end);
        cyclesY{end} = datay(indexArray(end) + 1:end);

        % Daten im Base Workspace entweder als Referenz- oder als Messdaten speichern
        basefig = evalin('base', 'fig');
        if isequal(fig, basefig)
            if isempty(data)
                assignin('base', 'cyclesX', cyclesX);
                assignin('base', 'cyclesY', cyclesY);
                assignin('base', 'lengthInd', l);
                loadData(fig);
            else
                assignin('base', 'fastRefX', cyclesX);
                assignin('base', 'fastRefY', cyclesY);
            end
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Laden der schnellen Daten.')
        disp(ME.message)
    end
end

function [slowX, slowY] = slowData(fig, data)
    % Laden der langsamen Daten aus Datei (normal) oder gegebenen Daten (bei
    % Referenz)
    %
    % Args:
    %    standardPath (str): Standardpfad für Dateiauswahl
    %    fig (handle):  Handle des Fensters
    %    data (cell array): Übergebene Daten (bei Referenz)
    try
        % Neue Datei einlesen, falls keine Daten übergeben werden
        if isempty(data)
            standardPath = evalin("base", 'standardPath');
            try
                oldFolder = cd(standardPath);
                [fileName, filePath] = uigetfile('*.txt', 'Wählen Sie eine Datei zur Auswertung aus');
                cd(oldFolder);
            catch ME
                fig = evalin('base', 'fig');
                uialert(fig, [ME.message], 'Standardordner nicht gültig, bitte in der config anpassen.', 'Icon', 'warning');
                [fileName, filePath] = uigetfile('*.txt', 'Wählen Sie eine Datei zur Auswertung aus');
            end

            if isequal(fileName, 0)
                disp('Keine Datei ausgewählt');
                return;
            end

            assignin("base",'standardPath', filePath)

            dataFile = fullfile(filePath, fileName);
            currentRef = evalin("base", 'currentRef');
            [dataArray, slewRate] = read_txt({dataFile}, currentRef);
            assignin('base', 'slowSlewrate', slewRate)
        else
            dataArray = data;
        end

        % Datenarray in x und y einteilen
        slowX = dataArray{1}(:, 3);
        slowY = dataArray{1}(:, 4);

        % Daten im Base Workspace entweder als Referenz- oder als Messdaten speichern
        if isempty(data)
            assignin('base', 'slowX', slowX);
            assignin('base', 'slowY', slowY);
            loadData(fig);
        else
            assignin('base', 'slowRefX', slowX);
            assignin('base', 'slowRefY', slowY);
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Laden der langsamen Daten.')
        disp(ME.message)
    end
end

function multiplePlots()
    fig = uifigure();

    uitextarea(fig, "Value", 'fast Data:', 'Position', [10, 390, 95, 27], 'FontSize', 17.5, ...
        'Tag', 'fastFileListLabel', 'Editable', 'off', 'BackgroundColor', fig.Color);
    uilistbox(fig, 'Position', [10, 85, 260, 300], 'Tag', 'fastFileList', ...
        'Multiselect', 'on', 'Items', {});

    uitextarea(fig, "Value", 'slow Data:', 'Position', [290, 390, 95, 27], 'FontSize', 17.5, ...
        'Tag', 'slowFileListLabel', 'Editable', 'off', 'BackgroundColor', fig.Color);
    uilistbox(fig, 'Position', [290, 85, 260, 300], 'Tag', 'slowFileList', ...
        'Multiselect', 'on', 'Items', {});

    uicheckbox(fig, ...
            'Text', 'fast Referenzdaten anzeigen', ...
            'Position', [10, 60, 175, 22], ...
            'Value', 0, ...
            'Tag', 'showFastReference');

    uidropdown(fig, ...
            'Position', [200, 60, 155, 22], ...
            'Items', {'Cycle 1', 'Cycle 2', 'Cycle 3', 'Cycle 4'}, ...
            'Tag', 'cycleDropdown', 'Value', 'Cycle 4');

    uicheckbox(fig, ...
            'Text', 'slow Referenzdaten anzeigen', ...
            'Position', [370, 60, 180, 22], ...
            'Value', 0, ...
            'Tag', 'showSlowReference');

    % Load Fast Data Button
    uibutton(fig, 'push', ...
        'Text', 'Load Fast Data', ...
        'Position', [10, 7.5, 520/3, 50], ...
        'ButtonPushedFcn', @(btn, event) addFiles(fig, 'fast'), ...
        'Tag', 'plotButton');

    % Plot Button
    uibutton(fig, 'push', ...
        'Text', 'Plot', ...
        'Position', [560/2 - 520/3/2, 7.5, 520/3, 50], ...
        'ButtonPushedFcn', @(btn, event) plotMultipleScans(fig), ...
        'Tag', 'plotButton');

    % Load Slow Data Button
    uibutton(fig, 'push', ...
        'Text', 'Load Slow Data', ...
        'Position', [560 - 520/3 - 10, 7.5, 520/3, 50], ...
        'ButtonPushedFcn', @(btn, event) addFiles(fig, 'slow'), ...
        'Tag', 'plotButton');
end

function addFiles(fig, speed)
    % Funktion zum Hinzufügen von Dateien zur Liste
    try
        try
            standardPath = evalin('base', 'standardPath');
            oldFolder = cd(standardPath);
            [fileNames, filePath] = uigetfile('*.txt', ['Wählen Sie Dateien für ', speed, ' Data aus'], 'MultiSelect', 'on');
            cd(oldFolder);
        catch ME
            uialert(fig, [ME.message], 'Standardordner nicht gültig, bitte in der config anpassen.', 'Icon', 'warning');
            [fileNames, filePath] = uigetfile('*.txt', 'Wählen Sie eine Datei zur Auswertung aus', 'MultiSelect', 'on');
        end
        if isequal(fileNames, 0)
            disp('Keine Datei ausgewählt');
            return;
        end

        if ischar(fileNames)
            fileNames = {fileNames};
        end
        dataFiles = cell(length(fileNames), 1);
        for i = 1:length(fileNames)
            dataFiles{i} = fullfile(filePath, fileNames{i});
        end
        currentRef = evalin("base", 'currentRef');
        [dataArray, ~] = read_txt(dataFiles, currentRef);

        if isequal(fileNames, 0)
            return
        end

        fileList = findobj(fig, 'Tag', [speed, 'FileList']);
        try
            for i = 1:length(fileNames)
                fileName = fileNames{i};
                addFileToList(fileList, fileName, dataArray{i}, length(fileList.Items) + 1)
            end
        catch ME
            error('Error reading data files: %s', ME.message);
        end
        fileList.Value = fileList.ItemsData;
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Hinzufügen der Dateien.')
        disp(ME.message)
    end
end

function plotMultipleScans(fig)
    config = evalin("base", 'config');
    lineWidth = config.lineWidth;

    fastFileList = findobj(fig, 'Tag', 'fastFileList');
    fastDataArray = fastFileList.Value;
    fastItems = fastFileList.Items;
    [~, idx] = ismember(fastItems, fastFileList.Items);
    fastDataArray = fastDataArray(idx);

    fastL = length(fastDataArray);
    cyclesX = cell(1:fastL);
    cyclesY = cell(1:fastL);

    selectedCycle = findobj(fig, 'Tag', 'cycleDropdown').Value;
    cycle = str2double(regexp(selectedCycle, '\d+', 'match'));

    slowFileList = findobj(fig, 'Tag', 'slowFileList');
    slowDataArray = slowFileList.Value;
    slowItems = slowFileList.Items;
    [~, idx] = ismember(slowItems, slowFileList.Items);
    slowDataArray = slowDataArray(idx);

    slowL = length(slowDataArray);
    slowX = cell(1:slowL);
    slowY = cell(1:slowL);
    
    for i = 1:fastL
        [cyclesX{i}, cyclesY{i}] = fastData(fig, fastDataArray(i));
    end
    for i = 1:slowL
        [slowX{i}, slowY{i}] = slowData(fig, slowDataArray(i));
    end
    
    showFastReference = findobj(fig, 'Tag', 'showFastReference').Value;
    showSlowReference = findobj(fig, 'Tag', 'showSlowReference').Value;
    
    d = uiprogressdlg(fig,'Title','Bitte Warten','Message','Plot wird erstellt');
    d.Value = 0.1;

    if fastL > 0 || slowL > 0 || showFastReference || showSlowReference
        figure('Units', 'normalized', 'OuterPosition', [0 0 1 1]);
        hold on;
        configurePlot(fig);

        if fastL > slowL
            l = fastL;
        else
            l = slowL;
        end
        colors = jet(l);
        numColors = size(colors, 1);
        
        d.Value = 0.2;

        PlotRefData(fig, 1, showFastReference, showSlowReference);

        d.Value = 0.5;

        % schnelle Daten und gewählten Zyklus einlesen und plotten
        for i = 1:fastL
            name = strcat('fast\_DUT\_', num2str(i));
            colorIndex = mod(i - 1, numColors) + 1;
            plot(cyclesX{i}{cycle}, cyclesY{i}{cycle}, '.-', 'LineWidth', lineWidth, 'MarkerSize', 10, 'DisplayName', name, 'Color', colors(colorIndex, :));
        end
        % langsame Daten einlesen und plotten
        for i = 1:slowL
            name = strcat('slow\_DUT\_', num2str(i));
            colorIndex = mod(i - 1, numColors) + 1;
            plot(slowX{i}, slowY{i}, '.-', 'LineWidth', lineWidth, 'MarkerSize', 10, 'DisplayName', name, 'Color', colors(colorIndex, :));
        end
        d.Value = 0.9;
    else 
        return;
    end

    d.Value = 1;
    close(d)
end

function addFileToList(fileList, fileName, data, position)
    % Helper function to add a single file to the list at a specific position
    try
        if isempty(fileList.Items)
            fileList.Items = {fileName};
            fileList.ItemsData = {data};
        else
            index = find(cellfun(@(x) isequal(x, fileName), fileList.Items));
            if ~isempty(index)
                fileList.Items(index) = [];
                fileList.ItemsData(index) = [];
                if index < position
                    position = position - 1;
                end
            end
            % Sicherstellen, dass beide als Zell-Arrays behandelt werden
            fileList.Items = [fileList.Items(1:position-1), {fileName}, fileList.Items(position:end)];
            fileList.ItemsData = [fileList.ItemsData(1:position-1), {data}, fileList.ItemsData(position:end)];
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim einer Datei.')
        disp(ME.message)
    end
end

function getReferences(fig)
    % Laden der schnellen und langsamen Referenzdaten
    %
    % Args:
    try
        referenceFolder = evalin("base", 'referenceFolder');

        % Laden der schnellen Referenzdaten
        fastReferenceFolder = fullfile(referenceFolder, 'schneller_Scan');
        fastReferenceData = getReference(fastReferenceFolder);
        assignin('base', 'fastReferenceDataArray', fastReferenceData);

        % Laden der langsamen Referenzdaten
        slowReferenceFolder = fullfile(referenceFolder, 'langsamer_Scan');
        slowReferenceData = getReference(slowReferenceFolder);
        assignin('base', 'slowReferenceDataArray', slowReferenceData);
        
        recalcRef(fig)
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Laden der Referenzdaten.')
        disp(ME.message)
    end
end

function recalcRef(fig)
    try
        config = evalin("base", 'config');
        decimal = config.Nachkommastellen;
        formatstring = sprintf('%%.%df', decimal);
        selectedCycle = findobj(fig, 'Tag', 'cycleDropdown').Value;
        cycle = str2double(regexp(selectedCycle, '\d+', 'match'));
        fastReferenceData = evalin("base", 'fastReferenceDataArray');
        slowReferenceData = evalin("base", 'slowReferenceDataArray');

        if isempty(fastReferenceData) || isempty(slowReferenceData)
            return
        end

        allFastRefX = cell(1:length(fastReferenceData));
        allFastRefY = cell(1:length(fastReferenceData));
        % Daten aller Referenzdateien in Zyklen einteilen 
        for i = 1:length(fastReferenceData)
            [~, ~] = fastData(fig, fastReferenceData(i));
            fastRefX = evalin('base', 'fastRefX');
            allFastRefX{i} = fastRefX;
            fastRefY = evalin('base', 'fastRefY');
            allFastRefY{i} = fastRefY;
        end

        allslowRefX = cell(1:length(slowReferenceData));
        allslowRefY = cell(1:length(slowReferenceData));
        for i = 1:length(slowReferenceData)
            [~, ~] = slowData(fig, slowReferenceData(i));
            slowRefX = evalin('base', 'slowRefX');
            allslowRefX{i} = slowRefX;
            slowRefY = evalin('base', 'slowRefY');
            allslowRefY{i} = slowRefY;
        end
        all_ecsa_ads = NaN(1, length(fastReferenceData));
        all_ecsa_des = NaN(1, length(fastReferenceData));
        all_ecsa = NaN(1, length(fastReferenceData));
        for i = 1:length(fastReferenceData)
            fastRefX = allFastRefX{i};
            fastRefY = allFastRefY{i};
            slowRefX = allslowRefX{i};
            slowRefY = allslowRefY{i};
            [refNewX, refNewY] = compareFastAndSlow(fastRefX{cycle}, fastRefY{cycle}, slowRefX, slowRefY);
            [ref_I_DL_Forward, ref_I_DL_Backward] = findDL(refNewX, refNewY);
            v = config.refFastSlewRate(i);
            PtLoading = config.refPtLoading(i);
            Area = config.refActiveArea(i);
            [all_ecsa_ads(i), all_ecsa_des(i), all_ecsa(i)] = ECSA(refNewX, refNewY, ref_I_DL_Forward, ref_I_DL_Backward, fig, v, PtLoading, Area);
        end
        obj = findobj(fig, 'Tag', 'ECSA_Ref');
        obj.Value = mean(all_ecsa);
        obj.ValueDisplayFormat = formatstring;
        obj = findobj(fig, 'Tag', 'ECSA_Ref_ads');
        obj.Value = mean(all_ecsa_ads);
        obj.ValueDisplayFormat = formatstring;
        obj = findobj(fig, 'Tag', 'ECSA_Ref_des');
        obj.Value = mean(all_ecsa_des);
        obj.ValueDisplayFormat = formatstring;

        recalcLoss(fig)
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Berechnen der Referenz-ECSA.')
        disp(ME.message)
    end
end

function referenceDataArray = getReference(referenceFolder)
    % Referenzdaten aus Referenzordner auslesen
    %
    % Args:
    %    referenceFolder (str): Dateipfad zum Referenzordner
    %
    % Returns:
    %    referenceDataArray (cell array): Array der Referenzdaten

    try
        % Auslesen der Daten und abspeichern in einem Daten-Array
        matFiles = dir(fullfile(referenceFolder, 'Referenz#*.mat'));
        referenceDataArray = cell(numel(matFiles), 1);
        for i = 1:numel(matFiles)
            loadedData = load(fullfile(referenceFolder, matFiles(i).name));
            if isfield(loadedData, 'dataArray')
                referenceDataArray{i} = loadedData.dataArray{1};
            else
                warning('The file %s does not contain the expected variable "dataArray".', matFiles(i).name);
            end
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Ladfen einer Referenzdatei.')
        disp(ME.message)
    end
end

function helpButton()
    try
        helpdlg([['>> Titel Zeile 1 und 2: Titelanpassung (^{Text} für hochgestellten Text und _{Text} für tiefgestellten ' ...
                  'Text => [\{, \} und \\ um {, } und \ zu schreiben])'] newline ...
                  '>> Dropdown-Menü "Cycle ...": Gibt den Zyklus des schnellen Scans an, der dargestellt wird' newline ...
                  '>> Load fast & slow Data: Lädt die Daten des schnellen oder langsamen Scans' newline ...
                  '>> Plot Multiple Scans: Öffnet ein Fenster in dem schnelle und langsame Messdaten mehrerer Messungen gleichzeit geladen und geplottet werden können' newline ...
                  '>> Start integration cathodic & anodic [V]: Setzt den Spannungswert ab dem unten & oben integriert werden soll' newline ...
                  '>> Pt loading [mg/cm²]: Gibt die Elektrodenbeladung an' newline ...
                  '>> Active Area: Gibt die aktive Fläche an' newline ...
                  '>>> In config für Referenzdateien getrennt angeben' newline ...
                  '>> ECSA: Gibt die ECSA der Referenzdateien, der DUT und den Verlust an' newline ...
                  '>> ads: Gibt die ECSA im negativen/kathodischen Strombereich an' newline ...
                  '>> des: Gibt die ECSA im positiven/anodischen Strombereich an' newline ...
                  '>> Referenzdaten anzeigen: Falls diese Checkbox gewählt wird, werden die Referenzdaten im Plot angezeigt' newline ...
                  '>> DUT anzeigen: Falls diese Checkbox gewählt wird, werden die DUT-Daten im Plot angezeigt' newline ...
                  '>> fast Data anzeigen: Falls diese Checkbox gewählt wird, wird der schnelle Scan im Plot angezeigt' newline ...
                  '>> slow Data anzeigen: Falls diese Checkbox gewählt wird, wird der langsamen Scan im Plot angezeigt' newline ...
                  '>> ECSA-Ø anzeigen: Falls diese Checkbox gewählt wird, wird im Plot der Durchschnittliche ECSA-Wert als Text angezeigt' newline newline ...
                  '>> Formeln für ECSA-Berechnung: ' newline ...
                  '>> ECSA_ges = (|ECSA_des|+ECSA_ads)/2' newline ...
                  '>> Q_ads = (∫((I-I_DL)/Area dU))/Scangeschwindigkeit von U(Start Cathodic) bis U_DL' newline ...
                  '>> ECSA_ads = (Q_ads*100)/(H2SurfaceCharge*Pt loading)' newline ...
                  '>> Q_des = (∫((I-I_DL)/Area dU))/Scangeschwindigkeit über U(Start Anodic) bis U_DL' newline ...
                  '>> ECSA_des = (Q_des*100)/(H2SurfaceCharge*Pt loading)'], 'Information');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Öffnen des Hilfsdialogs.')
        disp(ME.message)
    end
end