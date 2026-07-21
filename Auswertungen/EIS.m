function EIS(referenceFolder)
    % Hauptfunktion, die den gesamten Ablauf steuert
    try
        % Abruf der config.json und vervollständigen des Pfades zum Referenzordner
        currentRef = referenceFolder;
        assignin("base", "currentRef", currentRef);
        
        % Error handling für file operations
        configFile = fullfile(currentRef, 'config.json');
        fid = fopen(configFile, 'r');
        jsonData = fscanf(fid, '%c');
        fclose(fid);
        configData = jsondecode(jsonData);
        eis_config = configData.EIS;
        assignin("base", "config", eis_config);
        
        % Zugriff auf das bisherige Auswahlfenster aus dem Base Workspace
        fig = evalin('base', 'fig'); 
        fig.Name = 'EIS';
        
        % Setup des Fensters mit Buttons, Dateiauswahlliste und Textfeldern
        delete(fig.Children);
        createBackButton(fig); 
        createFileSelectionFields(fig); % Definition der Dateiauswahl und Buttons
    
        % Hinzufügen der SizeChangedFcn, um die Größenänderung zu behandeln
        fig.SizeChangedFcn = @(src, event) resizeUIComponents(fig);
        fig.AutoResizeChildren = 'off';  % Deaktivieren der automatischen Größenanpassung
    
        % Initiale Größenanpassung auf aktuelle Fenstergröße
        resizeUIComponents(fig);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Öffnen des EIS-Fensters.')
        disp(ME.message)
    end
end

function createFileSelectionFields(fig)
    % Diese Funktion erstellt die Dateiauswahlliste und Buttons für die GUI.
    try
        % config laden
        config = evalin("base", 'config');
        showSigma = config.sigmaAnzeigen;
        defaultTitle = config.Titel;
        area = config.Flaeche;
        numColumns = config.SplatenInPlotlegende;
    
        % Dateiauswahlliste hinzufügen
        uitextarea(fig, "Value",'Dateiauswahl:', 'Position', [20, fig.Position(4) - 37, 120, 27], 'FontSize', 17.5, ...
            'Tag', 'fileListLabel', 'Editable', 'off', 'BackgroundColor', fig.Color);
        uilistbox(fig, 'Position', [20, 110, 415, fig.Position(4) - 145], 'Tag', 'fileList', 'Multiselect', 'on', 'Items', {}); %fileList = 
        
        % Hinzufügen des WindowButtonDownFcn-Callbacks
%         fig.WindowButtonDownFcn = @(src, event) onRefListDoubleClick(src, fileList);

        % Buttons für Dateiverwaltung hinzufügen
        uibutton(fig, 'Text', 'Neue Dateien', 'Position', [20, 70, 100, 30], 'ButtonPushedFcn', @(btn, event) addFiles(fig), 'Tag' , 'Neue Dateien');
        uibutton(fig, 'Text', 'Alle wählen', 'Position', [125, 70, 100, 30], 'ButtonPushedFcn', @(btn, event) selectAllFiles(fig), 'Tag' , 'Alle wählen');
        uibutton(fig, 'Text', 'Alle abwählen', 'Position', [230, 70, 100, 30], 'ButtonPushedFcn', @(btn, event) deselectAllFiles(fig), 'Tag' , 'Alle abwählen');
        uibutton(fig, 'Text', 'Löschen', 'Position', [335, 70, 100, 30], 'ButtonPushedFcn', @(btn, event) clearSelectedFiles(fig), 'Tag' , 'Löschen');
        
        % Plot Buttons hinzufügen
        uibutton(fig, 'push', 'Text', 'Plot -Nyquist', 'Position', [fig.Position(3)/2 - 320, 10, 200, 50], 'ButtonPushedFcn', @(btn, event) nyquistPlotSelectedFiles(fig), ...
            'Tag', 'Plot -Nyquist');
        uibutton(fig, 'push', 'Text', 'Plot Bode', 'Position', [fig.Position(3)/2 - 100, 10, 200, 50], 'ButtonPushedFcn', @(btn, event) bodePlotSelectedFiles(fig), ...
            'Tag', 'Plot Bode');
        
        % Button zum Hinzufügen der Durchschnittsdatei
        uibutton(fig, 'push', 'Text', 'Mittelwert & σ berechnen', 'Tag', 'Mittelwert berechnen', 'Position', [440, 530, 200, 30], ...
            'ButtonPushedFcn', @(btn, event) addAverageAndSigmaFile(fig));
        uibutton(fig, 'push', 'Text', 'MW&σ Dateien wählen', 'Tag', 'MW&σ wählen', 'Position', [650, 530, 200, 30], ...
            'ButtonPushedFcn', @(btn, event) selectAllMWAndSigmaFiles(fig));
        uibutton(fig, 'push', 'Text', 'Datei umbenennen', 'Tag', 'Datei umbenennen', 'Position', [440, 495, 440, 30], ...
            'ButtonPushedFcn', @(btn, event) renameFile(fig));
        uibutton(fig, 'push', 'Text', 'Als Referenz markieren', 'Tag', 'Referenz on', 'Position', [440, 460, 200, 30], ...
            'ButtonPushedFcn', @(btn, event) addReference(fig));
        uibutton(fig, 'push', 'Text', 'Referenzmarkierung auflösen', 'Tag', 'Referenz off', 'Position', [650, 460, 200, 30], ...
            'ButtonPushedFcn', @(btn, event) removeReference(fig));

        % Andere Buttons hinzufügen
        uibutton(fig, 'Text', 'EIS config', 'Position', [305, fig.Position(4) - 32, 130, 22], 'ButtonPushedFcn', @(btn, event) runMethodScript('EIS'), 'Tag', 'configButton');
        uibutton(fig, 'Text', 'Exportieren', 'Position', [160, fig.Position(4) - 32, 130, 22], 'ButtonPushedFcn', @(btn, event) txtExport(fig), 'Tag', 'exportieren');
    
        % Titel
        uilabel(fig, 'Position', [440, fig.Position(4) - 32, 26, 22], 'Text', 'Titel:', 'Tag', 'titleLabel'); 
        uieditfield(fig, 'text', 'Position', [470, fig.Position(4) - 32, 264, 22], 'Value', defaultTitle{1}, 'Tag', 'title');
    
        % Parameter
        uilabel(fig, 'Position', [745, fig.Position(4) - 32, 80, 22], 'Text', 'Aktive Fläche:', 'Tag', 'areaLabel'); 
        uispinner(fig, "Value", area, 'Position', [825, fig.Position(4) - 32, 55, 22], 'Tag', 'area', 'ValueChangedFcn', @(src, event) areaWarning(fig), ...
            'RoundFractionalValues', 'off', 'Limits', [0, Inf], 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');

        uilabel(fig, 'Position', [440, fig.Position(4) - 60, 145, 22], 'Text', 'Spalten in der Plotlegende:', 'Tag', 'numColumnsLabel'); 
        uispinner(fig, 'Position', [590, fig.Position(4) - 60, 50, 22], "Value", numColumns, 'Tag', 'numColumns', "Limits", [0, inf], 'RoundFractionalValues', 'on');

        uicheckbox(fig, 'Text', 'σ anzeigen', 'Tag', 'showSigma', 'Position', [650, fig.Position(4) - 60, 85, 30], 'Value', showSigma);
        uicheckbox(fig, 'Text', 'Dateinamen kürzen', 'Tag', 'shortenNames', 'Position', [750, fig.Position(4) - 60, 85, 30], 'Value', 1);

        % Infotext
        uitextarea(fig, ...
            'Position', [440, 70, 440, 300], ...
            'Value', ['Die Auswertungsmethode "EIS" wurde ausgewählt:' newline ...
                  '>> Titel: Titelanpassung (^{Text} für hochgestellten Text und _{Text} für tiefgestellten Text => [\{, \} und \\ um {, } und \ zu schreiben])' newline ...
                  '>> Aktive Fläche: für die Berechnung der Flächenbezogenen Impedanz (-Nyquist)' newline ...
                  '>> Spalten in der Plotlegende: Anzahl der Spalten, die für die Legende genutzt werden (Die dargestellte Dateianzahl sollte ein vielfaches sein, damit in jeder Zeile gleich viele Namen stehen)' newline ...
                  '>> σ anzeigen: Zeigt im Plot die Standardabweichung als Fehlerkreuz' newline ...
                  '>> Dateinamen kürzen: Kürzt die Namen der Dateien beim Laden' newline ...
                  '>> Mittelwert & σ berechnen: Erstellt eine Datei mit dem MW und der Standardabweichung der gewählten Dateien' newline ...
                  '>> MW&σ Dateien wählen: Wählt alle per "Mittelwert & σ berechnen" erstellten Dateien aus' newline ...
                  '>> Datei umbenennen: Ermöglicht die Umbenennung der gewählten Datei' newline ...
                  '>> Als Referenz markieren: Markierte Dateien werden ausgegraut und dicker geplottet' newline ...
                  '>> Exportieren: Exportiert die gewählten Dateien als .txt-Dateien mit allen berechneten Werten' newline ...
                  newline ...
                  'Erst "Neue Dateien" dann "Plot ..."' 
                  ], ...
            'Tag', 'infoText');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Dateiauswahlfensters.')
        disp(ME.message)
    end
end

function renameFile(fig)
    try
        fileList = findobj(fig, 'Tag', 'fileList');
        selectedItem = fileList.Value;
        l = length(selectedItem);
        if l == 1
            index = find(cellfun(@(x) isequal(x, selectedItem{1}), fileList.ItemsData));
        else
            error('Bitte genau eine Datei auswählen.')
        end
        if isnumeric(index)
            oldName = fileList.Items{index};
            prompt = {'Geben Sie den neuen Namen für die Datei ein:'};
            dlgtitle = 'Datei umbenennen';
            dims = [1 50];
            definput = {oldName};
            answer = inputdlg(prompt, dlgtitle, dims, definput);
            if ~isempty(answer)
                fileList.Items{index} = answer{1};
                fileList.ItemsData{index}.ID = answer{1};
            end
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Umbenennen der Datei.', 'Icon', 'warning')
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
            fig = findall(0, 'Type', 'figure', 'Name', 'EIS Einstellungen'); 

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
        eis_config = configData.EIS;
        assignin("base", "config", eis_config);
        
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

function createBackButton(fig)
    % Erzeugt einen Zurück-Button, um zur Auswahl zurückzukehren
    try
        back_btn_width = 200;
        back_btn_height = 50;
        back_btn_x = fig.Position(3)/2 + 120;
        back_btn_y = 10;
    
        % Zurück-Button erstellen
        uibutton(fig, 'push', ...
            'Text', 'Zurück zur Auswahl', ...
            'Position', [back_btn_x, back_btn_y, back_btn_width, back_btn_height], ...
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

function addFiles(fig)
    % Funktion zum Hinzufügen von Dateien zur Liste
    try
        area = findobj(fig, 'Tag', 'area').Value;
        shortenNames = findobj(fig, 'Tag', 'shortenNames').Value;
        standardPath = evalin('base', 'standardPath');
        try
            oldFolder = cd(standardPath);
            [fileNames, filePath] = uigetfile({'*.txt;*.csv', 'Text and CSV Files (*.txt, *.csv)'}, 'MultiSelect', 'on');
            cd(oldFolder);
        catch ME
            fig = evalin('base', 'fig');
            uialert(fig, [ME.message], 'Standardordner nicht gültig, bitte in der config anpassen.', 'Icon', 'warning');
            [fileNames, filePath] = uigetfile({'*.txt;*.csv', 'Text and CSV Files (*.txt, *.csv)'}, 'MultiSelect', 'on');
        end
        
        if isequal(fileNames, 0)
            return;
        end

        assignin("base",'standardPath', filePath)
        
        configFile = evalin('base', 'currentRef');
        fileList = findobj(fig, 'Tag', 'fileList');
    
        dataFiles = getDataFiles(fileNames, filePath);
        if isempty(dataFiles)
            disp('Bitte mindestens eine Datei auswählen');
            return;
        end
    
        try
            d = uiprogressdlg(fig,'Title', 'Bitte Warten', 'Message', 'Dateien werden geladen');
            factor = 1/length(dataFiles);
            for i = 1:length(dataFiles)
                [~, ~, ext] = fileparts(dataFiles{i});
                switch lower(ext)
                    case '.txt'
                        [data, ~] = read_eis_txt(dataFiles(i), configFile);
                    case '.csv'
                        data = read_eis_csv(dataFiles(i), configFile);
                    otherwise
                        error('Unsupported file extension: %s', ext);
                end
                impedance = data{1} (:, 3);
                phasDeg = data{1} (:, 4);
                real = impedance .* cosd(phasDeg) * area;
                imaginary = impedance .* sind(phasDeg) * area;
                data{1} = [data{1}, real, imaginary];  
                if ischar(fileNames)
                    fileName = extractAndTruncateName(fileNames, shortenNames);
                    fileName = addNameCounter(fig, fileName);
                    addFileToList(fileList, fileName , data, length(fileList.Items) + 1)
                else
                    fileName = extractAndTruncateName(fileNames{i}, shortenNames);
                    fileName = addNameCounter(fig, fileName);
                    addFileToList(fileList, fileName, data, length(fileList.Items) + 1)
                end
                drawnow;
                d.Value = factor * i;
            end
            close(d)
        catch ME
            if ~exist("fig") %#ok<EXIST> 
                fig = uifigure();
            end
            uialert(fig, ME.message, 'Fehler beim Lesen der Dateien.')
            disp(ME.message)
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Hinzufügen der Dateien.')
        disp(ME.message)
    end
end

function dataFiles = getDataFiles(fileNames, filePath)
    % Helper function to get data files from the selected filenames
    try
        if ischar(fileNames)
            dataFiles = {fullfile(filePath, fileNames)};
        elseif iscell(fileNames) && length(fileNames) >= 2
            dataFiles = cell(1, length(fileNames));
            for i = 1:length(fileNames)
                dataFiles{i} = fullfile(filePath, fileNames{i}); 
            end
        else
            dataFiles = {};
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen der Dateinamen.')
        disp(ME.message)
    end
end

function addFileToList(fileList, fileName, data, position)
    try
        if isempty(fileList.Items)
            fileList.Items = {fileName};
            fileList.ItemsData = {struct('Data', data, 'ID', fileName)};
        else
            index = find(cellfun(@(x) isequal(x.ID, fileName), fileList.ItemsData));
            if ~isempty(index)
                % Wenn ein Eintrag mit gleichem Namen schon existiert, entferne ihn
                fileList.Items(index) = [];
                fileList.ItemsData(index) = [];
                if index < position
                    position = position - 1;
                end
            end
            % Füge neuen Eintrag an gewünschter Position ein
            fileList.Items = [fileList.Items(1:position-1), {fileName}, fileList.Items(position:end)];
            fileList.ItemsData = [fileList.ItemsData(1:position-1), {struct('Data', data, 'ID', fileName)}, fileList.ItemsData(position:end)];
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Hinzufügen einer Datei.')
        disp(ME.message)
    end
end

function selectAllFiles(fig)
    % Funktion zum Wählen aller Dateien in der Liste
    try
        fileList = findobj(fig, 'Tag', 'fileList');
        fileList.Value = fileList.ItemsData;
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Auswählen aller Dateien.')
        disp(ME.message)
    end
end

function selectAllMWAndSigmaFiles(fig)
    % Funktion zum Wählen aller MW&σ Dateien in der Liste
    try
        fileList = findobj(fig, 'Tag', 'fileList');
        items = fileList.Items;
        
        % Initialisiere ein leeres Array für die Indizes der auszuwählenden Dateien
        indexArray = [];
    
        for i = 1:length(items)
            file = items(i);
            
            % Prüfe, ob die Datei mit 'MW&σ' endet
            if contains(file, 'MW&σ')
    
                % Füge den Index der Datei dem Array hinzu
                indexArray(end+1) = i;  %#ok<AGROW> 
            end
    
        end
        fileList.Value = fileList.ItemsData(indexArray);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Auswählen aller MW&σ-Dateien.')
        disp(ME.message)
    end
end

function deselectAllFiles(fig)
    % Funktion zum Abwählen aller Dateien in der Liste
    try
        fileList = findobj(fig, 'Tag', 'fileList');
        fileList.Value = {};
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Abwählen aller Dateien.')
        disp(ME.message)
    end
end

function clearSelectedFiles(fig)
    % Function to clear all selected files from the list
    try
        fileList = findobj(fig, 'Tag', 'fileList');
        selectedItems = fileList.Value;
    
        if isempty(selectedItems)
            return; % Nichts zu löschen, wenn keine Elemente ausgewählt sind
        end
    
        % Stellen Sie sicher, dass selectedItems ein Zell-Array von Zeichenvektoren ist
        if ischar(selectedItems)
            selectedItems = {selectedItems};
        end
    
        % Stellen Sie sicher, dass fileList.Items und fileList.ItemsData Zell-Arrays von Zeichenvektoren sind
        if ischar(fileList.Items)
            fileList.Items = {fileList.Items};
        end
    
        if ischar(fileList.ItemsData)
            fileList.ItemsData = {fileList.ItemsData};
        end
    
        % Entfernen der ausgewählten Elemente aus der Liste
        indexArray = NaN(1, length(selectedItems));
        d = uiprogressdlg(fig,'Title', 'Bitte Warten', 'Message', 'Dateien werden gelöscht');
        factor = 1 / numel(selectedItems);
        for i = 1:numel(selectedItems)
            indexArray(i) = find(cellfun(@(x) isequal(x, selectedItems{i}), fileList.ItemsData));
            d.Value = factor * i;
        end
        close(d)
    
        if ~isempty(indexArray)
            fileList.Items(indexArray) = [];
            fileList.ItemsData(indexArray) = [];
        end
    
        % Auswahl löschen
        fileList.Value = {};
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Löschen der Dateien.')
        disp(ME.message)
    end
end

function nyquistPlotSelectedFiles(fig)
    % Funktion zum Plotten der ausgewählten Dateien
    try
        d = uiprogressdlg(fig,'Title','Bitte Warten', 'Message','Plot wird erstellt');
    
        % config laden
        config = evalin("base", 'config');
    
        fileList = findobj(fig, 'Tag', 'fileList');
        selectedFiles = fileList.Value;
    
        showSigma = findobj(fig, 'Tag', 'showSigma').Value;
        numColumns = findobj(fig, 'Tag', 'numColumns').Value;

        ref = false;
    
        % Daten nach Listenposition sortieren:
    
        d.Value = 0.1;
    
        % Indize der Daten in der Liste ermitteln
        indexArray = NaN(1, length(selectedFiles));
        for i = 1:length(selectedFiles)
            file = selectedFiles(i);
            indexArray(i) = find(cellfun(@(x) isequal(x, file{1}), fileList.ItemsData)) + 1;
        end
    
        d.Value = 0.2;
    
        % Reihenfolge der Daten ermitteln
        [~, order] = sort(indexArray);
        % Daten umsortieren
        selectedFiles = selectedFiles(order);
    
        if isempty(selectedFiles)
            uialert(fig, 'Keine Dateien ausgewählt', 'Fehler');
            return;
        end
    
        d.Value = 0.3;
    
        figure('Units', 'normalized', 'OuterPosition', [0 0 1 1]);
        hold on;
        maxReal = NaN(numel(selectedFiles), 1);
        % Zugriff auf die ColorOrder-Eigenschaft der aktuellen Achse
        colors = jet(numel(selectedFiles));
        % Anzahl der verfügbaren Farben im ColorOrder
        numColors = size(colors, 1);
    
        d.Value = 0.4;
    
        for i = 1:numel(selectedFiles)
            data  = selectedFiles{i}.Data;
            Realteil = data (:, 5);
            Imaginaerteil = data (:, 6);
            colorIndex = mod(i-1, numColors) + 1; % Zyklischer Zugriff auf die Farben
            fileName = selectedFiles{i}.ID;
            if startsWith(fileName, 'Ref: ')
                plot(Realteil, Imaginaerteil, '-', 'LineWidth', config.lineWidth*8, 'Color', [0.9 0.9 0.9], 'HandleVisibility', 'off')
                plot(Realteil, Imaginaerteil, 'o', 'LineWidth', config.lineWidth*10, 'MarkerFaceColor', [0.9 0.9 0.9], 'Color', [0.9 0.9 0.9], 'HandleVisibility', 'off')
                maxReal(i) = max(Realteil);
                d.Value = 0.7;
                ref = true;
            elseif size(data, 2) >= 10 && showSigma
                % Fehlerbalken hinzufügen
                errorReal = data(:, 9);
                errorImag = data(:, 10);
                errorbar(Realteil, Imaginaerteil, errorImag, errorImag, errorReal, errorReal, '', 'Color', 'k', 'HandleVisibility', 'off')
                plot(Realteil, Imaginaerteil, '.-', 'LineWidth', config.lineWidth*2, 'Color', colors(colorIndex, :), 'DisplayName', strrep(fileName, '_', '\_'))
                maxReal(i) = max(Realteil);
                d.Value = 0.7;
            else
                % Ohne Fehlerbalken plotten
                plot(Realteil, Imaginaerteil, '-', 'LineWidth', config.lineWidth*2, 'Color', colors(colorIndex, :), 'DisplayName', strrep(fileName, '_', '\_'))
                plot(Realteil, Imaginaerteil, 'o', 'LineWidth', config.lineWidth*3, 'MarkerFaceColor', 'w', 'Color', colors(colorIndex, :), 'HandleVisibility', 'off')
                maxReal(i) = max(Realteil);
                d.Value = 0.7;
            end
        end

        if ref
            plot(nan, nan, '-o', 'LineWidth', config.lineWidth*8, 'MarkerSize', config.lineWidth*8, ...
                'MarkerFaceColor', [0.9, 0.9, 0.9], ...
                'Color', [0.9, 0.9, 0.9], 'DisplayName', 'Referenz');
        end
        
        configureAxes()
        set(gca, 'YAxisLocation', 'origin') % Y-Achse am Ursprung
        set(gca, 'YDir', 'reverse')
        set(gca, 'xLim', [0, max(maxReal) + 0.025])
    
        d.Value = 0.9;
    
        ax = gca;
        ax.XAxis.FontSize = config.xTickSize;
        ax.YAxis.FontSize = config.yTickSize;
    
        % Titel und Achsenbeschriftung
        title1 = char(findobj(fig, 'Tag', 'title').Value);
        title(title1, config.nyquistXlabel)
        ylabel(config.nyquistYlabel);
        l = legend('Location', 'bestoutside', 'Orientation', 'horizontal', 'NumColumns', numColumns);  % Legenden anzeigen
        l.FontSize = config.legendFontSize;
        hold off;
        d.Value = 1;
        close(d)
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des -Nyquist-Plots.')
        disp(ME.message)
    end
end

function bodePlotSelectedFiles(fig)
    % Funktion zum Plotten der ausgewählten Dateien
    try
        d = uiprogressdlg(fig,'Title','Bitte Warten',...
            'Message','Plot wird erstellt');
    
        % config laden
        config = evalin("base", 'config');
    
        fileList = findobj(fig, 'Tag', 'fileList');
        selectedFiles = fileList.Value;
    
        showSigma = findobj(fig, 'Tag', 'showSigma').Value;
        numColumns = findobj(fig, 'Tag', 'numColumns').Value;
        
        ref = false;
    
        d.Value = 0.1;
    
        % Daten nach Listenposition sortieren:
        indexArray = NaN(1, length(selectedFiles));
        for i = 1:length(selectedFiles)
            file = selectedFiles(i);
            indexArray(i) = find(cellfun(@(x) isequal(x, file{1}), fileList.ItemsData)) + 1;
        end
        [~, order] = sort(indexArray);
        selectedFiles = selectedFiles(order);
    
        if isempty(selectedFiles)
            uialert(fig, 'Keine Dateien ausgewählt', 'Fehler');
            return;
        end
    
        d.Value = 0.3;
    
        figure('Units', 'normalized', 'OuterPosition', [0 0 1 1]);
        hold on;
        legends = cell(numel(selectedFiles), 1);
        colors = jet(numel(selectedFiles));
        numColors = size(colors, 1);
        maxImp = NaN(numel(selectedFiles), 1);
        minImp = NaN(numel(selectedFiles), 1);
        maxPhase = NaN(numel(selectedFiles), 1);
        minPhase = NaN(numel(selectedFiles), 1);
    
        for i = 1:numel(selectedFiles)
            legends{i} = selectedFiles{i}.ID;
            legends{i} = strrep(legends{i}, '_', '\_');
            colorIndex = mod(i-1, numColors) + 1;
            data = selectedFiles{i}.Data;
            frequency = data(:, 2);
            impedance = data(:, 3);
            phaseDeg = data(:, 4);
            colororder({'k', 'k'})
    
            d.Value = 0.5;
    
            if startsWith(legends{i}, 'Ref: ')
                yyaxis left;
                plot(frequency, impedance, 'o-', 'LineWidth', config.lineWidth*4.5, 'Color', [0.9 0.9 0.9], 'MarkerSize', 8, 'HandleVisibility', 'off');
                xlabel(config.bodeXlabel);
                ylabel(config.bodeYlabelLeft);
                set(gca, 'YScale', 'log');
                maxImp(i) = max(impedance);
                minImp(i) = min(impedance);

                yyaxis right;
                plot(frequency, abs(phaseDeg), 'o--', 'LineWidth', config.lineWidth*4.5, 'Color', [0.9 0.9 0.9], 'MarkerSize', 8, 'HandleVisibility', 'off');
                maxPhase(i) = max(phaseDeg);
                minPhase(i) = min(phaseDeg);
                ylabel(config.bodeYlabelRight);
                d.Value = 0.8;
                ref = true;
            elseif size(data, 2) >= 10 && showSigma
                errorImp = data(:, 7);
                errorPhase = data(:, 8);
                yyaxis left;
                errorbar(frequency, impedance, errorImp, errorImp, 'o-', 'LineWidth', config.lineWidth, 'Color', colors(colorIndex, :), 'MarkerSize', 5, ...
                    'DisplayName', [legends{i}, '\_Impedance']);
                xlabel(config.bodeXlabel);
                ylabel(config.bodeYlabelLeft);
                set(gca, 'YScale', 'log');
                maxImp(i) = max(impedance);
                minImp(i) = min(impedance);

                yyaxis right;
                errorbar(frequency, abs(phaseDeg), errorPhase, errorPhase, 'o--', 'LineWidth', config.lineWidth, 'Color', colors(colorIndex, :), 'MarkerSize', 5, ...
                    'DisplayName', [legends{i}, '\_Phase']);
                maxPhase(i) = max(phaseDeg);
                minPhase(i) = min(phaseDeg);
                ylabel(config.bodeYlabelRight);
                d.Value = 0.8;
            else
                yyaxis left;
                plot(frequency, impedance, 'o-', 'LineWidth', config.lineWidth*1.5, 'Color', colors(colorIndex, :), 'MarkerSize', 4, 'DisplayName', [legends{i}, '\_Impedance']);
                xlabel(config.bodeXlabel);
                ylabel(config.bodeYlabelLeft);
                set(gca, 'YScale', 'log');
                maxImp(i) = max(impedance);
                minImp(i) = min(impedance);

                yyaxis right;
                plot(frequency, abs(phaseDeg), 'o--', 'LineWidth', config.lineWidth*1.5, 'Color', colors(colorIndex, :), 'MarkerSize', 4, 'DisplayName', [legends{i}, '\_Phase']);
                maxPhase(i) = max(phaseDeg);
                minPhase(i) = min(phaseDeg);
                ylabel(config.bodeYlabelRight);
                d.Value = 0.8;
            end
        end

        if ref
            plot(nan, nan, 'o-', 'LineWidth', config.lineWidth*4.5, 'Color', [0.9 0.9 0.9], 'MarkerSize', 8, 'DisplayName', 'Referenz');
        end

        yyaxis left;
        ymax = max(maxImp);
        baseTicks = [100, 178, 316, 562];
        yTicks = generateLogTicks(ymax * 1e12, baseTicks, 1e-12);
        yTickLabels = arrayfun(@formatTickLabel, yTicks, 'UniformOutput', false);
        set(gca, 'YTick', yTicks, 'YTickLabel', yTickLabels);
    
        xmax = max(frequency);
        baseTicks = [1];    %#ok<NBRAK> 
        xTicks = generateLogTicks(xmax * 1e6, baseTicks, 1);
        xTickLabels = arrayfun(@formatTickLabel, xTicks, 'UniformOutput', false);
        set(gca, 'XTick', xTicks, 'XTickLabel', xTickLabels);
        ax = gca;
        ax.XAxis.FontSize = config.xTickSize;
        ax.YAxis(1).FontSize = config.yTickSize;
        ax.YAxis(2).FontSize = config.yTickSize;
    
        d.Value = 0.9;
    
        yyaxis right;
        ymax = max(maxPhase);
        ymin = min(minPhase);
        yLim = [ymin, ymax];
        if yLim(1) < 0 && yLim(2) < 0
            yLim = [1.05 * yLim(1), -0.1 * yLim(2)];
        elseif yLim(1) < 0 && yLim(2) >= 0
            yLim = [1.05 * yLim(1), 1.05 * yLim(2)];
        elseif yLim(1) >= 0 && yLim(2) >= 0
            yLim = [-0.1 * yLim(1), 1.05 * yLim(2)];
        end
        set(gca, 'YLim', yLim)
        set(gca, 'YLim', [0, 90])
    
        set(gca, 'XScale', 'log');
        set(gca, 'XLim', [0, max(frequency)])
        
        configureAxes()
        % Titel und Achsenbeschriftung
        title1 = char(findobj(fig, 'Tag', 'title').Value);
        title(title1)
        l = legend('Location', 'bestoutside', 'Orientation', 'horizontal', 'NumColumns', numColumns);
        l.FontSize = config.legendFontSize;
        hold off;
        d.Value = 1;
        close(d)
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Bode-Plots.')
        disp(ME.message)
    end
end

function addReference(fig)
    fileList = findobj(fig, 'Tag', 'fileList');
    selectedFiles = fileList.Value;
    for i = 1:length(selectedFiles)
        fileName = selectedFiles{i}.ID;
        if ~startsWith(fileName, 'Ref: ')
            [~, id] = ismember(fileName, fileList.Items);
            fileName = ['Ref: ', fileName]; %#ok<AGROW> 
            fileList.Items{id} = fileName;
            fileList.ItemsData{id}.ID = fileName;
        end
    end
end

function removeReference(fig)
    fileList = findobj(fig, 'Tag', 'fileList');
    selectedFiles = fileList.Value;
    for i = 1:length(selectedFiles)
        fileName = selectedFiles{i}.ID;
        if startsWith(fileName, 'Ref: ')
            [~, id] = ismember(fileName, fileList.Items);
            fileName = fileName(6:end);
            fileList.Items{id} = fileName;
            fileList.ItemsData{id}.ID = fileName;
        end
    end
end

function addAverageAndSigmaFile(fig)
    % Funktion zum Berechnen des Durchschnitts der ausgewählten Dateien und Hinzufügen als neue Datei zur Liste
    try
        fileList = findobj(fig, 'Tag', 'fileList');
        shortenNames = findobj(fig, 'Tag', 'shortenNames').Value;
        selectedFiles = fileList.Value;
    
        n = nan(1:length(selectedFiles));
        for i = 1:length(selectedFiles)
            test = selectedFiles{i}.Data;
            n(1, :, i) = size(test);
        end
        % Prüfen, ob alle Slices gleich sind
        isEqual = isequal(n, repmat(n(:,:,1), [1, 1, size(n, 3)]));
    
        if isEqual
            if isempty(selectedFiles)
                uialert(fig, 'Keine Dateien ausgewählt', 'Fehler');
                return;
            end
            
            std_devs = addStandardDeviation(selectedFiles);
        
            % Berechnung des Durchschnitts
            numFiles = numel(selectedFiles);
            avgData = zeros(size(selectedFiles{1}.Data));
        
            for i = 1:numFiles    
                avgData = avgData + cell2mat({selectedFiles{i}.Data});
            end
            avgData = avgData / numFiles;
            
            avgAndSigmaData = [avgData, std_devs];
            
            % Generierung des neuen Dateinamens
            commonName = getCommonName(fileList, shortenNames);
            if commonName(end) == '_'
                commonName = commonName(1:end-1);
            end
            newFileName = [commonName, '_MW&σ'];
            newFileName = addNameCounter(fig, newFileName);
            
            % Position für die neue Datei
            indexArray = NaN(1, length(selectedFiles));
            for i = 1:length(selectedFiles)
                file = selectedFiles(i);
                indexArray(i) = find(cellfun(@(x) isequal(x, file{1}), fileList.ItemsData)) + 1;
            end
            index = max(indexArray);
            % Hinzufügen der neuen Datei zur Liste
            addFileToList(fileList, newFileName, {avgAndSigmaData}, index);
        else
            uialert(fig, 'Die Messdateien haben unterschiedlich viele Messwerte, daher ist die Berechnung nicht sinnvoll', 'Achtung')
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Hinzufügen der MW&σ-Datei.')
        disp(ME.message)
    end
end

function std_devs = addStandardDeviation(selectedFiles)
    % Funktion zum Berechnen der Standardabweichung der ausgewählten Dateien und Hinzufügen als neue Datei zur Liste
    try
        numFiles = numel(selectedFiles);
        [nRows, nCols] = size(selectedFiles{1}.Data(:, [3, 4, 5, 6]));
    
        data = zeros(nRows, nCols, numFiles);
    
        for i = 1:numFiles
            data(:, :, i) = selectedFiles{i}.Data(:, [3, 4, 5, 6]);
        end
    
        std_devs = std(data, 0, 3);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Berechnen der Standardabweichung.')
        disp(ME.message)
    end
end

function commonName = getCommonName(fileList, shortenNames)
    % Funktion zum Ermitteln des gemeinsamen Teils der Dateinamen der ausgewählten Dateien
    try
        selectedFiles = fileList.Value;
        legends = cellfun(@(x) fileList.Items{cellfun(@(y) isequal(y, x), fileList.ItemsData)}, selectedFiles, 'UniformOutput', false);
    
        minLength = min(cellfun(@length, legends));
        legends = cellfun(@(x) x(1:minLength), legends, 'UniformOutput', false);
        ids = [];
        k = 1;
        for i = 1:minLength
            if ~all(cellfun(@(x) x(i) == legends{1}(i), legends))
                ids(k) = i; %#ok<AGROW> 
                k=k+1;
            end
        end
        
        if shortenNames
            if 1 == length(legends)
                commonName = legends{1}(1:ids(1));
            else
                commonName = legends{1}(1:ids(1)-1);
            end
        else
            commonName = legends{1};
            commonName(ids) = 'X';
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Ermitteln des gemeinsamen Namens.')
        disp(ME.message)
    end
end

function configureAxes()
    % Anpassung der Achsen und des Gitters
    try
        ax = gca;
        ax.XGrid = 'on';
        ax.YGrid = 'on';
        ax.GridLineStyle = '-';
        ax.GridColor = [0.5, 0.5, 0.5];
        ax.GridAlpha = 0.7;
        ax.Layer = 'top';
        ax.XAxisLocation = 'origin';
        ax.Layer = 'top';
        ax.ClippingStyle = 'rectangle'; % Clipping anpassen
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Anpassen des Plots.')
        disp(ME.message)
    end
end

function resizeUIComponents(fig)
    % Diese Funktion passt die Größe und Position der UI-Elemente an, wenn die Fenstergröße geändert wird.
    try
        windowWidth = fig.Position(3);
        windowHeight = fig.Position(4);
    
        widthScaleFactor = windowWidth / 900;
        heightScaleFactor = windowHeight / 625;
        margin = 20 * widthScaleFactor;
        height = 22 * heightScaleFactor;
    
        resizeComponent(fig, 'fileListLabel',           [margin,                    588 * heightScaleFactor,    120 * widthScaleFactor,     27 * heightScaleFactor]);
        resizeComponent(fig, 'fileList',                [margin,                    110 * heightScaleFactor,    415 * widthScaleFactor,    480 * heightScaleFactor]);
        resizeComponent(fig, 'configButton',            [305 * widthScaleFactor,    593 * heightScaleFactor,    130 * widthScaleFactor,    height]);
        resizeComponent(fig, 'exportieren',             [160 * widthScaleFactor,    593 * heightScaleFactor,    130 * widthScaleFactor,    height]);
    
        small_btn_y = 75 * heightScaleFactor;
        small_btn_width = 100 * widthScaleFactor;
        small_btn_height = 30 * heightScaleFactor;

        resizeComponent(fig, 'Neue Dateien',            [margin,                    small_btn_y,                small_btn_width,            small_btn_height]);
        resizeComponent(fig, 'Alle wählen',             [125 * widthScaleFactor,    small_btn_y,                small_btn_width,            small_btn_height]);
        resizeComponent(fig, 'Alle abwählen',           [230 * widthScaleFactor,    small_btn_y,                small_btn_width,            small_btn_height]);
        resizeComponent(fig, 'Löschen',                 [335 * widthScaleFactor,    small_btn_y,                small_btn_width,            small_btn_height]);
    
        btn_y = 10 * heightScaleFactor;
        btn_width = 200 * widthScaleFactor;
        btn_height = 50 * heightScaleFactor;

        resizeComponent(fig, 'Plot -Nyquist',           [130 * widthScaleFactor,    btn_y,                      btn_width,                  btn_height]);
        resizeComponent(fig, 'Plot Bode',               [350 * widthScaleFactor,    btn_y,                      btn_width,                  btn_height]);
        resizeComponent(fig, 'backButton',              [570 * widthScaleFactor,    btn_y,                      btn_width,                  btn_height]);

        param_y = 460 * heightScaleFactor;
        resizeComponent(fig, 'Referenz off',            [665 * widthScaleFactor,    param_y,                    215 * widthScaleFactor,     small_btn_height]);
        resizeComponent(fig, 'Referenz on',             [440 * widthScaleFactor,    param_y,                    215 * widthScaleFactor,     small_btn_height]);

        param_y = 495 * heightScaleFactor;
        resizeComponent(fig, 'Datei umbenennen',        [440 * widthScaleFactor,    param_y,                    440 * widthScaleFactor,     small_btn_height]);
    
        param_y = 530 * heightScaleFactor;
        resizeComponent(fig, 'MW&σ wählen',             [665 * widthScaleFactor,    param_y,                    215 * widthScaleFactor,     small_btn_height]);
        resizeComponent(fig, 'Mittelwert berechnen',    [440 * widthScaleFactor,    param_y,                    215 * widthScaleFactor,     small_btn_height]);
    
    
        param_y = 565 * heightScaleFactor;
        resizeComponent(fig, 'showSigma',               [660 * widthScaleFactor,    param_y,                     80 * widthScaleFactor,     height]);
        resizeComponent(fig, 'shortenNames',            [755 * widthScaleFactor,    param_y,                    125 * widthScaleFactor,     height]);

        resizeComponent(fig, 'numColumnsLabel',         [440 * widthScaleFactor,    param_y,                    160 * widthScaleFactor,     height]);
        resizeComponent(fig, 'numColumns',              [590 * widthScaleFactor,    param_y,                     50 * widthScaleFactor,     height]);
        param_y = 593 * heightScaleFactor;
        resizeComponent(fig, 'areaLabel',               [745 * widthScaleFactor,    param_y,                    100 * widthScaleFactor,     height]);
        resizeComponent(fig, 'area',                    [825 * widthScaleFactor,    param_y,                     55 * widthScaleFactor,     height]);
    
        resizeComponent(fig, 'titleLabel',              [440 * widthScaleFactor,    param_y,                     50 * widthScaleFactor,     height]);
        resizeComponent(fig, 'title',                   [470 * widthScaleFactor,    param_y,                    264 * widthScaleFactor,     height]);

        resizeComponent(fig, 'infoText',                [440 * widthScaleFactor,    small_btn_y,                440 * widthScaleFactor,     300 * heightScaleFactor]);
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
    try
        if evalin('base', 'exist("referenceDataArray", "var")') == 1 
            evalin('base', 'clear referenceDataArray');
        end
        evalin("base", 'clear config');
        evalin('base', 'clear referenceFolder');
        evalin('base', 'clear currentRef');
        evalin('base', 'clear fig');
        clc;
        Auswahl(fig);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Zurück-Buttons.')
        disp(ME.message)
    end
end

function areaWarning(fig)
    try
        fileList = findobj(fig, 'Tag', 'fileList');
        if ~isempty(fileList.Items)
            uialert(fig, 'Bitte alle Dateien löschen und neu laden, da die Fläche nur beim laden der Daten ausgewertet wird', 'Warnung');
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Ausgeben der Flächenwarnung.')
        disp(ME.message)
    end
end

function Ticks = generateLogTicks(max, baseTicks, startFactor)
    % Funktion zum Generieren der logarithmischen Ticks bei 178, 316, 562 und 1
    try
        Ticks = [];
    
        while true
            newTicks = startFactor * baseTicks;
            if all(newTicks > max)
                break;
            end
            Ticks = [Ticks, newTicks];  %#ok<AGROW> 
            startFactor = startFactor * 10;
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Generieren der Logarithmischen Ticks.')
        disp(ME.message)
    end
end

function label = formatTickLabel(value)
    try
        prefixes = {'p', 'n', 'µ', 'm', '', 'k', 'M', 'G'};
        exponent = floor(log10(value));
        mantissa = value / 10^exponent;
    
        prefixIndex = floor(exponent / 3) + 5;
        if prefixIndex < 1
            prefixIndex = 1;
        elseif prefixIndex > length(prefixes)
            prefixIndex = length(prefixes);
        end
    
        prefix = prefixes{prefixIndex};
        scaleExponent = exponent - (prefixIndex - 5) * 3;
        mantissa = mantissa * 10^(scaleExponent);
    
        label = sprintf('%.f', mantissa);
        number = length(label);
        switch number
            case 1
                label = sprintf('%.2f%s', mantissa, prefix);
            case 2
                label = sprintf('%.1f%s', mantissa, prefix);
            case 3
                label = sprintf('%.0f%s', mantissa, prefix);
            case 4
                mantissa = 1;
                label = sprintf('%.2f', mantissa);
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Formatieren der Ticklabels.')
        disp(ME.message)
    end
end

function truncatedName = extractAndTruncateName(fileName, shortenNames)
    try
        if shortenNames
            eisIndex = strfind(fileName, 'EIS');
            if isempty(eisIndex)
                truncatedName = fileName;
            else
                truncatedName = fileName(eisIndex(1):end);
            end
            
            [~, name, ext] = fileparts(truncatedName);
            if strcmp(ext, '.txt') || strcmp(ext, '.csv')
                truncatedName = name;
            end
        
            if ~isempty(truncatedName) && length(truncatedName) >= 4
                underscoreIndices = strfind(truncatedName, '_');
                if ~isempty(underscoreIndices)
                    lastUnderscoreIndex = underscoreIndices(end);
                    suffix = truncatedName(lastUnderscoreIndex+1:end);
                    if length(suffix) >= 4 && all(isstrprop(suffix, 'digit'))
                        truncatedName = truncatedName(1:lastUnderscoreIndex-1);
                    end
                end
            end
        else
            truncatedName = fileName;
            [~, name, ext] = fileparts(truncatedName);
            if strcmp(ext, '.txt') || strcmp(ext, '.csv')
                truncatedName = name;
            end
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim extrahieren des Dateinamens.')
        disp(ME.message)
    end
end

function fileName = addNameCounter(fig, fileName)
    fileList = findobj(fig, 'Tag', 'fileList');
    while true
        if ismember(fileName, fileList.Items)
            tokens = regexp(fileName, '(([0123456789]+)', 'tokens');
            if ~isempty(tokens) && endsWith(fileName, ')')
                oldIntLen = length(num2str(tokens{end}{1}));
                newIntStr = num2str(str2double(tokens{end}{1})+1);
                fileName = fileName(1:end-oldIntLen-1);
                fileName = [fileName, newIntStr, ')']; %#ok<AGROW> 
            else
                fileName = [fileName, '(1)']; %#ok<AGROW> 
            end
        else
            break
        end
    end
end

function txtExport(fig)
    % Funktion zum Exportieren der ausgewählten Dateien
    try
        d = uiprogressdlg(fig,'Title','Bitte Warten',...
            'Message','Export wird erstellt');
    
        fileList = findobj(fig, 'Tag', 'fileList');
        selectedFiles = fileList.Value;

        d.Value = 0.1;

        % Indize der Daten in der Liste ermitteln
        indexArray = NaN(1, length(selectedFiles));
        for i = 1:length(selectedFiles)
            file = selectedFiles(i);
            indexArray(i) = find(cellfun(@(x) isequal(x, file{1}), fileList.ItemsData)) + 1;
        end
    
        d.Value = 0.2;
    
        % Reihenfolge der Daten ermitteln
        [~, order] = sort(indexArray);
        % Daten umsortieren
        selectedFiles = selectedFiles(order);
    
        if isempty(selectedFiles)
            uialert(fig, 'Keine Dateien ausgewählt', 'Fehler');
            return;
        end
    
        d.Value = 0.3;

        % Titelzeile festlegen
        titles = ["Number", "Frequency[Hz]", "Impedance[Ω]", "Phase[°]", ...
                  "Real[Ω*cm²]", "Imaginary[Ω*cm²]", "σ-Impedance[Ω]", ...
                  "σ-Phase[°]", "σ-Real[Ω*cm²]", "σ-Imaginary[Ω*cm²]"];

        % Ordner für den Export auswählen
        folder = uigetdir(pwd, 'Wählen Sie den Exportordner aus');
        if folder == 0
            return;
        end

        % Daten für jede ausgewählte Datei exportieren
        for i = 1:length(selectedFiles)
            % Dateiname ermitteln
            filename = fileList.Items{cellfun(@(x) isequal(x, selectedFiles{i}), fileList.ItemsData)};
            
            % Daten extrahieren
            data = selectedFiles{i}.Data;

            % Erstelle eine Datei und öffne sie zum Schreiben
            filepath = fullfile(folder, [filename, '.txt']);
            fid = fopen(filepath, 'wt');

            % Überprüfen, ob die Datei erfolgreich geöffnet wurde
            if fid == -1
                error('Die Datei %s konnte nicht geöffnet werden.', filepath);
            end

            [rows, cols] = size(data);

            % Schreibe die Titelzeile
            fprintf(fid, '%s\t', titles{1:cols});
            fprintf(fid, '\n');

            % Schreibe die Datenzeilen
            formatSpec = ['%g\t', repmat('%e\t', 1, cols-2), '%e\n'];
            for r = 1:rows
                fprintf(fid, formatSpec, data(r, :));
            end

            % Schließe die Datei
            fclose(fid);

            d.Value = 0.3 + 0.7 * (i / length(selectedFiles));
        end

        d.Value = 1.0;
        d.Message = 'Export abgeschlossen';
        pause(1);
        close(d);

    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim extrahieren der Dateien.');
        disp(ME.message)
    end
end