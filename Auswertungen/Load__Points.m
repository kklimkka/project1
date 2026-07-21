%% Setup- und Initialisierungsfunktionen

function Load__Points(referenceFolder)
    % Hauptfunktion, die den gesamten Ablauf steuert.
    % Diese Funktion ruft die config.json ab, richtet die GUI ein und fügt erforderliche Pfade hinzu.
    %
    % Args:
    %    referenceFolder (string): Pfad zum Ordner mit den Referenzdaten
    try
        % Abruf der config.json und vervollständigen des Pfades zum Referenzordner
        currentRef = referenceFolder;
        configData = jsondecode(fileread(fullfile(currentRef, 'config.json')));
        loadPoints_config = configData.Load__Points;
        assignin("base", 'currentRef', currentRef)
        assignin("base", "config", loadPoints_config)
    
        % Suche nach der Beispiel-Excel-Datei im Referenzordner und speichere ihren Pfad im Base Workspace
        referenceFolder = fullfile(referenceFolder, '\Load__Points');
        exampleExcel = dir(fullfile(referenceFolder, '*.xlsx'));
        exampleExcelMakro = dir(fullfile(referenceFolder, '*.xlsm'));
        if ~isempty(exampleExcel)
            exampleExcelPath = fullfile(referenceFolder, exampleExcel(1).name);
            assignin('base', 'exampleExcelPath', exampleExcelPath);
        elseif ~isempty(exampleExcelMakro)
            exampleExcelPath = fullfile(referenceFolder, exampleExcelMakro(1).name);
            assignin('base', 'exampleExcelPath', exampleExcelPath);
        else
            exampleExcelPath = fullfile(fileparts(fileparts(referenceFolder)), 'Standard export.xlsx');
            assignin('base', 'exampleExcelPath', exampleExcelPath);
        end
    
        % Aktuelles Fenster als 'fig' laden und benennen
        fig = evalin('base', 'fig');
        fig.Name = 'Load Points';
    
        % Setup von 'fig' mit Buttons, Standardwerten und Textfeldern
        delete(fig.Children);
        createButtons(fig);
        setupFigure(fig);
        createParameterFields(fig);
        createFileSelectionFields(fig);
        createConfigBtn(fig);
    
        % Event-Listener für die Größenänderung des Fensters hinzufügen
        fig.SizeChangedFcn = @(src, event) resizeUIComponents(fig);
        fig.AutoResizeChildren = 'off';  % Deaktivieren der automatischen Größenanpassung
    
        % Initiale Größenanpassung auf aktuelle Fenstergröße
        resizeUIComponents(fig);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Öffnen des Load Points-Fensters.')
        disp(ME.message)
    end
end

function setupFigure(fig)
    % Leeren von 'fig' und Hinzufügen eines Textbereichs zum Anzeigen von Informationen.
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    %    config (struct): Konfigurationsdaten
    try
        config = evalin("base", 'config');
        margin = 20;
        
        % Textbereich hinzufügen
        uitextarea(fig, 'Position', [margin, 470, 500, fig.Position(4) - 480], ...
            'Value', [
                'Die Auswertungsmethode "Load Points" wurde ausgewählt:' newline ...
                '> Daten werden immer direkt vor dem Ende der in der config benannten Triggerpunkte ausgewertet' newline ...
                '>> Mittelwert ab ...: Gibt an wie viele Sekunden vor jedem Triggerwechsel für die jeweilige Mittelwertberechnung genutzt werden sollen' newline ...
                '>> Messwerte pro Sekunde: Gibt an wie viele Messwerte es in der Datei pro Sekunde gibt' newline ...
                '>> Export in Excel: Falls diese Checkbox gewählt wird, wird eine Excel generiert (siehe Readme FC-OPAT.txt)' newline ...
                '>> Achsenlimits bei Time: Setzt die Limits der X-Achse (Format: 1000, 4000)' newline ...
                '>> Achsenlimits bei Parametern: Setzt die Limits der Y-Achse (Format: 1000, 4000)'
            ], ...
            'Tag', 'infoText');
    
        % Tabelle hinzufügen
        header = {'Load Point', 'Parameter 1', 'Parameter 2'};
        uitable(fig, 'Data', {}, 'ColumnName', header, 'Position', ...
            [2 * margin + 500, 130, fig.Position(3) - 3 * margin - 500, fig.Position(4) - 310], 'Tag', 'dataTable');
    
        % Creating the column table
        headerColumn = config.Header(:);
        spaltenColumn = num2cell(config.Spalten(:)); % Convert to cell array for mixed data types
        colorColumn = config.Colors(:);
        limitColumn = config.Limits(:);
        data = [headerColumn, spaltenColumn, colorColumn, limitColumn];
        
        uilabel(fig, 'text', 'Spalten der CSV-Datei, die geplottet werden sollen:', 'Position', [margin 450 500 15], 'Tag', 'SpaltenLabel');
        columnNames = {'Header', 'Spalten', 'Hex-Farben ', 'Achsenlimits'};
        uitable(fig, 'Data', data, 'ColumnName', columnNames, 'ColumnEditable', [false, false, true, true], 'CellSelectionCallback', @selectRow, ...
            'Position', [margin, 130, 500, fig.Position(4) - 310], 'ColumnWidth', {'40x', '12x', '17x', '19x'}, 'FontSize', 11, ...
            'Tag', 'columnTable', 'ColumnFormat', {'char', 'numeric', 'char', 'char'});
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Infotextes und der Tabellen.')
        disp(ME.message)
    end
end

function createConfigBtn(fig)
    try
        uibutton(fig, 'Text', 'Load Points config', 'Position', [fig.Position(3) - 150, fig.Position(4) - 32, 130, 22], ...
            'ButtonPushedFcn', @(btn, event) runMethodScript('Load__Points'), 'Tag', 'configButton');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Config-Buttons.')
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
            fig = findall(0, 'Type', 'figure', 'Name', 'Load Points Einstellungen'); 

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

        configData = jsondecode(fileread(fullfile(currentRef, 'config.json')));
        loadPoints_config = configData.Load__Points;
        assignin("base", "config", loadPoints_config)
        
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

function createButtons(fig)
    % Erzeugt Exit- und Back-Buttons, um das Programm zu beenden und zur Auswahl zurückzukehren
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    try
        buttonWidth = 200;
        buttonHeight = 50;
        centerX = fig.Position(3) / 2;
    
        % Zurück-Button erstellen
        uibutton(fig, 'push', 'Text', 'Zurück zur Auswahl', 'Tag', 'backButton', ...
            'Position', [centerX + 120, 10, buttonWidth, buttonHeight], ...
            'ButtonPushedFcn', @(btn, event) backToSelection(fig));
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Zurück-Buttons.')
        disp(ME.message)
    end
end

function createFileSelectionFields(fig)
    % Diese Funktion erstellt die Dateiauswahlliste
    try
        plot_btn_width = 200;
        plot_btn_height = 50;
        plot_btn_x = (fig.Position(3) / 2) - plot_btn_width - 120;
        plot_btn_y = 10;
        margin = 20;
    
        % Dateiauswahlliste hinzufügen
        uitextarea(fig, "Value",'Dateiauswahl:', 'Position', [2 * margin + 500, fig.Position(4) - 37, 120, 27], 'FontSize', 17.5, ...
            'Tag', 'fileListLabel', 'Editable', 'off', 'BackgroundColor', fig.Color);
        uilistbox(fig, 'Position', [2 * margin + 500, 470, fig.Position(3) - 3 * margin - 500, fig.Position(4) - 505], 'Tag', 'fileList', ...
            'Multiselect', 'on', 'Items', {});
    
        % Datei-Button hinzufügen
        uibutton(fig, 'push', 'Text', 'Neue Datei laden', 'Position', [plot_btn_x, plot_btn_y, plot_btn_width, plot_btn_height], ...
            'ButtonPushedFcn', @(btn, event) addFiles(fig), 'Tag', 'Neue Dateien');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Dateiauswahlfeldes.')
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

        for i = 1:length(fileNames)
            if ~isempty(data{i})
                addFileToList(fileList, fileNames{i}, data{i}, length(fileList.Items) + 1)
            else
                uialert(fig, 'Wahrscheinlich wird mind. ein Parameter in einer Spalte gesucht, die in der Datei leer ist.', ['Fehler beim hinzufügen der ', num2str(i), '. Datei.'])
            end
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
    % Diese Funktion erstellt Parameterfelder und Buttons für die GUI.
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    %    config (struct): Konfigurationsdaten
    try
        config = evalin("base", 'config');
        % Definition der Standardwerte 
        defaultTime = config.MWAbSekundenVor;
        defaultFactor = config.MesswerteProSekunde;
        export = config.checkExport;
        decimalI = config.NachkommastellenStrom;
        decimalU = config.NachkommastellenSpannung;
        defaultTitle = config.Titel;
    
        % Parameter für den Plot-Button
        buttonWidth = 200;
        buttonHeight = 50;
        centerX = fig.Position(3) / 2;
        
        headers = config.Header;
    
        % Textfelder hinzufügen um Standardwerte anzeigen und anpassen zu können.
        text_width = 50;
    
        uilabel(fig, 'Position', [20, 100, 170, 22], 'Text', 'Nachkommastellen des Stroms:', 'Tag', 'decimalILabel');
        uispinner(fig, 'Position', [210, 100, text_width+10, 22], 'Value', decimalI, 'Tag', 'decimalI', 'Limits', [0, inf], 'RoundFractionalValues', 'on');
    
        % Titel
        uilabel(fig, 'Position', [295, 100, 26, 22], 'Text', 'Titel:', 'Tag', 'titleLabel'); 
        uieditfield(fig, 'text', 'Position', [331, 100, 430, 22], 'Value', defaultTitle{1}, 'Tag', 'title');
        
        uilabel(fig, 'Position', [20, 70, 185, 22], 'Text', 'Nachkommastellen der Spannung:', 'Tag', 'decimalULabel');
        uispinner(fig, 'Position', [210, 70, text_width+10, 22], 'Value', decimalU, 'Tag', 'decimalU', 'Limits', [0, inf], 'RoundFractionalValues', 'on');
        
        uilabel(fig, 'Position', [295, 70, 152, 22], 'Text', 'Messwerte pro Sekunde:', 'Tag', 'factorLabel');
        uieditfield(fig, 'numeric', 'Position', [435, 70, text_width, 22], 'Value', defaultFactor, 'Tag', 'defaultFactor');
        
        uilabel(fig, 'Position', [550, 70, 275, 22], 'Text', 'Mittelwert ab ... Sekunden vor Ende des Triggers:', 'Tag', 'timeLabel');
        uieditfield(fig, 'numeric', 'Position', [830, 70, text_width, 22], 'Value', defaultTime, 'Tag', 'defaultTime');
        
        % Checkboxen ob Referenzdaten und DUT angezeigt werden sollen.
        uicheckbox(fig, 'Text', 'Export in Excel', 'Position', [780, 100, 100, 22], 'Value', export, 'Tag', 'export');
    
        % Plot Button hinzufügen
        uibutton(fig, 'push', 'Text', 'Daten Plotten', 'Position', [centerX - buttonWidth / 2, 10, buttonWidth, buttonHeight], ...
            'ButtonPushedFcn', @(btn, event) Plot(fig, headers), 'Tag', 'Plot');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen der Parameterfelder.')
        disp(ME.message)
    end
end

%% Event-Handler und Callback-Funktionen

function resizeUIComponents(fig)
    % Diese Funktion passt die Größe und Position der UI-Elemente an, wenn die Fenstergröße geändert wird.
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    try
        % Einlesen der Fenstergröße
        windowWidth = fig.Position(3);
        windowHeight = fig.Position(4);
    
        % Berechnung der Skalierungsfaktoren
        widthScaleFactor = windowWidth / 900;
        heightScaleFactor = windowHeight / 625;
        margin = 20 * widthScaleFactor;
        height = 22 * heightScaleFactor;
    
        % Infotext und Tabelle skalieren
        resizeComponent(fig, 'infoText',        [margin,                    469 * heightScaleFactor,    500 * widthScaleFactor,     146 * heightScaleFactor]);
        resizeComponent(fig, 'fileListLabel',   [540 * widthScaleFactor,    588 * heightScaleFactor,    120 * widthScaleFactor,      27 * heightScaleFactor]);
        resizeComponent(fig, 'fileList',        [540 * widthScaleFactor,    469 * heightScaleFactor,    340 * widthScaleFactor,     121 * heightScaleFactor]);
        resizeComponent(fig, 'configButton',    [750 * widthScaleFactor,    593 * heightScaleFactor,    130 * widthScaleFactor,     height]);
        resizeComponent(fig, 'dataTable',       [540 * widthScaleFactor,    130 * heightScaleFactor,    340 * widthScaleFactor,     315 * heightScaleFactor]);
        resizeComponent(fig, 'columnTable',     [margin,                    130 * heightScaleFactor,    500 * widthScaleFactor,     315 * heightScaleFactor]);
        resizeComponent(fig, 'SpaltenLabel',    [margin,                    450 * heightScaleFactor,    500 * widthScaleFactor,      15 * heightScaleFactor]);
    
        % Parameterfelder
        resizeComponent(fig, 'timeLabel',       [550 * widthScaleFactor,     70 * heightScaleFactor,    270 * widthScaleFactor,     height]);
        resizeComponent(fig, 'defaultTime',     [830 * widthScaleFactor,     70 * heightScaleFactor,     50 * widthScaleFactor,     height]);
        resizeComponent(fig, 'factorLabel',     [295 * widthScaleFactor,     70 * heightScaleFactor,    152 * widthScaleFactor,     height]);
        resizeComponent(fig, 'defaultFactor',   [435 * widthScaleFactor,     70 * heightScaleFactor,     50 * widthScaleFactor,     height]);
        resizeComponent(fig, 'decimalILabel',   [ 20 * widthScaleFactor,    100 * heightScaleFactor,    170 * widthScaleFactor,     height]);
        resizeComponent(fig, 'decimalI',        [210 * widthScaleFactor,    100 * heightScaleFactor,     60 * widthScaleFactor,     height]);
        resizeComponent(fig, 'decimalULabel',   [ 20 * widthScaleFactor,     70 * heightScaleFactor,    185 * widthScaleFactor,     height]);
        resizeComponent(fig, 'decimalU',        [210 * widthScaleFactor,     70 * heightScaleFactor,     60 * widthScaleFactor,     height]);
        resizeComponent(fig, 'titleLabel',      [295 * widthScaleFactor,    100 * heightScaleFactor,     26 * widthScaleFactor,     height]);
        resizeComponent(fig, 'title',           [331 * widthScaleFactor,    100 * heightScaleFactor,    430 * widthScaleFactor,     height]);
    
        % Checkboxen
        resizeComponent(fig, 'export',          [780 * widthScaleFactor,    100 * heightScaleFactor,    100 * widthScaleFactor,     height]);
        
        % Buttons
        btn_y = 10 * heightScaleFactor;
        btn_width = 200 * widthScaleFactor;
        btn_height = 50 * heightScaleFactor;

        resizeComponent(fig, 'Neue Dateien',    [130 * widthScaleFactor,    btn_y,                      btn_width,                  btn_height]);
        resizeComponent(fig, 'Plot',            [350 * widthScaleFactor,    btn_y,                      btn_width,                  btn_height]);
        resizeComponent(fig, 'backButton',      [570 * widthScaleFactor,    btn_y,                      btn_width,                  btn_height]);
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

function backToSelection(fig)
    % Diese Funktion kehrt zur Auswahl zurück und löscht unnötige Informationen aus dem Base Workspace.
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    try
        % Überprüfen, ob die Variable "referenceDataArray" existiert, und diese löschen
        evalin('base', 'clear referenceDataArray config referenceFolder fig');
        
        % Auswahl-Funktion aufrufen und das aktuelle Fenster übergeben
        clc;
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

function Plot(fig, headers)
    % Diese Funktion erstellt den Plot basierend auf den ausgewählten Daten.
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    %    headers (array): Array der Header der Spalten
    try
        config = evalin("base", 'config');
        d = uiprogressdlg(fig,'Title','Bitte Warten',...
            'Message','Plot wird erstellt');
        
        title1 = findobj(fig, 'Tag', 'title').Value;
        tableHandle = findobj(fig, 'Tag', 'columnTable');
        selectedRows = tableHandle.Selection;
        if ~isempty(selectedRows)
            selectedRows = selectedRows(:, 1);
        end
        selectedRows = unique(selectedRows);
        hexcolors = tableHandle.Data(:,3);
        hex2rgb = @(hex) sscanf(hex(2:end), '%2x%2x%2x', [1 3]) / 255;
        colors = cell2mat(cellfun(hex2rgb, hexcolors, 'UniformOutput', false));
    
        achsenlimits = tableHandle.Data(:,4);
    
        lineWidth = config.lineWidth;
        
        triggerColumn = strcmpi(headers, 'trigger');
    
        d.Value = 0.1;
    
        export = findobj(fig, 'Tag', 'export').Value;
        fileList = findobj(fig, 'Tag', 'fileList');
        data = fileList.Value;
        if isempty(data) || isempty(data{1})
            try
                data = fileList.ItemsData;
            catch
                uialert(fig, 'Bitte mindestens eine Datei laden.', 'Warnung')
                return
            end
        end
        if isempty(data) || isempty(data{1})
            uialert(fig, 'Bitte mindestens eine Datei laden.', 'Warnung')
            return
        end

        l = length(data);

        % Indize der Daten in der Liste ermitteln
        indexArray1 = NaN(1, l);
        for i = 1:l
            file = data(i);
            indexArray1(i) = find(cellfun(@(x) isequal(x(50,:), file{1}(50,:)), fileList.ItemsData)) + 1;
        end
    
        d.Value = 0.2;
    
        % Reihenfolge der Daten ermitteln
        [~, order] = sort(indexArray1);
        % Daten umsortieren
        data = data(order);
    
        d.Value = 0.2;
        allTriggerNames = cell(1, l);
        allAvgArrays = cell(1, l);
        
        for i = 1:l
            currData = data{i};
            [indexArray, triggerNames] = findIndices(currData(:, triggerColumn));
            allTriggerNames{i} = triggerNames;

            avgArray = allAvg(currData, indexArray, fig);
            if export
                exportToxlsx(fig, headers, avgArray, currData) % Export jeder Datei einzeln
            end
            allAvgArrays{i} = avgArray;
        end
        if ~isempty(allAvgArrays{1})
            editTable(fig, allAvgArrays, allTriggerNames)
        end
    
        d.Value = 0.4;
    
        if length(selectedRows)<=0
            selectedRows = [config.SpannungsIndex; config.StromIndex];
        elseif length(selectedRows) == 1 && selectedRows(1) == config.ZeitIndex
            selectedRows = [config.ZeitIndex; config.SpannungsIndex; config.StromIndex];
        end
        if selectedRows(1) ~= 1
            newSelectedRows = nan(length(selectedRows) + 1, 1);
            newSelectedRows(1) = 1;
            newSelectedRows(2:end, 1) = selectedRows(:, 1);
            selectedRows = newSelectedRows;
        end
        
        time = cell(1, l);
        for i = 1:l
            currData = data{i};
            data{i} = currData(:, selectedRows);
            time{i} = currData(:, config.ZeitIndex);
        end
        headers = headers(selectedRows);
    
        figure('Units', 'normalized', 'OuterPosition', [0 0.01 1 0.99]);
        hold on;    % Erlaube weitere Plots im Fenster
        
        numColumns = length(selectedRows);
        colors = colors(selectedRows, :);
        achsenlimits = achsenlimits(selectedRows);
        colorOrder = get(gca, 'ColorOrder');
        
        d.Value = 0.5;
    
        if numColumns == 2
            for n = 1:l
                if l == 1
                    color = colors(2, :);
                else
                    e = mod(n, size(colorOrder, 1)) + 1;
                    color = colorOrder(e, :);
                end
                currData = data{n};

                displayName = strrep(headers{2}, '_', '\_');
                if l > 1
                    displayName = [displayName, ' #', num2str(n)]; %#ok<AGROW> 
                end
                if contains(headers{2}, 'Set', 'IgnoreCase', true)
                    plot(time{n}, currData(:, 2), 'LineWidth', lineWidth, 'Color', color, 'DisplayName', displayName, 'LineStyle', '--');
                else
                    plot(time{n}, currData(:, 2), 'LineWidth', lineWidth, 'Color', color, 'DisplayName', displayName);
                end
        
                d.Value = 0.7;
        
                ylabel(['\fontsize{', num2str(config.ylabelSize), '}', strrep(headers{2}, '_', '\_')]);
                if ~strcmp(achsenlimits{2},'auto') && ~isempty(achsenlimits{2})
                    lims = strsplit(achsenlimits{2}, ',');
                    ylim([str2double(lims{1}), str2double(lims{2})]);
                else
                    upperLim = max(currData(:, 2));
                    lowerLim = min(currData(:, 2));
                    if upperLim > 0
                        ylim([0, upperLim]);
                    elseif lowerLim < 0
                        ylim([lowerLim, 0]);
                    end
                end
        
                ax = gca;
                ax.XAxis.FontSize = config.xTickSize;
                ax.YAxis.FontSize = config.yTickSize;
        
                d.Value = 0.8;
            end
        elseif numColumns == 3
            ax = gca;
            for i = 2:numColumns
                for n = 1:l
                    if l == 1
                        color = colors(i, :);
                    else
                        e = mod(n + (i-2)*l, size(colorOrder, 1)) + 1;
                        color = colorOrder(e, :);
                    end

                    currData = data{n};
    
                    if mod(i, 2) == 0
                        yyaxis left;
                    else
                        yyaxis right;
                    end
    
                    displayName = strrep(headers{i}, '_', '\_');
                    if l > 1
                        displayName = [displayName, ' #', num2str(n)]; %#ok<AGROW> 
                    end
                    if contains(headers{i}, 'Set', 'IgnoreCase', true)
                        plot(time{n}, currData(:, i), 'LineWidth', lineWidth, 'Color', color, 'DisplayName', displayName, 'LineStyle', '--');
                    else
                        plot(time{n}, currData(:, i), 'LineWidth', lineWidth, 'Color', color, 'DisplayName', displayName);
                    end
        
                    d.Value = 0.7;
        
                    ylabel(['\fontsize{', num2str(config.ylabelSize), '}', strrep(headers{i}, '_', '\_')]);
                    set(gca, 'YColor', colors(i,:));
                    if ~strcmp(achsenlimits{i},'auto') && ~isempty(achsenlimits{i})
                        lims = strsplit(achsenlimits{i}, ',');
                        ylim([str2double(lims{1}), str2double(lims{2})]);
                    else
                        upperLim = max(currData(:, i));
                        lowerLim = min(currData(:, i));
                        if upperLim > 0
                            ylim([0, upperLim]);
                        elseif lowerLim < 0
                            ylim([lowerLim, 0]);
                        end
                    end
                    ax.YAxis(i-1).FontSize = config.yTickSize;

                    d.Value = 0.8;
                end
            end

            ax.XAxis.FontSize = config.xTickSize;
        else
            for i = 2:numColumns
                for n = 1:l
                    if l == 1
                        color = colors(i, :);
                    else
                        e = mod(n + (i-2)*l, size(colorOrder, 1)) + 1;
                        color = colorOrder(e, :);
                    end

                    currData = data{n};

                    currentData = currData(:, i);
                    currentMax = max(currentData);
                    if ~strcmp(achsenlimits{i},'auto') && ~isempty(achsenlimits{i})
                        lims = strsplit(achsenlimits{i}, ',');
                        currentMax = str2double(lims{2});
                    end
                    if currentMax <= 0
                        currentMax = min(currentData);
                    end
                    for w = 1:length(currentData)
                        currentData(w) = currentData(w)/currentMax;
                    end

                    displayName = strrep(headers{i}, '_', '\_');
                    if l > 1
                        displayName = [displayName, ' #', num2str(n)]; %#ok<AGROW> 
                    end

                    if contains(headers{i}, 'Set', 'IgnoreCase', true)
                        plot(time{n}, currentData, 'LineWidth', lineWidth, 'Color', color, 'DisplayName', [displayName, ', Faktor ', num2str(currentMax, 5)], 'LineStyle', '--');
                    else
                        plot(time{n}, currentData, 'LineWidth', lineWidth, 'Color', color, 'DisplayName', [displayName, ', Faktor ', num2str(currentMax, 5)]);
                    end
                end
            end
            d.Value = 0.7;
    
            ylim([0, 1.005])
    
            ax = gca;
            ax.XAxis.FontSize = config.xTickSize;
            ax.YAxis.FontSize = config.yTickSize;
    
            d.Value = 0.8;
        end
        xlim1 = 0;
        xlim2 = 0;
        if ~strcmp(achsenlimits{1},'auto') && ~isempty(achsenlimits{1})
            lims = strsplit(achsenlimits{1}, ',');
            if length(lims) == 1
                xlim2 = str2double(lims{1});  
            else
                xlim1 = str2double(lims{1});
                xlim2 = str2double(lims{2});  
            end
        else
            for m = 1:l
                currTime = time{m};
                timeLim = currTime(end);
                if timeLim > xlim2
                    xlim2 = timeLim;
                elseif xlim1 > timeLim
                    xlim1 = timeLim;
                end
            end
        end

        xlim([xlim1, xlim2]);
        xlabel(config.xlabel);
        l = legend();
        l.FontSize = config.legendFontSize;
        title(title1);
        d.Value = 1;
        close(d)
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Plots.')
        disp(ME.message)
    end
end

function editTable(fig, allAvgArrays, allTriggerNames)
    try
        config = evalin("base", 'config');

        decimalI = findobj(fig, 'Tag', 'decimalI').Value;
        decimalU = findobj(fig, 'Tag', 'decimalU').Value;
        dataTable = findobj(fig, 'Tag', 'dataTable');
        dataTable.ColumnName(2) = config.Header(config.StromIndex);
        dataTable.ColumnName(3) = config.Header(config.SpannungsIndex);
        % Konvertiere allAvgCurrents und allAvgVoltages in Strings und erstelle Zellen
        avgCurrentsCell = {};
        avgVoltagesCell = {};
        triggerNamesCell = {};
        
        for i = 1:length(allAvgArrays)
            avgArray = allAvgArrays{i};
            triggerNames = allTriggerNames{i};

            % Füge eine Zeile mit dem Dateinamen hinzu
            triggerNamesCell = [triggerNamesCell; ['Datei #', num2str(i)]]; %#ok<AGROW> % Leere Zelle für Triggernamen
            avgCurrentsCell = [avgCurrentsCell; {' '}]; %#ok<AGROW> 
            avgVoltagesCell = [avgVoltagesCell; {' '}]; %#ok<AGROW> % Leere Zelle für Spannung

            for k = 1:length(avgArray)
                currentAvgArray = avgArray{k};
                
                % Füge die Daten hinzu
                currentsCell = arrayfun(@(x) sprintf(['%.', num2str(decimalI), 'f'], x), currentAvgArray(:, config.StromIndex), 'UniformOutput', false);
                voltagesCell = arrayfun(@(x) sprintf(['%.', num2str(decimalU), 'f'], x), currentAvgArray(:, config.SpannungsIndex), 'UniformOutput', false);
                
                triggerName = triggerNames{k};
                trig = cell(size(currentAvgArray, 1), 1);
                for m = 1:size(currentAvgArray, 1)
                    trig{m} = [triggerName, ' (', num2str(m), ')'];
                end
                
                avgCurrentsCell = [avgCurrentsCell; currentsCell]; %#ok<AGROW> 
                avgVoltagesCell = [avgVoltagesCell; voltagesCell]; %#ok<AGROW> 
                triggerNamesCell = [triggerNamesCell; trig]; %#ok<AGROW> 
            end
        end
        
        % Erstelle die Tabelle als Zelle
        numRows = length(avgCurrentsCell);
        tableData = cell(numRows, 3);  % Ohne Index-Spalte
        tableData(:, 1) = triggerNamesCell(:);
        tableData(:, 2) = avgCurrentsCell(:);
        tableData(:, 3) = avgVoltagesCell(:);
    
        % Aktualisiere die uitable mit den neuen Daten
        set(dataTable, 'Data', tableData);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Bearbeiten der Tabelle.')
        disp(ME.message)
    end
end

function valueArray = avgValues(data, indexArray, fig)
    % Berechnet den Mittelwert der Daten in einem bestimmten Bereich.
    %
    % Args:
    %    data (array): Array der Daten
    %    indexArray (array): Array der Indizes
    %    fig (figure): Das GUI-Fenster
    %
    % Returns:
    %    valueArray (array): Array der Mittelwerte
    try
        area = findobj(fig, 'Tag', 'defaultTime').Value * findobj(fig, 'Tag', 'defaultFactor').Value - 1;
        valueArray = arrayfun(@(idx) mean(data(idx - area:idx)), indexArray);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Berechnen der Durchschnitte einer Spalte.')
        disp(ME.message)
    end
end

function avgArray = allAvg(data, indexArray, fig)
    % Berechnet den Mittelwert aller Daten in einem bestimmten Bereich.
    %
    % Args:
    %    data (array): Array der Daten
    %    indexArray (array): Array der Indizes
    %    fig (figure): Das GUI-Fenster
    %
    % Returns:
    %    avgArray (array): Array der Mittelwerte
    try
        avgArray = cell(1, length(indexArray));
        for i = 1:length(indexArray)
            avgArraytt = arrayfun(@(col) avgValues(data(:, col), indexArray{i}, fig), 1:width(data), 'UniformOutput', false);
            avgArraytt = horzcat(avgArraytt{:});
            avgArray{i} = avgArraytt;
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Berechnen aller Durchschnitte.')
        disp(ME.message)
    end
end

function [dataArrays, fileNames] = DataWrapper()
    % Diese Funktion liest Daten aus ausgewählten Dateien ein.
    %
    % Args:
    %    columns (array): Array der auszuwertenden Spalten
    %
    % Returns:
    %    data (array): Eingelesene Daten
    try
        config = evalin("base", 'config');

        lines = processInf(config.Zeilen);
        columns = processInf(config.Spalten);
        
        % Standardpfad aus dem Base Workspace abrufen
        standardPath = evalin('base', 'standardPath');
        try
            % Verzeichnis zum Standardpfad wechseln
            oldFolder = cd(standardPath);
            % Datei-Auswahldialog für eine einzelne CSV-Datei öffnen
            [fileNames, filePath] = uigetfile('*.csv', 'Wählen Sie eine Datei zur Auswertung aus', 'MultiSelect', 'on');
            % Zurück zum ursprünglichen Verzeichnis wechseln
            cd(oldFolder);
            
        catch ME
            fig = evalin('base', 'fig');
            uialert(fig, [ME.message], 'Standardordner nicht gültig, bitte in der config anpassen.', 'Icon', 'warning');
            [fileNames, filePath] = uigetfile('*.csv', 'Wählen Sie eine Datei zur Auswertung aus', 'MultiSelect', 'on');
        end
    
        % Überprüfen, ob mindestens eine Datei ausgewählt wurde
        if isequal(fileNames, 0)
            disp('Keine Datei ausgewählt');
            return;
        end

        assignin("base",'standardPath', filePath)

        if ischar(fileNames)
            fileNames = {fileNames};
        end
        dataFiles = cell(length(fileNames), 1);
        for i = 1:length(fileNames)
            dataFiles{i} = fullfile(filePath, fileNames{i});
        end
        dataArrays = read_csv(dataFiles, lines, columns);
        
        % Daten in ein numerisches Array umwandeln
        try
            for i = 1:length(dataArrays)
                dataArrays{i} = cell2mat(dataArrays{i});
            end
        catch
            for i = 1:length(dataArrays)
                datetimeColumn = dataArrays{i}(:, 1);
                numericData = cell2mat(dataArrays{i}(:, 2:end));
                dataArrays{i} = [datetimeColumn, num2cell(numericData)];
            end
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Lesen der Daten.')
        disp(ME.message)
    end
end

function [indexArray, triggerNames] = findIndices(data)
    % Findet Indizes der letzten Werte mit Trigger
    %
    % Args:
    %    data (array): Array mit den Stromdaten
    %
    % Returns:
    %    indexArray (array): Array der Indizes der Stromabfälle
    try
        config = evalin("base", 'config');

        trigger = config.Trigger;
        triggerNames = config.TriggerNames;
        numRemoved = 0;
        for i = 1:length(trigger)
            test = find(data == trigger(i-numRemoved), 1);
            if isempty(test)
                trigger(i-numRemoved) = [];
                triggerNames(i-numRemoved) = [];
                numRemoved = numRemoved+1;
            end
        end
    
        indexArray = cell(1, length(trigger));
        % Find the last occurrence of each trigger value
        for i = 1:length(trigger)
            currentData = find(data == trigger(i));
            d = find(diff(currentData) ~=1);
            ttt = currentData(d); %#ok<FNDSB>
            ttt(end+1) = currentData(end); %#ok<AGROW> 
            indexArray{i} = ttt;
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Suchen der Indize.')
        disp(ME.message)
    end
end

function exportToxlsx(fig, headers, avgData, currData)
    % Diese Funktion exportiert die Daten in eine Excel-Datei.
    %
    % Args:
    %    headers (cell array): Header der Daten
    %    avgData (array): Durchschnittswerte der Daten
    %    currData (array): Aktuelle Werte der Daten
    try
        % Header in eine Zelle konvertieren, um sie in die Excel-Datei zu schreiben
        headers_cell = cellstr(headers)';
        
        % Header und Daten kombinieren
        longAvgData = avgData{1};
        if length(avgData) > 1
            for i = 2:length(avgData)
                longAvgData = [longAvgData; avgData{i}]; %#ok<AGROW> 
            end
        end
        longAvgData = sortrows(longAvgData, 1);
        combined_avg_data = [headers_cell; num2cell(longAvgData)];
        index = find(isnan(currData(:, 1)), 1, 'last');
        combined_curr_data = [headers_cell; num2cell(currData(index+1:end, :))]; 
        
        % Dateiauswahldialog öffnen, um Speicherort und Dateinamen auszuwählen
        [filename, pathname] = uiputfile('*.xlsx', 'Wählen Sie einen Speicherort und Dateinamen', 'Load Points-Export');
                
        % Fortschrittsdialog erstellen
        d = uiprogressdlg(fig, 'Title', 'Bitte warten', 'Message', 'Exportiere nach Excel');
        
        % Überprüfen, ob der Benutzer den Dialog abgebrochen hat
        if isequal(filename, 0) || isequal(pathname, 0)
            disp('Benutzer hat den Dateiauswahldialog abgebrochen');
        else
            if ~isequal(filename(end-4:end), '.xlsx')
                filename = [filename, '.xlsx'];
            end
            fullpath = fullfile(pathname, filename);
            
            d.Value = 0.1;
    
            % Beispiel-Excel-Datei aus dem Base Workspace holen
            exampleExcelPath = evalin('base', 'exampleExcelPath');
            
            % Überprüfen, ob die Zieldatei bereits existiert und umbenennen, falls geöffnet
            if exist(fullpath, 'file')
                [filepath, name, ext] = fileparts(fullpath);
                tempFilename = fullfile(filepath, [name '_temp' ext]);
                movefile(fullpath, tempFilename, "f"); % Datei umbenennen
            end
            
            d.Value = 0.2;
    
            % Beispiel-Excel-Datei in den gewünschten Ordner kopieren
            copyfile(exampleExcelPath, fullpath, "f");
    
            % Excel COM Server initialisieren
            Excel = actxserver('Excel.Application');
            Excel.Visible = false; % Excel nicht sichtbar machen
            try
                Workbook = Excel.Workbooks.Open(fullpath);
                
                % Daten in das Blatt 'Werte' schreiben
                sheet_avgValues = Workbook.Sheets.Item('Mittelwerte');
                sheet_avgValues.UsedRange.ClearContents();
                fprintf('Alte Daten auf dem Blatt "Mittelwerte" gelöscht.\n');
                
                d.Value = 0.3;
                writeDataToSheet(sheet_avgValues, combined_avg_data, d);
                
                % Daten in das Blatt 'Mittelwerte' schreiben
                sheet_values = Workbook.Sheets.Item('Werte');
                sheet_values.UsedRange.ClearContents();
                fprintf('Alte Daten auf dem Blatt "Werte" gelöscht.\n');
                
                d.Value = 0.5;
                writeDataToSheet(sheet_values, combined_curr_data, d);
                
                % Fortschrittsdialog abschließen
                d.Message = 'Speichern und Schließen der Datei...';
                d.Value = 1.0;
                delete(d);
    
                % Excel-Datei speichern und schließen
                Workbook.Save();
                Workbook.Close();
            catch ME
                % Im Fehlerfall Excel schließen und Fehler anzeigen
                Excel.Quit();
                delete(Excel);
                rethrow(ME);
            end
            Excel.Quit();
            delete(Excel);
    
            % Temporäre Datei löschen, wenn sie existiert
            if exist('tempFilename', 'var') && exist(tempFilename, 'file')
                delete(tempFilename);
            end
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Exportieren.')
        disp(ME.message)
    end
end

function writeDataToSheet(sheet, data, progressDialog)
    % Hilfsfunktion zum Schreiben von Daten in ein Excel-Blatt
    blockSize = 1000; % Anzahl der Zeilen pro Block
    numRows = size(data, 1);
    numCols = size(data, 2);
    fprintf('Gesamtanzahl der Zeilen: %d, Gesamtanzahl der Spalten: %d\n', numRows, numCols);
    val = progressDialog.Value;

    for startRow = 1:blockSize:numRows
        if progressDialog.CancelRequested
            break;
        end

        endRow = min(startRow + blockSize - 1, numRows);
        
        %progressDialog.Value = val + 0.15 * numRows / endRow;
        
        dataBlock = data(startRow:endRow, :);
        
        %progressDialog.Value = val + 0.15 * numRows / endRow;
        
        range = sprintf('A%d:%s%d', startRow, xlColLetter(numCols), endRow);
        fprintf('Schreibe Block: Startreihe: %d, Endreihe: %d, Bereich: %s\n', startRow, endRow, range);
        
        progressDialog.Value = val + 0.2 * blockSize / max(numRows, blockSize);
                        
        % Überprüfen, ob der Bereich korrekt ist
        try
            sheetRange = sheet.Range(range);
            sheetRange.Value = dataBlock;
        catch rangeError
            fprintf('Fehler bei der Bereichsangabe: %s\n', range);
            rethrow(rangeError);
        end                
        
%         progressDialog.Value = progressDialog.Value + 0.15 * numRows / endRow;
        progressDialog.Message = sprintf('Exportiere Zeilen %d bis %d von %d', startRow, endRow, numRows);
    end
end


function colLetter = xlColLetter(colNum)
    % Diese Funktion konvertiert eine Spaltennummer in den entsprechenden Excel-Spaltenbuchstaben
    try
        colLetter = '';
        while colNum > 0
            thisLetter = mod(colNum - 1, 26);
            colLetter = [char(thisLetter + 'A'), colLetter]; %#ok<AGROW> 
            colNum = floor((colNum - thisLetter - 1) / 26);
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Konvertieren der Spaltennummern in Buchstaben.')
        disp(ME.message)
    end
end

%% Helfer- und Dienstprogramme

function data = processInf(data)
    % Diese Funktion verarbeitet 'Inf' Werte in einem Zell-Array oder numerischen Array.
    %
    % Args:
    %    data (cell or array): Eingabedaten, die 'Inf' Werte enthalten können
    % 
    % Returns:
    %    data (array): Verarbeitete Daten ohne 'Inf' Werte
    try
        if iscell(data)
            for i = 1:numel(data)
                if ischar(data{i}) && strcmpi(data{i}, 'inf')
                    data{i} = Inf;
                elseif ischar(data{i})
                    % Entfernen von Anführungszeichen
                    data{i} = strrep(data{i}, '"', '');
                elseif isnumeric(data{i}) && isinf(data{i})
                    data{i} = Inf;
                end
            end
            
            % Konvertieren der Zelle in ein numerisches Array, falls möglich
            data = reshape(cell2mat(data), 1, 2);
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Verarbeiten von "Inf"-Eingaben.')
        disp(ME.message)
    end
end

function selectRow(src, event)
    try
        % Save the selected row index
        if ~isempty(event.Indices)
            selectedRows = unique(event.Indices(:, 1));
            setappdata(src, 'SelectedRows', selectedRows);
        end
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler beim Auswählen der Zeile')
    end
end