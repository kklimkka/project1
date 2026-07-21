%% Setup- und Initialisierungsfunktionen

function Leckage(referenceFolder)
    % Hauptfunktion, die den gesamten Ablauf steuert
    try
        %Abruf der config.json und vervollständigen des Pfades zum Referenzordner
        currentRef = referenceFolder;
        assignin("base", "currentRef", currentRef)
        configFile = fullfile(currentRef, 'config.json');
        fid = fopen(configFile, 'r');
        jsonData = fscanf(fid, '%c');
        fclose(fid);
        configData = jsondecode(jsonData);
        leckage_config = configData.Leckage;
        assignin("base", "config", leckage_config)
    
        referenceFolder = fullfile(referenceFolder, 'Leckage');
    
        % Zugriff auf 'fig' aus dem Base Workspace
        fig = evalin('base', 'fig');
        fig.Name = 'Leckage';
        
        % Setup von 'fig' mit Buttons, Standardwerten und Textfeldern
        delete(fig.Children);
        createBackButton(fig); 
        setupFigure(fig); 
        createFileSelectionFields(fig);
    
        % Definition der Standardwerte
        defaultRow = leckage_config.Zeilen{1};
        defaultCols = leckage_config.Spalten{1};
        checkRef = leckage_config.checkRef;
        checkDUT = leckage_config.checkDUT;
    
        createParameterFields(fig, defaultRow, defaultCols);  % Standardparameterfelder erstellen
        createEmptyTable(fig); % Tabelle erstellen
        createCheckboxes(fig, checkRef, checkDUT); % Checkboxes hinzufügen
        createConfigBtn(fig);
    
        % Einlesen der Referenzdaten
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
        assignin('base', 'referenceDataArray', referenceDataArray);
    
        % Hinzufügen der SizeChangedFcn, um die Größenänderung zu behandeln
        fig.SizeChangedFcn = @(src, event) resizeUIComponents(fig);
        fig.AutoResizeChildren = 'off';  % Deaktivieren der automatischen Größenanpassung
    
        % Initiale Größenanpassung auf aktuelle Fenstergröße
        resizeUIComponents(fig);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Öffnen des Leckage-Fensters.')
        disp(ME.message)
    end
end

function createConfigBtn(fig)
    try
        uibutton(fig, 'Text', 'Leckage config', 'Position', [fig.Position(3) - 150, fig.Position(4) - 32, 130, 22], ...
            'ButtonPushedFcn', @(btn, event) runMethodScript('Leckage'), 'Tag', 'configButton');
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
            fig = findall(0, 'Type', 'figure', 'Name', 'Leckage Einstellungen'); 

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
        leckage_config = configData.Leckage;
        assignin("base", "config", leckage_config)
        
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

function setupFigure(fig)
    % Hinzufügen eines Textbereichs zum Anzeigen von Informationen
    try
        uitextarea(fig, ...
            'Position', [20, fig.Position(4) / 2 - 70, (fig.Position(3) - 60)/2, fig.Position(4) / 2 + 55], ...
            'Value', ['Die Auswertungsmethode "Leckage" wurde ausgewählt:' newline ...
                  'Bitte "Leak_Check - logger 2" zur Auswertung nutzen' newline ...
                  '>> Zeile: Zeile der CSV, deren Daten ausgewertet werden sollen' newline ...
                  '>> Spalten: Spalten der CSV (A=1, B=2,... wie in Excel), deren Daten ausgewertet werden sollen (Bearbeitung in der Config ist sinnvoller)' newline ...
                  '>> Referenzdaten anzeigen: Falls diese Checkbox gewählt wird, werden die Referenzdaten im Plot angezeigt' newline ...
                  '>> DUT anzeigen: Falls diese Checkbox gewählt wird, werden die DUT-Daten im Plot angezeigt' newline ...
                  newline ...
                  'Erst "Neue Datei laden" dann "Plotten"' 
                  ], ...
            'Tag', 'infoText');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Infotextes.')
        disp(ME.message)
    end
end

function createFileSelectionFields(fig)
    % Diese Funktion erstellt die Dateiauswahlliste
    try
        load_data_btn_width = 200;
        load_data_btn_height = 50;
        load_data_btn_x = (fig.Position(3) / 2) - load_data_btn_width - 120;
        load_data_btn_y = 10;
        margin = 20;
    
         % Dateiauswahlliste hinzufügen
        uitextarea(fig, "Value",'Dateiauswahl:', 'Position', [fig.Position(3)/2 + 0.5 * margin, fig.Position(4) - 37, 120, 27], 'FontSize', 17.5, ...
            'Tag', 'fileListLabel', 'Editable', 'off', 'BackgroundColor', fig.Color);
        uilistbox(fig, 'Position', [fig.Position(3)/2 + 0.5 * margin, 250, fig.Position(3)/2 - 30, fig.Position(4) - 285], 'Tag', 'fileList', ...
            'Multiselect', 'on', 'Items', {});
    
        % Datei-Button hinzufügen
        uibutton(fig, 'push', 'Text', 'Neue Datei laden', 'Position', [load_data_btn_x, load_data_btn_y, load_data_btn_width, load_data_btn_height], ...
            'ButtonPushedFcn', @(btn, event) addFiles(fig), 'Tag', 'Neue Dateien');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Dateiauswahlfensters.')
        disp(ME.message)
    end
end

function addFiles(fig)
    % Funktion zum Hinzufügen von Dateien zur Liste
    try
        [data, fileNames] = selectAndReadData(fig);
        if isempty(data)
            return
        end

        fileList = findobj(fig, 'Tag', 'fileList');
    
        try
            for i = 1:length(fileNames)
                addFileToList(fileList, fileNames{i}, data{i}, length(fileList.Items) + 1)
            end
        catch ME
            error('Error reading data files: %s', ME.message);
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
    try
        % Helper function to add a single file to the list at a specific position
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

function createParameterFields(fig, defaultRow, defaultCols)
    try
        figWidth = fig.Position(3);
        
        % Parameter
        plot_btn_width = 200;
        plot_btn_height = 50;
        plot_btn_x = (figWidth / 2) - plot_btn_width - 120;
    
        % Eingabefelder hinzufügen um die Zeile und Spalten anpassen zu können
        % Zeile:
        uilabel(fig, 'Position', [plot_btn_x, 115, 50, 22], 'Text', 'Zeile:', 'Tag', 'rowInputLabel'); 
        uieditfield(fig, 'text', 'Position', [plot_btn_x + 50, 115, 370, 22], 'Value', defaultRow, 'Tag', 'rowInput');
    
        % Spalten:
        uilabel(fig, 'Position', [plot_btn_x, 75, 50, 22], 'Text', 'Spalten:', 'Tag', 'colInputsLabel');
        uieditfield(fig, 'text', 'Position', [plot_btn_x + 50, 75, 370, 22], 'Value', defaultCols, 'Tag', 'colInputs');

        % DUT Bezeichnung:
        uilabel(fig, 'Position', [495, 75, 125, 22], 'Text', 'Bezeichnung der DUT:', 'Tag', 'NameOfDUTLabel');
        uieditfield(fig, 'text', 'Position', [495 + 125, 75, 150, 22], 'Value', 'DUT', 'Tag', 'NameOfDUT');
    
        % Plot Button
        uibutton(fig, 'push', ...
            'Text', 'Plotten', ...
            'Position', [plot_btn_x, 15, plot_btn_width, plot_btn_height], ...
            'ButtonPushedFcn', @(btn, event) plotDataWrapper(fig), ...
            'Tag', 'plotButton'); 
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen der Parameterfelder.')
        disp(ME.message)
    end
end

function createEmptyTable(fig)
    % Initiale leere Tabelle unter dem Textfeld erstellen
    try
        % Daten für die leere Tabelle
        data = cell(2, 2); % Leere Zellen für initiale Anzeige
        
        % Spaltennamen
        columnName = {'Extern (mbar/min)', 'Intern (mbar/min)'};
        
        % Tabellen-Position
        tablePosition = [20, fig.Position(4) / 2 - 159.334, fig.Position(3) - 40, 74.334];
        
        % Erstellen der Tabelle
        uitable(fig, ...
            'Data', data, ...
            'ColumnName', columnName, ...
            'Position', tablePosition, ...
            'Tag', 'resultTable', ...
            'RowName', {'Anode', 'Kathode'}); % Zeilennamen
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen der Tabelle.')
        disp(ME.message)
    end
end

function createCheckboxes(fig, checkRef, checkDUT)
    try
        % Position und Größe der Checkboxes
        checkbox_width = 150;
        checkbox_height = 22;
    
        % Checkbox für Referenzdaten
        uicheckbox(fig, ...
            'Text', 'Referenzdaten anzeigen', ...
            'Value', checkRef, ...
            'Position', [(fig.Position(3) / 2) + 120, 115, checkbox_width, checkbox_height], ...
            'Tag', 'referenceCheckbox');
    
        % Checkbox für DUT
        uicheckbox(fig, ...
            'Text', 'DUT anzeigen', ...
            'Value', checkDUT, ...
            'Position', [(fig.Position(3) / 2) + 280, 115, checkbox_width, checkbox_height], ...
            'Tag', 'dutCheckbox');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen der Checkboxen.')
        disp(ME.message)
    end
end

function createBackButton(fig)
    try
        % Zurück-Button Position
        back_btn_width = 200;
        back_btn_height = 50;
        back_btn_x = (fig.Position(3) / 2) - back_btn_width / 2;
    
        % Erstelle den Zurück-Button
        uibutton(fig, 'push', ...
            'Text', 'Zurück zur Auswahl', ...
            'Position', [back_btn_x, 15, back_btn_width, back_btn_height], ...
            'ButtonPushedFcn', @(btn, event) backToSelection(fig), ...
            'Tag', 'backButton');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Zurück-Buttons.')
        disp(ME.message)
    end
end

%% Event-Handler und Callback-Funktionen

function backToSelection(fig)
    try
        % unnötige Informationen aus Base Workspace löschen
        if evalin('base', 'exist("referenceDataArray", "var")') == 1 
            % Variable existiert, daher können wir sie löschen
            evalin('base', 'clear referenceDataArray');
        end
        evalin("base", 'clear config')
        evalin('base', 'clear referenceFolder');
        evalin('base', 'clear fig');
        % Rufe die Auswahlfunktion auf und übergebe das aktuelle Fenster
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

function resizeUIComponents(fig)
    % Diese Funktion passt die Größe und Position der UI-Elemente an, wenn die Fenstergröße geändert wird.
    try
        % Berechnung der Fenstergröße
        windowWidth = fig.Position(3);
        windowHeight = fig.Position(4);
    
        % Berechnung der Skalierungsfaktoren
        widthScaleFactor = windowWidth / 900;
        heightScaleFactor = windowHeight / 625;
        margin = 20 * widthScaleFactor;
        height = 22 * heightScaleFactor;
    
        % Infotext
        resizeComponent(fig, 'infoText',            [margin,                    240 * heightScaleFactor,    420 * widthScaleFactor,     375 * heightScaleFactor])
        resizeComponent(fig, 'fileListLabel',       [460 * widthScaleFactor,    588 * heightScaleFactor,    120 * widthScaleFactor,      27 * heightScaleFactor])
        resizeComponent(fig, 'fileList',            [460 * widthScaleFactor,    240 * heightScaleFactor,    420 * widthScaleFactor,     350 * heightScaleFactor])
        resizeComponent(fig, 'configButton',        [750 * widthScaleFactor,    593 * heightScaleFactor,    130 * widthScaleFactor,     height])
    
        % Parameterfelder
        resizeComponent(fig, 'rowInputLabel',       [130 * widthScaleFactor,    105 * heightScaleFactor,     50 * widthScaleFactor,     height])
        resizeComponent(fig, 'rowInput',            [180 * widthScaleFactor,    105 * heightScaleFactor,    295 * widthScaleFactor,     height])
        resizeComponent(fig, 'colInputsLabel',      [130 * widthScaleFactor,     75 * heightScaleFactor,     50 * widthScaleFactor,     height])
        resizeComponent(fig, 'colInputs',           [180 * widthScaleFactor,     75 * heightScaleFactor,    295 * widthScaleFactor,     height])
        resizeComponent(fig, 'NameOfDUTLabel',      [495 * widthScaleFactor,     75 * heightScaleFactor,    125 * widthScaleFactor,     height])
        resizeComponent(fig, 'NameOfDUT',           [620 * widthScaleFactor,     75 * heightScaleFactor,    150 * widthScaleFactor,     height])
    
        % Tabelle
        resizeComponent(fig, 'resultTable',         [margin,                    142.5*heightScaleFactor,    860 * widthScaleFactor,     74.34])
    
        % Checkboxen
        resizeComponent(fig, 'referenceCheckbox',   [495 * widthScaleFactor,    105 * heightScaleFactor,    150 * widthScaleFactor,     height])
        resizeComponent(fig, 'dutCheckbox',         [675 * widthScaleFactor,    105 * heightScaleFactor,    100 * widthScaleFactor,     height])
    
        % Buttons
        btn_y = 10 * heightScaleFactor;
        btn_width = 200 * widthScaleFactor;
        btn_height = 50 * heightScaleFactor;

        resizeComponent(fig, 'Neue Dateien',        [130 * widthScaleFactor,    btn_y,                      btn_width,                  btn_height]);
        resizeComponent(fig, 'plotButton',          [350 * widthScaleFactor,    btn_y,                      btn_width,                  btn_height]);
        resizeComponent(fig, 'backButton',          [570 * widthScaleFactor,    btn_y,                      btn_width,                  btn_height]);
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

%% Datenverarbeitungsfunktionen

function plotDataWrapper(fig)
    % Wrapper-Funktion, die aufgerufen wird, wenn der Plot-Button gedrückt wird
    try
        % Prüfe den Zustand der Checkboxes
        useReference = findobj(fig, 'Tag', 'referenceCheckbox').Value;
        useDUT = findobj(fig, 'Tag', 'dutCheckbox').Value;

        if ~useReference && ~useDUT
            return;
        end

        d = uiprogressdlg(fig,'Title','Bitte Warten',...
            'Message','Plot wird erstellt');
    
        % Initialisiere Variablen für DUT-Daten
        allDutExternalAnode = [];
        allDutExternalCathode = [];
        allDutInternalAnode = [];
        allDutInternalCathode = [];
        
        % 1. Daten einlesen, wenn DUT aktiviert ist
        if useDUT
            fileList = findobj(fig, 'Tag', 'fileList');
    
            data = fileList.Value;
            if isempty(data)
                try
                    data = fileList.ItemsData;
                    if isempty(data)
                        uialert(fig, 'Bitte mindestens eine Datei laden.', 'Warnung', 'Icon', 'warning')
                        return
                    end
                catch
                    uialert(fig, 'Bitte mindestens eine Datei laden.', 'Warnung', 'Icon', 'warning')
                    return
                end
            end
            
            % Wenn keine Daten eingelesen wurden, beenden
            if isempty(data)
                return;
            end

            % Indize der Daten in der Liste ermitteln
            indexArray = NaN(1, length(data));
            for i = 1:length(data)
                file = data(i);
                indexArray(i) = find(cellfun(@(x) isequal(x, file{1}), fileList.ItemsData)) + 1;
            end
        
            d.Value = 0.2;
        
            % Reihenfolge der Daten ermitteln
            [~, order] = sort(indexArray);
            % Daten umsortieren
            data = data(order);
    
            d.Value = 0.1;
            
            for i = 1:length(data)     % Schleife um alle Dateien abzudecken
                % 3. Leckage berechnen
                [dutExternalAnode, dutExternalCathode, dutInternalAnode, dutInternalCathode] = calculateLeakage(data{i});
                
                % 4. Ergebnisse anzeigen
                displayResults(fig, dutExternalAnode, dutExternalCathode, dutInternalAnode, dutInternalCathode);
        
                % Speichere die Ergebnisse
                allDutExternalAnode(end+1) = dutExternalAnode; %#ok<*AGROW> 
                allDutExternalCathode(end+1) = dutExternalCathode;
                allDutInternalAnode(end+1) = dutInternalAnode;
                allDutInternalCathode(end+1) = dutInternalCathode;
            end
        end
    
        d.Value = 0.2;
    
        % 5. Referenzdaten auswerten und plotten
        plotLeakageData(fig, allDutExternalAnode, allDutExternalCathode, allDutInternalAnode, allDutInternalCathode, useDUT, useReference, d);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Laden oder Plotten der Daten.')
        disp(ME.message)
    end
end

function plotLeakageData(fig, dutExternalAnode, dutExternalCathode, dutInternalAnode, dutInternalCathode, useDUT, useReference, d)
    % Funktion zur Auswertung der Referenzdaten und zum Erstellen des Plots
    try
        % Initialisiere Arrays für die Leckraten
        refExternalAnode = [];
        refExternalCathode = [];
        refInternalAnode = [];
        refInternalCathode = [];
        refNames = {};
        lengthDUT = 0;
        NameOfDUT = findobj(fig, 'Tag', 'NameOfDUT').Value;
        
        if useReference
            % Lese alle CSV-Dateien im Referenzordner
            referenceDataArray = evalin('base', 'referenceDataArray');
            for i = 1:length(referenceDataArray)     % Schleife um alle Dateien abzudecken
                d.Value = 0.3;
                try
                    % Daten einlesen
                    data = referenceDataArray{i};
    
                    % Berechne die Leckraten
                    [externalAnode, externalCathode, internalAnode, internalCathode] = calculateLeakage(data);
                
                    % Speichere die Ergebnisse
                    refExternalAnode(end+1) = externalAnode; 
                    refExternalCathode(end+1) = externalCathode; 
                    refInternalAnode(end+1) = internalAnode;
                    refInternalCathode(end+1) = internalCathode; 
                    refNames{end+1} = ['Ref#', num2str(i)];
    
                catch ME
                    % Fehlerbehandlung und Ausgabe im Textfeld
                    infoText = findobj(fig, 'Tag', 'infoText');
                    infoText.Value = [
                        infoText.Value;
                        ' ';
                        ['Fehler bei der Auswertung der Datei ', files(i).name, ': ', ME.message]
                    ];
                end
            end
        end
    
        d.Value = 0.4;
    
        % Füge die DUT-Daten hinzu, wenn DUT aktiviert ist
        if useDUT
            refExternalAnode = [refExternalAnode, dutExternalAnode];
            refExternalCathode = [refExternalCathode, dutExternalCathode];
            refInternalAnode = [refInternalAnode, dutInternalAnode];
            refInternalCathode = [refInternalCathode, dutInternalCathode];
            
            lengthDUT = length(dutExternalAnode);
    
            d.Value = 0.5;
    
            if lengthDUT > 1
                for i = 1:lengthDUT
                    refNames{end+1} = ['Zelle #', num2str(i)];
                end
            else
                refNames{end+1} = NameOfDUT;
            end
        end
    
        d.Value = 0.6;
        
        if ~isempty(refExternalAnode)
            % Erstelle den Balkenplot für externe Leckage
            createLeakagePlot(refExternalAnode, refExternalCathode, refNames, 'Externe Leckage', useDUT, useReference, lengthDUT);
        
            d.Value = 0.8;
        
            % Erstelle den Balkenplot für interne Leckage
            createLeakagePlot(refInternalAnode, refInternalCathode, refNames, 'Interne Leckage', useDUT, useReference, lengthDUT);
        else
            if ~exist("fig") %#ok<EXIST> 
                fig = uifigure();
            end
            uialert(fig, "Keine Referenz-/DUT-Datei gefunden" , 'Fehler beim Erstellen des Plots.')
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

function createLeakagePlot(anodeData, cathodeData, labels, titleText, useDUT, useReference, lengthDUT)
    % Funktion zur Erstellung des Leckage-Plots
    try
        % config laden
        config = evalin("base", 'config');
        yLim = config.yAchsenLimits;
        barTextSize = config.barTextSize;
        
        % Initialisierung der Figur
        figure('Name', titleText, 'NumberTitle', 'off', 'Units', 'normalized', 'OuterPosition', [0 0.05 1 0.95]);
        hold on;
        numSteps = 1000; % Anzahl der Schritte im Farbverlauf
        
        if useDUT && useReference 
            grey = [0.7, 0.7, 0.7];
            x = [0.5, 0.5, (length(anodeData) - lengthDUT)*2 + 0.5, (length(anodeData) - lengthDUT)*2 + 0.5];
            y = [-2, 6, 6, -2];
            % Erstellen eines halbtransparenten Rechtecks mit fill-Funktion
            fill(x, y, grey, 'FaceAlpha', 0.5, 'EdgeColor', 'none', 'HandleVisibility', 'off')
        end
    
        % Erstellen der Balken mit Farbverlauf
        for i = 1:length(anodeData)
            % Anode Balken rot
            createGradientBar(i*2-1, anodeData(i), [192/255, 0, 0], numSteps);
            % Kathode Balken in #0070C0
            createGradientBar(i*2, cathodeData(i), [0, 112/255, 192/255], numSteps);
            
            % Text hinzufügen
            addBarText(i*2-1, anodeData(i), barTextSize);
            addBarText(i*2, cathodeData(i), barTextSize);
        end
        hold off;
        
        % Achsenbeschriftungen und Titel für Leckage
        set(gca, 'XTick', 1.5:2:length(labels)*2, 'XTickLabel', labels);
        ax = gca;
        ax.XAxis.FontSize = config.xTickSize;
        ax.YAxis.FontSize = config.yTickSize;
        ylabel(config.ylabel, 'FontWeight', 'bold');
        xlabel(config.xlabel, 'FontWeight', 'bold');
        t = title(titleText);
        t.FontSize = config.titleFontSize;
        ylim(yLim);
        yline(config.Grenzwert, '-', 'Color', [1, 0.5, 0], 'Alpha', 0.5, 'LineWidth', 2, 'HandleVisibility', 'off'); % Halbtransparente Grenzwertlinie bei y = config.Grenzwert
        
        % Legende und Gitter basierend auf den aktivierten Optionen
        x = length(anodeData);
        xlim([0.5, 2 * x + 0.5]); 
        l = legend({'Anode', 'Kathode'});
        l.FontSize = config.legendFontSize;
        grid on; % Gitter aktivieren
        set(gca, 'XGrid', 'off', 'YGrid', 'on', 'GridAlpha', 0.2); % Nur Y-Gitterlinien
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Plots.')
        disp(ME.message)
    end
end

function [externalAnode, externalCathode, internalAnode, internalCathode] = calculateLeakage(data)
    % Prüfe, ob data eine Zelle ist und konvertiere sie in numerische Werte
    try
        if iscell(data)
            data = cellfun(@convertToNumeric, data);
        end
        
        % Berechnung der Leckage-Werte
        factor = 100; % Konstante für die Berechnung
        externalAnode = (data(1) - data(3)) * factor;  
        externalCathode = (data(2) - data(4)) * factor;  
        internalAnode = (data(5) - data(7)) * factor;  
        internalCathode = (data(6) - data(8)) * factor; 
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Berechnen der Leckage.')
        disp(ME.message)
    end 
end

%% Helfer- und Dienstprogramme

function createGradientBar(x, height, color, numSteps)
    % Diese Funktion erstellt einen Balken mit Farbverlauf
    try
        y = linspace(0, height, numSteps)'; % y-Koordinaten
        xCoords = [x-0.4, x+0.4]; % x-Koordinaten für den Balken
        
        % Erzeugen der Farbwerte und Transparenzwerte
        c = repmat(reshape(color, 1, 1, 3), numSteps, 2); % Farbe für jeden Schritt
        alphaValues = linspace(1, 0.01, numSteps)'; % Transparenz von 100% bis 1%
        
        % Erstellen der Matrizen für das surface-Objekt
        [X, Y] = meshgrid(xCoords, y);
        Z = zeros(size(X)); % Z-Koordinaten für 2D-Darstellung
        A = repmat(alphaValues, 1, 2); % Transparenz für jeden Punkt auf der Oberfläche
        
        % Erstellen des surface-Objekts
        surface(X, Y, Z, c, 'FaceColor', 'interp', 'EdgeColor', 'none', ...
            'FaceAlpha', 'interp', 'AlphaData', A, 'AlphaDataMapping', 'none');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen der Balken.')
        disp(ME.message)
    end
end

function addBarText(x, value, barTextSize)
    % Diese Funktion fügt Text zu einem Balken hinzu
    try
        if value < 0
            alignment = 'top';
        else
            alignment = 'bottom';
        end
        
        % config laden
        config = evalin("base", 'config');
        
        % Nachkommastellenzahl für Balkentext anpassen
        decimal = config.NachkommastellenPlot;
        formatString = sprintf('%%.%df', decimal);
    
        % Balkengröße beschriften
        t = text(x, value, strrep(sprintf(formatString, value), '.', ','), 'VerticalAlignment', alignment, 'Color', 'k', 'FontWeight', 'bold');
        t.FontSize = barTextSize;
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Hinzufügen der Werte.')
        disp(ME.message)
    end
end

function [rowInput, colIndices] = dataLocations(fig)
    % Extraktion der relevanten Daten aus der angegebenen Zeile und Spalten 
    try
        leckage_config = evalin("base", 'config');
        % Standardwerte für Zeile und Spalten
        defaultRow = leckage_config.Zeilen{1};
        defaultCols = strsplit(char(leckage_config.Spalten{1}), ',');
    
        % Einlesen der Zeilen- und Spaltenwerte aus der GUI
        rowInput = str2double(findobj(fig, 'Tag', 'rowInput').Value);
        colInputs = strsplit(char(findobj(fig, 'Tag', 'colInputs').Value), ',');
        
        % Verwenden der Standardwerte, falls keine Eingabe vorhanden
        if isnan(rowInput) || rowInput <= 0, rowInput = defaultRow; end
        if isequal(rowInput, 'Standard: letzte Zeile (sonst Zeilennummer angeben)')
            rowInput = 'last';
        end
        if isempty(colInputs{1}), colInputs = defaultCols; end
        
        % Konvertieren der Excel-Buchstaben in numerische Indizes
        colIndices = cellfun(@colLetterToIndex, colInputs);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erkennen der Spalten und Zeilen.')
        disp(ME.message)
    end
end

function num = convertToNumeric(cellVal)
    % Versucht, den Zellinhalt in eine Zahl zu konvertieren
    try
        if ischar(cellVal)
            num = str2double(cellVal);
        elseif isnumeric(cellVal)
            num = cellVal;
        elseif iscell(cellVal) && ~isempty(cellVal)
            num = str2double(char(cellVal));
        else
            num = NaN;
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Konvertieren der Daten in Zahlen.')
        disp(ME.message)
    end
end

function index = colLetterToIndex(letter)
    % Konvertiert Excel-Spaltenbuchstaben in numerische Indizes
    try
        index = sum((double(upper(letter)) - 64) .* (26.^(numel(letter)-1:-1:0)));
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Konvertieren der Excel-Spaltenbuchstaben in numerische Indizes.')
        disp(ME.message)
    end
end

%% Eingabe-/Ausgabefunktionen

function displayResults(fig, externalAnode, externalCathode, internalAnode, internalCathode)
    % Anzeige der Ergebnisse in der GUI als Tabelle
    try
        % config laden
        config = evalin("base", 'config');
        decimal = config.NachkommastellenTabelle;
        formatString = sprintf('%%.%df', decimal);
    
        % Daten für die Tabelle
        data = {...
            strrep(sprintf(formatString, externalAnode), '.', ','), strrep(sprintf(formatString, internalAnode), '.', ','); ...
            strrep(sprintf(formatString, externalCathode), '.', ','), strrep(sprintf(formatString, internalCathode), '.', ',') ...
        };
        
        % Erhalte das Tabellenobjekt
        resultTable = findobj(fig, 'Tag', 'resultTable');
        
        % Aktualisiere die Tabelle mit den neuen Daten
        resultTable.Data = data;
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Ausgeben der Ergebnisse.')
        disp(ME.message)
    end
end

function [dataArrays, fileNames] = selectAndReadData(fig)
    % Auswahl und Einlesen der Daten aus der CSV-Datei
    try
        standardPath = evalin('base', 'standardPath');
        try
            oldFolder = cd(standardPath);
            [fileNames, filePath] = uigetfile('*.csv', 'Wählen Sie eine Datei zur Auswertung aus', 'MultiSelect', 'on');
            cd(oldFolder);
        catch ME
            fig = evalin('base', 'fig');
            uialert(fig, [ME.message], 'Standardordner nicht gültig, bitte in der config anpassen.', 'Icon', 'warning');
            [fileNames, filePath] = uigetfile('*.csv', 'Wählen Sie eine Datei zur Auswertung aus', 'MultiSelect', 'on');
        end
    
        if isequal(fileNames, 0)
            disp('Keine Datei ausgewählt');
            dataArrays = {};
            return;
        end
        
        assignin("base",'standardPath', filePath)

        if ischar(fileNames)
            fileNames = {fileNames};
        end
        [rowInput, colIndices] = dataLocations(fig);
        dataFiles = cell(length(fileNames), 1);
        for i = 1:length(fileNames)
            dataFiles{i} = fullfile(filePath, fileNames{i});
        end
        dataArrays = read_csv(dataFiles, rowInput, colIndices);
        for i = 1:length(dataArrays)
            dataArrays{i} = cellfun(@convertToNumeric, dataArrays{i}); % Konvertiere die Daten in numerische Werte
        end
        disp('Daten erfolgreich eingelesen.');
    
        % Debugging-Informationen im Textfeld anzeigen
        infoText = findobj(fig, 'Tag', 'infoText');
        % Überprüfen, ob Daten erfolgreich eingelesen wurden
        if length(dataArrays) == 1
            % Debugging-Informationen über die extrahierten Daten anzeigen
            dataStr = sprintf('%f, ', dataArrays{i}); % Konvertiere das Array zu einer Zeichenkette
            dataStr = dataStr(1:end-2); % Entferne das letzte Komma
            infoText.Value = [
                infoText.Value;
                ' ';
                'DUT-Daten:';
                strrep(dataStr, '.', ',') % Dezimaltrennzeichen ändern
            ];
        else
            for i = 1:length(dataArrays)
                % Debugging-Informationen über die extrahierten Daten anzeigen
                dataStr = sprintf('%f, ', dataArrays{i}); % Konvertiere das Array zu einer Zeichenkette
                dataStr = dataStr(1:end-2); % Entferne das letzte Komma
                infoText.Value = [
                    infoText.Value;
                    ' ';
                    ['DUT #', num2str(i), '-Daten:'];
                    strrep(dataStr, '.', ',') % Dezimaltrennzeichen ändern
                ];
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