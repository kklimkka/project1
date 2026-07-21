%% Setup- und Initialisierungsfunktionen
function H2_Crossover(referenceFolder)
    % Hauptfunktion, die den gesamten Ablauf steuert.
    try
        %Abruf der config.json und vervollständigen des Pfades zum Referenzordner
        currentRef = referenceFolder;
        assignin("base", "currentRef", currentRef)
        configFile = fullfile(currentRef, 'config.json');
        fid = fopen(configFile, 'r');
        jsonData = fscanf(fid, '%c');
        fclose(fid);
        configData = jsondecode(jsonData);
        h2_config = configData.H2_Crossover;
        assignin("base", "config", h2_config)
    
        % Zugriff auf 'fig' aus dem Base Workspace
        fig = evalin('base', 'fig'); 
        fig.Name = 'H2-Crossover';
    
        % Setup von 'fig' mit Buttons, Standardwerten und Textfeldern
        delete(fig.Children);
        createParameterFields(fig); 

        % Einlesen der Referenzdaten
        referenceFolder = fullfile(referenceFolder, 'H2_Crossover');
        matFiles = dir(fullfile(referenceFolder, 'Referenz#*.mat'));
        referenceDataArray = cell(numel(matFiles), 1);
        for i = 1:numel(matFiles)
            loadedData = load(fullfile(referenceFolder, matFiles(i).name));
            % Entferne die zusätzliche Schicht und speichere die eigentlichen Daten
            if isfield(loadedData, 'dataArray')
                referenceDataArray{i} = loadedData.dataArray{1}; % Entferne die zusätzliche Schicht
            else
                warning('The file %s does not contain the expected variable "dataArray".', matFiles(i).name);
            end
        end

        % Debugging-Ausgaben zur Überprüfung der Struktur
        for i = 1:numel(referenceDataArray)
            fprintf('Size of referenceDataArray{%d}: %s\n', i, mat2str(size(referenceDataArray{i})));
        end

        % Speichern der Referenzdaten im Base Workspace
        assignin('base', 'refFiles', matFiles);
        assignin('base', 'referenceDataArray', referenceDataArray);
        
        % Event-Listener für die Größenänderung des Fensters hinzufügen
        fig.SizeChangedFcn = @(src, event) resizeUIComponents(fig);
        fig.AutoResizeChildren = 'off';  % Deaktivieren der automatischen Größenanpassung
    
        % Initiale Größenanpassung auf aktuelle Fenstergröße
        resizeUIComponents(fig);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Öffnen des H2-Crossover-Fensters.')
        disp(ME.message)
    end
end

function runMethodScript(method)
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
            fig = findall(0, 'Type', 'figure', 'Name', 'H2-Crossover Einstellungen'); 

            % Setze den CloseRequestFcn-Callback
            addlistener(fig, 'ObjectBeingDestroyed', @(src, event) onCloseCallback(src, event));
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

function onCloseCallback(src, ~)
    try
        disp('closed')
        currentRef = evalin("base", 'currentRef');

        configFile = fullfile(currentRef, 'config.json');
        fid = fopen(configFile, 'r');
        jsonData = fscanf(fid, '%c');
        fclose(fid);
        configData = jsondecode(jsonData);
        h2_config = configData.H2_Crossover;
        assignin("base", "config", h2_config)
        
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

function addFiles(fig)
    % Funktion zum Hinzufügen von Dateien zur Liste
    try
        try
            [data, fileNames] = DataWrapper();
        catch
            return
        end 
    
        fileList = findobj(fig, 'Tag', 'fileList');

        for i = 1:length(data)
            addFileToList(fileList, fileNames{i} , data{i}, length(fileList.Items) + 1)
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Hinzufügen der Dateien.')
        disp(ME.message)
    end
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
        uialert(fig, ME.message, 'Fehler beim Hinzufügen einer Datei.')
        disp(ME.message)
    end
end

function createParameterFields(fig)
    try
        % config laden
        config = evalin("base", 'config');
        
        % Definition der Standardwerte.
        defaultTitle1 = config.Titel1;
        defaultTitle2 = config.Titel2;
        defaultXStart = config.UMin;
        defaultXEnd = config.UMax;
        defaultArea = config.Flaeche;
        defaultDecimal = config.Nachkommastellen_I;
        checkDUT = config.checkDUT;
        checkRef = config.checkRef;
    
        % Button Parameter.
        btn_width = 200;
        btn_height = 50;
        btn_y = 10;

        % Infotext hinzufügen
        uitextarea(fig, 'Position', [20, 200, 420, 415], ...
            'Value', ['Die Auswertungsmethode "H2-Crossover" wurde ausgewählt:' newline ...
                  ['>> Titel Zeile 1 und 2: Titelanpassung (^{Text} für hochgestellten Text und _{Text} für tiefgestellten ' ...
                  'Text => [\{, \} und \\ um {, } und \ zu schreiben])'] newline ...
                  '>> Fläche [cm²]: Gibt die Aktive Fläche der Zelle an' newline ...
                  '>> Nackommastellen bei I: Gibt an wie viele Nachkommastellen von I ausgegeben werden' newline ...
                  '>> Spannungsminimum & -maximum [V]: Geben den Spannungsbereich für den Fit der Geraden an' newline ...
                  '>> showRef: Falls diese Checkbox gewählt wird, werden die Referenzdaten im Plot angezeigt' newline ...
                  '>> showDUT: Falls diese Checkbox gewählt wird, werden die DUT-Daten im Plot angezeigt' newline ...
                  '> Text im Plotfenster lassen sich verschieben' newline ...
                  newline ...
                  'Erst "Neue Datei laden" dann "Plotten" oder "Fitten"' 
                  ], ...
            'Tag', 'infoText');
    
        % Textfelder hinzufügen um Standardwerte anzeigen und anpassen zu können.
        uilabel(fig, 'Position', [20, 160, 100, 22], 'Text', 'Titel Zeile 1:', 'Tag', 'titel1label'); 
        uieditfield(fig, 'text', 'Position', [95, 160, 485, 22], 'Value', defaultTitle1{1}, 'Tag', 'title1');
    
        uilabel(fig, 'Position', [20, 120, 100, 22], 'Text', 'Titel Zeile 2:', 'Tag', 'titel2label');
        uieditfield(fig, 'text', 'Position', [95, 120, 785, 22], 'Value', defaultTitle2{1}, 'Tag', 'title2');

        % Checkboxen hinzufügen
        uicheckbox(fig, "Position", [590, 160, 70, 22], 'Text', 'showDUT', 'Tag', 'checkDUT', 'Value', checkDUT)
        uicheckbox(fig, "Position", [675, 160, 65, 22], 'Text', 'showRef', 'Tag', 'checkRef', 'Value', checkRef)
        
        % xy-Bereich.
        label_width = 200;
        text_width = 50;
    
        uilabel(fig, 'Position', [460, 80, label_width, 22], 'Text', 'Spannungsminimum [V]:', 'Tag', 'MinU');
        uieditfield(fig, 'numeric', 'Position', [460 + 150, 80, text_width, 22], 'Value', defaultXStart, 'Tag', 'defaultXStart');
    
        uilabel(fig, 'Position', [680, 80, label_width, 22], 'Text', 'Spannungsmaximum [V]:', 'Tag', 'MaxU');
        uieditfield(fig, 'numeric', 'Position', [680 + 150, 80, text_width, 22], 'Value', defaultXEnd, 'Tag', 'defaultXEnd');
    
        uilabel(fig, 'Position', [20, 80, label_width, 22], 'Text', 'Fläche [cm²]:', 'Tag', 'Area');
        uieditfield(fig, 'numeric', 'Position', [20 + 150, 80, text_width, 22], 'Value', defaultArea, 'Tag', 'defaultArea');
    
        uilabel(fig, 'Position', [240, 80, label_width, 22], 'Text', 'Nachkommastellen bei I:', 'Tag', 'decimal');
        uispinner(fig, 'Position', [240 + 150, 80, text_width, 22], 'Value', defaultDecimal, 'Tag', 'defaultDecimal', "Limits", [0, inf], 'RoundFractionalValues', 'on');
        
        % Ergebnisfeld
        uilabel(fig, 'Position', [750, 160, 100, 22], 'Text', '\fontname{Helvetica}I_{H2-Crossover}:', 'Tag', 'resultLabel', 'Interpreter', 'tex');
        uieditfield(fig, 'text', 'Position', [830, 160, 50, 22], 'Value', '', 'Tag', 'result', 'Editable', 'off');

        % Dateiauswahlliste hinzufügen
        uitextarea(fig, "Value",'Dateiauswahl:', 'Position', [460, 588, 120, 27], 'FontSize', 17.5, ...
            'Tag', 'fileListLabel', 'Editable', 'off', 'BackgroundColor', fig.Color);
        uilistbox(fig, 'Position', [460, 200, 420, 390], 'Tag', 'fileList', ...
            'Multiselect', 'on', 'Items', {});
    
        % Buttons
        uibutton(fig, 'push', 'Text', 'Neue Datei laden', ...
            'Position', [20, btn_y, btn_width, btn_height], ...
            'ButtonPushedFcn', @(btn, event) addFiles(fig), 'Tag', 'Neue Dateien');

        uibutton(fig, 'push', 'Text', 'Ganzen Bereich plotten', ...
            'Position', [240, btn_y, btn_width, btn_height], ...
            'ButtonPushedFcn', @(btn, event) fullPlot(fig), ...
            'Tag', 'plotButton'); % Plot Button ruft fullPlot auf
        
        uibutton(fig, 'push', 'Text', 'Fitten', ...
            'Position', [460, btn_y, btn_width, btn_height], ...
            'ButtonPushedFcn', @(btn, event) plotAndCalc(fig), ...
            'Tag', 'Fit'); % Plot Button ruft plotAndCalc auf

        uibutton(fig, 'push', 'Text', 'Zurück zur Auswahl', 'Position', ...
            [680, btn_y, btn_width, btn_height], ...
            'ButtonPushedFcn', @(btn, event) backToSelection(fig), 'Tag', 'backButton');


        uibutton(fig, 'Text', 'H2-Crossover config', 'Position', [fig.Position(3) - 150, fig.Position(4) - 32, 130, 22], ...
            'ButtonPushedFcn', @(btn, event) runMethodScript('H2_Crossover'), 'Tag', 'configButton');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen der Parameterfelder und Buttons.')
        disp(ME.message)
    end
end

%% Event-Handler und Callback-Funktionen

function resizeUIComponents(fig)
    % Diese Funktion passt die Größe und Position der UI-Elemente an, wenn die Fenstergröße geändert wird.
    try
        % Berechnung der Fenstergröße
        windowWidth = fig.Position(3);
        windowHeight = fig.Position(4);
    
        % Berechnung der Skalierungsfaktoren
        widthScaleFactor = windowWidth / 900;
        heightScaleFactor = windowHeight / 625;

        % Parameterfelder Variablen
        label_width = 200 * widthScaleFactor;
        text_width = 50 * widthScaleFactor;
        margin = 20 * widthScaleFactor;
        height = 22 * heightScaleFactor;
        
        % Buttons Variablen
        numButtons = 4;
        spacingOriginal = 20; % Ursprünglicher Abstand zwischen den Buttons und den Rändern
        spacing = spacingOriginal * widthScaleFactor; % Skalierten Abstand berechnen
        totalSpacing = (numButtons + 1) * spacing; % Totaler Abstand (zwischen Buttons und Rändern)
        
        % Verfügbare Breite für die Buttons berechnen
        availableWidth = fig.Position(3) - totalSpacing; 
        btn_width = availableWidth / numButtons; % Breite jedes Buttons
        btn_height = 50 * heightScaleFactor; % Höhe der Buttons
        
        % Berechne die x-Positionen der Buttons
        x_positions = spacing + (0:(numButtons-1)) * (btn_width + spacing);
        btn_y = 10 * heightScaleFactor;
        
        % Button Positionen
        resizeComponent(fig, 'Neue Dateien',    [x_positions(1),                btn_y,                      btn_width,                  btn_height])
        resizeComponent(fig, 'plotButton',      [x_positions(2),                btn_y,                      btn_width,                  btn_height])
        resizeComponent(fig, 'Fit',             [x_positions(3),                btn_y,                      btn_width,                  btn_height])
        resizeComponent(fig, 'backButton',      [x_positions(4),                btn_y,                      btn_width,                  btn_height])
        resizeComponent(fig, 'configButton',    [750 * widthScaleFactor,        593 * heightScaleFactor,    130 * widthScaleFactor,     height])

        % Titel
        resizeComponent(fig, 'title1',          [ 95 * widthScaleFactor,        160 * heightScaleFactor,    485 * widthScaleFactor,     height])
        resizeComponent(fig, 'title2',          [ 95 * widthScaleFactor,        120 * heightScaleFactor,    785 * widthScaleFactor,     height])

        % Checkboxen
        resizeComponent(fig, 'checkDUT',        [590 * widthScaleFactor,        160 * heightScaleFactor,     70 * widthScaleFactor,     height])
        resizeComponent(fig, 'checkRef',        [675 * widthScaleFactor,        160 * heightScaleFactor,     65 * widthScaleFactor,     height])

        % Textfelder für Spannungsmin und -max
        textDelta = btn_width - text_width;
        param_y = 80 * heightScaleFactor;
        resizeComponent(fig, 'defaultXStart',   [x_positions(3) + textDelta,    param_y,                    text_width,                 height])
        resizeComponent(fig, 'defaultXEnd',     [x_positions(4) + textDelta,    param_y,                    text_width,                 height])
    
        % Textfelder für Fläche und Nachkommastellen
        resizeComponent(fig, 'defaultArea',     [x_positions(1) + textDelta,    param_y,                    text_width,                 height])
        resizeComponent(fig, 'defaultDecimal',  [x_positions(2) + textDelta,    param_y,                    text_width,                 height])
    
        % Labels Position
        resizeComponent(fig, 'titel1label',     [margin,                        160 * heightScaleFactor,    100 * widthScaleFactor,     height])
        resizeComponent(fig, 'titel2label',     [margin,                        120 * heightScaleFactor,    100 * widthScaleFactor,     height])
        resizeComponent(fig, 'MinU',            [x_positions(3),                param_y,                    label_width,                height])
        resizeComponent(fig, 'MaxU',            [x_positions(4),                param_y,                    label_width,                height])
        resizeComponent(fig, 'Area',            [x_positions(1),                param_y,                    label_width,                height])
        resizeComponent(fig, 'decimal',         [x_positions(2),                param_y,                    label_width,                height])
    
        % InfoText und fileList skalieren
        resizeComponent(fig, 'infoText',        [margin,                        200 * heightScaleFactor,    420 * widthScaleFactor,     415 * heightScaleFactor])
        resizeComponent(fig, 'fileListLabel',   [460 * widthScaleFactor,        588 * heightScaleFactor,    120 * widthScaleFactor,      27 * heightScaleFactor])
        resizeComponent(fig, 'fileList',        [460 * widthScaleFactor,        200 * heightScaleFactor,    420 * widthScaleFactor,     390 * heightScaleFactor])
    
        % Ergebnisfeld skalieren
        resizeComponent(fig, 'resultLabel',     [750 * widthScaleFactor,        160 * heightScaleFactor,    100 * widthScaleFactor,     height])
        resizeComponent(fig, 'result',          [830 * widthScaleFactor,        160 * heightScaleFactor,     50 * widthScaleFactor,     height])
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

function [data, fileNames] = DataWrapper()
    % Diese Funktion liest Daten aus ausgewählten Dateien ein.
    try
        % config laden
        config = evalin("base", 'config');
        columns = config.Spalten;
    
        % Dateiauswahl-Dialog für txt-Dateien, falls sich das Dateiformat bzw.
        % der Dateityp ändert hier anpassen
        standardPath = evalin('base', 'standardPath');
        try
            oldFolder = cd(standardPath);
            [fileNames, filePath] = uigetfile('*.txt', 'Wählen Sie eine Datei zur Auswertung aus', 'MultiSelect', 'on');
            cd(oldFolder);
        catch ME
            fig = evalin('base', 'fig');
            uialert(fig, [ME.message], 'Standardordner nicht gültig, bitte in der config anpassen.', 'Icon', 'warning');
            [fileNames, filePath] = uigetfile('*.txt', 'Wählen Sie eine Datei zur Auswertung aus', 'MultiSelect', 'on');
        end
    
        if isequal(fileNames, 0)
            disp('Keine Datei ausgewählt'); 
            return;
        end

        assignin("base",'standardPath', filePath)

        % Überprüfung wie viele Dateien ausgewählt wurden
        if ischar(fileNames)
            dataFiles = {fullfile(filePath, fileNames)};
            fileNames = {fileNames};
        elseif length(fileNames) >= 2
            dataFiles = cell(1, length(fileNames));
            for i = 1:length(fileNames)
                dataFiles{i} = fullfile(filePath, fileNames{i}); 
            end
        else
            disp('Bitte mindestens eine Datei auswählen');
        end
    
        % Daten einlesen 
        currentRef = evalin("base", 'currentRef');
        [dataArray, ~] = read_txt(dataFiles, currentRef);
        data = cell(1, length(dataArray));
        for i = 1:length(dataArray)
            data{i} = dataArray{i}(:, columns);
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Lesen einer Datei.')
        disp(ME.message)
    end
end

function backToSelection(fig)
    try
        % unnötige Informationen aus Base Workspace löschen
        evalin("base", 'clear config')
        evalin('base', 'clear referenceFolder');
        evalin('base', 'clear fig');
        evalin('base', 'clear selectedFileName');
        % Rufe die Auswahlfunktion auf und übergebe das aktuelle Fenster.
        clc;
        evalin('base', 'clear data');
        Auswahl(fig);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Schließen der Methode.')
        disp(ME.message)
    end
end

%% Datenverarbeitungsfunktionen

function plotAndCalc(fig)
    try
        d = uiprogressdlg(fig,'Title','Bitte Warten',...
            'Message','Plot wird erstellt');
    
        % config laden
        config = evalin("base", 'config');
        lineWidth = config.lineWidth;
        nachkommastellen = num2str(config.Nachkommastellen_y);
        columns = config.Spalten;
        showReference = findobj(fig, 'Tag', 'checkRef').Value;
        showDUT = findobj(fig, 'Tag', 'checkDUT').Value;

        if ~showReference && ~showDUT
            return;
        end
    
        % Diese Funktion erstellt den Plot und berechnet den H2-Crossover
        d.Value = 0.1;
    
        infoText = findobj(fig, 'Tag', 'infoText');
        % Wenn die Daten nicht im Base Workspace existieren, Daten einlesen
        fileList = findobj(fig, 'Tag', 'fileList');
        data = fileList.Value;
        if isempty(data) && showDUT
            try
                data = fileList.ItemsData;
                if isempty(data)
                    error('no data');
                end
            catch
                uialert(fig, 'Bitte mindestens eine Datei laden.', 'Warnung', 'Icon', 'warning')
                return
            end
        end

        d.Value = 0.2;

        % Wenn die Referenzdaten-Checkbox ausgewählt ist
        if showReference
            referenceDataArray = evalin('base', 'referenceDataArray');
        end
        
        % Indize der Daten in der Liste ermitteln
        indexArray = NaN(1, length(data));
        for i = 1:length(data)
            file = data(i);
            indexArray(i) = find(cellfun(@(x) isequal(x, file{1}), fileList.ItemsData)) + 1;
        end
    
        % Reihenfolge der Daten ermitteln
        [~, order] = sort(indexArray);
        % Daten umsortieren
        data = data(order);
    
            
        % Filter auf relevanten Spannungsbereich anwenden
        if showDUT
            limits = findLimits(data, fig, 1);
            for i = 1:length(data)
                data{i} = data{i}(limits{i}(1):limits{i}(2), :);
            end
        end
        
        if showReference
            reflimits = findLimits(referenceDataArray, fig, columns(1));
            for i = 1:length(referenceDataArray)
                referenceDataArray{i} = referenceDataArray{i}(reflimits{i}(1):reflimits{i}(2), :);
            end
        end
    
        d.Value = 0.3;
        
        % Plotfenster erstellen
        figure('Units', 'normalized', 'OuterPosition', [0 0 1 1]);
        hold on; % Erlaube weitere Plots im Fenster
        % Achsenlimits:
        yLim = config.yAchsenLimitsFit;
        xLim = config.xAchsenLimitsFit;
        % Arrays für Berechnungen initialisieren
        yAchse = cell(1, length(data));
        steigung = cell(1, length(data));

        d.Value = 0.4;
        if showDUT
            % Referenz plotten
            if showReference
                for i = 1:length(referenceDataArray)
                    x = referenceDataArray{i}(:,columns(1));
                    y = referenceDataArray{i}(:,columns(2));
                    p = polyfit(x, y, 1);                                           % Lineare Regression
                    h = plot(x, y, '-o', 'LineWidth', lineWidth*3, 'Color', [0.9, 0.9, 0.9], 'HandleVisibility', 'off', 'MarkerSize', 12);      % plotten
                    h.MarkerFaceColor = h.Color;                                    % Marker ausfüllen (sonst weiße Markerfläche)
                    x_fit = linspace(0, max(x), length(x));                         % x für Fitgerade
                    y_fit = polyval(p, x_fit);                                      % y für Fitgerade
                    line(x_fit, y_fit, 'LineStyle', '-', 'LineWidth', lineWidth*3, 'Color', h.Color, 'HandleVisibility', 'off');  % Fitgerade
                end
            end
            % Daten plotten und lineare Regression durchführen
            colors = jet(length(data));
            for i = 1:length(data)
                x = data{i}(:,1);
                y = data{i}(:,2);
                p = polyfit(x, y, 1);                                           % Lineare Regression
                name = sprintf('%d. Messung', i);                               % Plotnamen festlegen
                h = plot(x, y, '-o', 'LineWidth', lineWidth, 'DisplayName', name, 'Color', colors(i,:));      % plotten
                h.MarkerFaceColor = h.Color;                                    % Marker ausfüllen (sonst weiße Markerfläche)
                x_fit = linspace(0, max(x), length(x));                         % x für Fitgerade
                y_fit = polyval(p, x_fit);                                      % y für Fitgerade
                line(x_fit, y_fit, 'LineStyle', '-', 'LineWidth', lineWidth, 'Color', h.Color, 'HandleVisibility', 'off');  % Fitgerade
                
                % Text für Fit-Gerade
                dataIndex = round((0.065 * i - 0.03) * length(x));              % x-Position für jede Gerade anpassen (um Überschneidung zu vermeiden)
                dataPointX = x_fit(dataIndex);
                dataPointY = polyval(p, x_fit(dataIndex));                      % y-Position für jede Gerade anpassen
                textOffsetX = 0;                                                % später für Verschiebung wichtig
                textOffsetY = -0.01;                                            % später für Verschiebung wichtig
                equationText = sprintf(['y = %.', nachkommastellen,'fx + %.', nachkommastellen,'f'], p(1), p(2));         % Gleichung des Fits
                hText = text(dataPointX + textOffsetX, dataPointY + textOffsetY, equationText, 'Color', h.Color, 'VerticalAlignment', 'bottom');    % Fitgerade
                hText.FontSize = config.fitTextSize;
                
                % Ausgabe der Gleichung im Infotext
                infoText.Value = [infoText.Value; ' '; 'Fitgerade ', name, ': '; strrep(equationText, '.', ',')];
        
                % Verschieben der Gleichungstexte ermöglichen
                hAx = gca;
                hText.ButtonDownFcn = @(src, event) startDragFcn(src, event, hAx);
        
                yAchse{i} = p(2);       % y-Achsenabschnitt für Berechnung speichern
                steigung{i} = p(1);     % Steigung für Berechnung speichern
            end
        elseif showReference
            % Referenz plotten und lineare Regression durchführen
            colors = jet(length(referenceDataArray));
            for i = 1:length(referenceDataArray)
                x = referenceDataArray{i}(:,columns(1));
                y = referenceDataArray{i}(:,columns(2));
                p = polyfit(x, y, 1);                                           % Lineare Regression
                name = sprintf('%d. Referenz', i);                               % Plotnamen festlegen
                h = plot(x, y, '-o', 'LineWidth', lineWidth, 'DisplayName', name, 'Color', colors(i,:));      % plotten
                h.MarkerFaceColor = h.Color;                                    % Marker ausfüllen (sonst weiße Markerfläche)
                x_fit = linspace(0, max(x), length(x));                         % x für Fitgerade
                y_fit = polyval(p, x_fit);                                      % y für Fitgerade
                line(x_fit, y_fit, 'LineStyle', '-', 'LineWidth', lineWidth, 'Color', h.Color, 'HandleVisibility', 'off');  % Fitgerade
                
                % Text für Fit-Gerade
                dataIndex = round((0.065 * i - 0.03) * length(x));              % x-Position für jede Gerade anpassen (um Überschneidung zu vermeiden)
                dataPointX = x_fit(dataIndex);
                dataPointY = polyval(p, x_fit(dataIndex));                      % y-Position für jede Gerade anpassen
                textOffsetX = 0;                                                % später für Verschiebung wichtig
                textOffsetY = -0.01;                                            % später für Verschiebung wichtig
                equationText = sprintf(['y = %.', nachkommastellen,'fx + %.', nachkommastellen,'f'], p(1), p(2));         % Gleichung des Fits
                hText = text(dataPointX + textOffsetX, dataPointY + textOffsetY, equationText, 'Color', h.Color, 'VerticalAlignment', 'bottom');    % Fitgerade
                hText.FontSize = config.fitTextSize;
                
                % Ausgabe der Gleichung im Infotext
                infoText.Value = [infoText.Value; ' '; 'Fitgerade ', name, ': '; strrep(equationText, '.', ',')];
        
                % Verschieben der Gleichungstexte ermöglichen
                hAx = gca;
                hText.ButtonDownFcn = @(src, event) startDragFcn(src, event, hAx);
        
                yAchse{i} = p(2);       % y-Achsenabschnitt für Berechnung speichern
                steigung{i} = p(1);     % Steigung für Berechnung speichern
            end
            
        end
        
        d.Value = 0.8;
    
        % Plotfenster anpassen
        configureaxes(yLim, xLim); 
        xlabel(config.xlabel, 'FontWeight', 'bold');
        ylabel(config.ylabel, 'FontWeight', 'bold');
        hLegend = legend('Location', 'best');
        hLegend.Position(1) = 0.6;
        hLegend.Position(2) = 0.5;
        hLegend.FontSize = config.legendFontSize;
    
        % Durchschnittlichen Fit berechnen
        y = mean(cell2mat(yAchse));
        if length(y) ~= 1
            m = mean(cell2mat(steigung));
            equationText = sprintf(['y = %.', nachkommastellen,'fx + %.', nachkommastellen,'f'], m, y);
            % Ausgabe der Durchschnitssgleichung im Infotext
            infoText.Value = [infoText.Value; ' '; 'Durchschnittlicher Fit: '; strrep(equationText, '.', ',')]; 
        end
    
        d.Value = 0.9;
    
        % H2-Crossover berechnen und anzeigen
        area = findobj(fig, 'Tag', 'defaultArea').Value;            % Fläche auslesen
        decimal = findobj(fig, 'Tag', 'defaultDecimal').Value;      % Dezimalpunktstelle auslesen
        H2_Crossover = num2str(round(y * 1000 / area, decimal));                % H2-Crossover berechnen
        result = findobj(fig, 'Tag', 'result');
        result.Value = H2_Crossover;
        formattedText = sprintf('I(H2-Crossover) ≈ %s mA/cm²', strrep(H2_Crossover, '.', ','));
        % Berechneten H2-Crossover im Plot zeigen
        hCross = text(xLim(1)+0.056*diff(xLim), yLim(1)+0.3*diff(yLim), formattedText, 'Color', [192/255 0 0], 'BackgroundColor', [200/255 200/255 200/255], 'FontSize', config.IH2_CrossoverSize, 'FontWeight', 'bold', 'EdgeColor', [165/255 165/255 165/255]);
        % Verschieben der H2-Crossover Textbox ermöglichen
        hCross.ButtonDownFcn = @(src, event) startDragFcn(src, event, hAx);
        d.Value = 1;
        close(d)
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Fitten oder Plotten.')
        disp(ME.message)
    end
end

function index = findLimits(data, fig, column)
    % Diese Funktion findet die Indizes für den Start- und Endwerte, basierend auf dem angegebenen Spannungsbereich
    try
        startVoltage = findobj(fig, 'Tag', 'defaultXStart').Value;
        endVoltage = findobj(fig, 'Tag', 'defaultXEnd').Value;
        index = cell(1, length(data));
        for i = 1:length(data)
            start = find(data{i}(:,column) >= startVoltage, 1);
            stop = find(data{i}(:,column) >= endVoltage, 1);
            index{i} = [start, stop]; 
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Suchen der Limits.')
        disp(ME.message)
    end
end

function fullPlot(fig)
    try
        d = uiprogressdlg(fig,'Title','Bitte Warten',...
            'Message','Plot wird erstellt');
        % config laden
        config = evalin("base", 'config');
        lineWidth = config.lineWidth;
        columns = config.Spalten;
        showReference = findobj(fig, 'Tag', 'checkRef').Value;
        showDUT = findobj(fig, 'Tag', 'checkDUT').Value;

        if ~showReference && ~showDUT
            return;
        end
    
        % Diese Funktion erstellt einen Gesamtplot der eingelesenen Daten.
        fileList = findobj(fig, 'Tag', 'fileList');
        data = fileList.Value;
        if isempty(data) && showDUT
            try
                data = fileList.ItemsData;
                if isempty(data)
                    error('no data');
                end
            catch
                uialert(fig, 'Bitte mindestens eine Datei laden.', 'Warnung', 'Icon', 'warning')
                return
            end
        end

        % Indize der Daten in der Liste ermitteln
        indexArray = NaN(1, length(data));
        for i = 1:length(data)
            file = data(i);
            indexArray(i) = find(cellfun(@(x) isequal(x, file{1}), fileList.ItemsData)) + 1;
        end
    
        % Reihenfolge der Daten ermitteln
        [~, order] = sort(indexArray);
        % Daten umsortieren
        data = data(order);

        % Wenn die Referenzdaten-Checkbox ausgewählt ist
        if showReference
            referenceDataArray = evalin('base', 'referenceDataArray');
        end
    
        d.Value = 0.1;
    
        t1 = char(findobj(fig, 'Tag', 'title1').Value);
        t2 = char(findobj(fig, 'Tag', 'title2').Value);
        replaceSpecialChars = @(str) regexprep(regexprep(str, '_(?!{)', '\\_'), '\^(?!{)', '\\^');
        t1 = replaceSpecialChars(t1);
        t2 = replaceSpecialChars(t2);
    
        d.Value = 0.3;
    
        % Plotfenster erstellen
        figure('Units', 'normalized', 'OuterPosition', [0 0 1 1]);
        hold on; % Erlaube weitere Plots im Fenster
        if showDUT
            if showReference
                for i = 1:length(referenceDataArray)
                    % Referenz plotten
                    x = referenceDataArray{i}(:,columns(1));
                    y = referenceDataArray{i}(:,columns(2)); 
                    r = plot(x, y, '-o', 'LineWidth', lineWidth * 3, 'MarkerSize', 10, ...
                        'HandleVisibility', 'off', 'Color', [0.9, 0.9, 0.9]);
                    r.MarkerFaceColor = r.Color;    % Marker ausfüllen (sonst weiße Markerfläche)
                end
            end
            colors = jet(length(data));
            for i = 1:length(data)
                x = data{i}(:,1);
                y = data{i}(:,2);
                name = sprintf('%d. Messung', i);                                   % Plotname ermitteln
                h = plot(x, y, '-o', 'LineWidth', lineWidth, 'DisplayName', name, 'Color', colors(i,:));          % plotten
                h.MarkerFaceColor = h.Color;                                        % Marker ausfüllen (sonst weiße Markerfläche)
            end
        elseif showReference
            colors = jet(length(referenceDataArray));
            for i = 1:length(referenceDataArray)
                x = referenceDataArray{i}(:,columns(1));
                y = referenceDataArray{i}(:,columns(2));
                name = sprintf('%d. Referenz', i);                                   % Plotname ermitteln
                h = plot(x, y, '-o', 'LineWidth', lineWidth, 'DisplayName', name, 'Color', colors(i,:));          % plotten
                h.MarkerFaceColor = h.Color;                                        % Marker ausfüllen (sonst weiße Markerfläche)
            end
        end
    
        d.Value = 0.7;
        
        % Plotfenster anpassen
        yLim = config.yAchsenLimitsGesamt;
        xLim = config.xAchsenLimitsGesamt;
        configureaxes(yLim, xLim);
        title(t1, t2);
        xlabel(config.xlabel, 'Position', ...
            [mean(xLim) + diff(xLim) * 0.018, yLim(1) - diff(yLim) * 0.035], ...
            'FontWeight', 'bold');
        ylabel(config.ylabel, 'FontWeight', 'bold');
        hLegend = legend('Location', 'best');
        hLegend.Position(1) = 0.6;
        hLegend.Position(2) = 0.5;
        hLegend.FontSize = config.legendFontSize;
    
        d.Value = 0.8;
        
        d.Value = 1;
        close(d)
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Gesamtplots.')
        disp(ME.message)
    end
end


%% Helfer- und Dienstprogramme

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

function configureaxes(yLim, xLim)
    try
        config = evalin("base", 'config');
        
        % Anpassung des Plotfensters
        ax = gca;
        ax.XGrid = 'on'; % Aktivieren des X-Gitters
        ax.YGrid = 'on'; % Aktivieren des Y-Gitters
        ax.GridLineStyle = '-'; % Durchgezogene Gitterlinien
        ax.GridColor = [0.5, 0.5, 0.5]; % Gitterfarbe: Grau
        ax.GridAlpha = 0.7; % Transparenz
        ax.XLim = xLim; % X-Achsenlimit setzen
        ax.YLim = yLim; % Y-Achsenlimit setzen
        ax.XAxisLocation = 'origin'; % X-Achse am Ursprung
        ax.YAxisLocation = 'origin'; % Y-Achse am Ursprung
        
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
        uialert(fig, ME.message, 'Fehler beim Anpassen des Plots.')
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
        uialert(fig, ME.message, 'Fehler beim Updaten der Ticklabels.')
        disp(ME.message)
    end
end

%% Eingabe-/Ausgabefunktionen