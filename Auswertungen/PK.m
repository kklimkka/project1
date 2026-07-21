%% Setup- und Initialisierungsfunktionen

function PK(referenceFolder)
    % Hauptfunktion, die den gesamten Ablauf steuert.
    % Diese Funktion ruft die config.json ab, richtet die GUI ein und fügt erforderliche Pfade hinzu.
    %
    % Args:
    %    referenceFolder (string): Pfad zum Ordner mit den Referenzdaten
    %    number (integer): Nummer zur Auswahl der Standardwerte
    try
        % Abruf der config.json und Vervollständigen des Pfades zum Referenzordner
        currentRef = referenceFolder;
        assignin("base", "currentRef", currentRef)
        configFile = fullfile(currentRef, 'config.json');
        configData = jsondecode(fileread(configFile));
        pk_config = configData.PK;
        assignin("base", "config", pk_config)
        referenceFolder = fullfile(referenceFolder, 'PK');
    
    
        % Aktuelles Fenster als 'fig' laden und benennen
        fig = evalin('base', 'fig');
        fig.Name = 'PK';
    
        % Setup von 'fig' mit Buttons, Standardwerten und Textfeldern
        delete(fig.Children);
        setupFigure(fig);
        createParameterFields(fig, referenceFolder);
    
        % Event-Listener für die Größenänderung des Fensters hinzufügen
        fig.SizeChangedFcn = @(src, event) resizeUIComponents(fig);
        fig.AutoResizeChildren = 'off';  % Deaktivieren der automatischen Größenanpassung
    
        % Initiale Größenanpassung auf aktuelle Fenstergröße
        resizeUIComponents(fig);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Öffnen des PK-Fensters.')
        disp(ME.message)
    end
end

function setupFigure(fig)
    % Leeren von 'fig' und Hinzufügen eines Textbereichs zum Anzeigen von Informationen.
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    try
        margin = 20;
        
        % Textbereich hinzufügen
        uitextarea(fig, 'Position', [margin, 290, (fig.Position(3) - 3 * margin) / 2, fig.Position(4) - 300], ...
        'Value', ['Die Auswertungsmethode "PK" wurde ausgewählt:' newline ...
              '>> Dropdown-Menü "PK ...": Passt die Titel und Referenzdateien an die jeweilige Polarisationskurve an' newline ...
              '>> Tabelle (rechts): Zeigt die errechneten Strom- und Spannungsdurchschnitte an den Messpunkten an' newline ...
              ['>> Titel Zeile 1 und 2: Titelanpassung (^{Text} für hochgestellten Text und _{Text} für tiefgestellten ' ...
              'Text => [\{, \} und \\ um {, } und \ zu schreiben])'] newline ...
              '>> Mittelwert ab ...: Gibt an, wie viele Sekunden vor jedem Stromabfall für die jeweilige Mittelwertberechnung genutzt werden sollen' newline ...
              '>> Messwerte pro Sekunde: Gibt an, wie viele Messwerte es in der Datei pro Sekunde gibt' newline ...
              '>> Werte in Plot anzeigen: Falls diese Checkbox gewählt wird, wird an jedem Datenpunkt im Plot die Spannung angezeigt' newline ...
              '>> Referenzdaten anzeigen: Falls diese Checkbox gewählt wird, werden die Referenzdaten im Plot angezeigt' newline ...
              '>> DUT anzeigen: Falls diese Checkbox gewählt wird, werden die DUT-Daten im Plot angezeigt' newline ...
              '>> Export in Excel: Falls diese Checkbox gewählt wird, wird eine Excel-Datei generiert (siehe Readme FC-OPAT.txt)'
              ], ...
        'Tag', 'infoText');
    
        % Tabelle hinzufügen
        header = {'i [A/cm²]', 'U [V]', 'Verlust [%]'};
        uitable(fig, 'Data', cell(0, 3), 'ColumnName', header, 'Position', ...
            [460, 195, 420, 420], 'Tag', 'dataTable', 'ColumnWidth', {'30x', '10x', '10x'});
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen von Infotext/Tabelle.')
        disp(ME.message)
    end
end

function runMethodScript(method, methodfig)
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
            
            % Fenster (Handle) holen
            fig = findall(0, 'Type', 'figure', 'Name', 'PK Einstellungen'); 

            % Setze den CloseRequestFcn-Callback
            addlistener(fig, 'ObjectBeingDestroyed', @(src, event) onCloseCallback(src, event, methodfig));
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

function onCloseCallback(src, ~, methodfig)
    try
        disp('closed')
        currentRef = evalin("base", 'currentRef');

        configFile = fullfile(currentRef, 'config.json');
        configData = jsondecode(fileread(configFile));
        pk_config = configData.PK;
        assignin("base", "config", pk_config)
        
        % Vermeiden Sie rekursive Aufrufe, indem Sie src löschen
        if isvalid(src)
            delete(src);
        end

        fileList = findobj(methodfig, 'Tag', 'fileList');
        data = fileList.ItemsData;
        for i = 1:length(data)
            currData = data{i}{1}.Data;
            if length(currData) > 1
                newData = calcPKTable({currData}, methodfig, pk_config);
                fileList.ItemsData{i} = newData;
            end
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
            [data, fileNames] = DataWrapper(fig);
        catch
            return
        end 
    
        fileList = findobj(fig, 'Tag', 'fileList');

        for i = 1:length(fileNames)
            addFileToList(fileList, fileNames(i), data(i), length(fileList.Items) + 1)
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Hinzufügen der Dateien.')
        disp(ME.message)
    end
end

function addNewPKData(fig)
    fileList = findobj(fig, 'Tag', 'fileList');

    prompt = {'Geben Sie den Namen für die neue PK ein:'};
    dlgtitle = 'neue PK erstellen';
    dims = [1 50];
    fileName = 'PK';
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

    definput = {fileName};
    answer = inputdlg(prompt, dlgtitle, dims, definput);

    if ~isempty(answer)        
        % Neues Fenster (Figure) erstellen
        newFig = uifigure('Name', ['Daten von ', answer{1}], 'Position', [435, 165, 450, 510]);
        
        % Spaltenüberschriften definieren
        header = {'i [A/cm²]', 'U [V]'};
        
        % Tabelle erstellen
        ct = uitable(newFig, 'Data', [0, 0], 'ColumnName', header, 'Position', [20, 90, 410, 410], ...
            'Tag', 'dataTable', 'ColumnEditable', [true, true], 'ColumnWidth', {'20x', '20x'}, 'ColumnFormat', {'numeric', 'numeric'});
        
        % Button to add a new row
        uibutton(newFig, 'Text', 'Neue Zeile hinzufügen', 'Position', [20, 50, 195, 30], ...
            'ButtonPushedFcn', @(btn, event) addRow(ct));
    
        % Button to remove selected row
        uibutton(newFig, 'Text', 'Zeile entfernen', 'Position', [235, 50, 195, 30], ...
            'ButtonPushedFcn', @(btn, event) removeRow(ct));

        % Button to Save the Data
        uibutton(newFig, 'Text', 'Speichern', 'Position', [20, 10, 410, 30], ...
            'ButtonPushedFcn', @(btn, event) saveNewPK(ct.Data, answer{1}, fileList, newFig));
    end
end

function addRow(tableHandle)
    tableHandle.Data(end+1,:) = [0, 0];
end

function removeRow(tableHandle)
    try
        % Remove the selected row from the table
        if ~isempty(tableHandle.Selection)
            selectedRow = tableHandle.Selection(1);
            tableHandle.Data(selectedRow, :) = [];
        end
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler beim Löschen der Zeile')
        disp(ME.message)
    end
end

function saveNewPK(tableData, fileName, fileList, newFig)
    tableData = struct('avgCurrents', tableData(:, 1), 'avgVoltages', tableData(:, 2));
    data = {struct('Data', NaN, 'PK1', tableData, 'PK2', tableData, 'PK3', tableData)};
    addFileToList(fileList, {fileName}, data, length(fileList.Items) + 1)
    delete(newFig);
end

function addFileToList(fileList, fileName, data, position)
    % Helper function to add a single file to the list at a specific position
    try
        if isempty(fileList.Items)
            fileList.Items = fileName;
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
            fileList.Items = [fileList.Items(1:position-1), fileName, fileList.Items(position:end)];
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

function createParameterFields(fig, referenceFolder)
    % Diese Funktion erstellt Parameterfelder und Buttons für die GUI.
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    try
        % config laden
        config = evalin("base", 'config');
        
        % Definition der Standardwerte 
        defaultTime = config.MWAbSekundenVor;
        defaultFactor = config.MesswerteProSekunde;
        showReference = config.checkRef;
        showDUT = config.checkDUT;
        showTxt = config.checkWerteInPlot;
        export = config.checkExport;
    
        % Parameter für den Plot-Button
        btn_width = 200;
        btn_height = 50;
        btn_y = 10;
        
        headers = config.Header;
    
        % Dropdown hinzufügen für PK Auswahl
        drop = uidropdown(fig, 'Position', [fig.Position(3) - 91.5, 215, 70, 22], 'Tag', 'pkWahl', 'Items', {'PK 1', 'PK 2', 'PK 3'}, 'ValueChangedFcn', @(dd, event) updateTitleAndRef(fig, dd.Value, config, referenceFolder));
        number = str2double(drop.Value(end));
        defaultTitle1 = [config.Titel1{1}, num2str(number)]; 
        defaultTitle2 = config.(sprintf('Titel2_PK%d', number)){1};
    
        % Referenzdaten einlesen
        refstr = sprintf('PK%d', number);
        referenceFolder = fullfile(referenceFolder, refstr);
        getReference(referenceFolder, fig);
    
        % Textfelder hinzufügen um Standardwerte anzeigen und anpassen zu können.
        uilabel(fig, 'Position', [20, 215, 100, 22], 'Text', 'Titel Zeile 1:', 'Tag', 'titleLabel1'); 
        uieditfield(fig, 'text', 'Position', [100, 215, fig.Position(3) - 200, 22], 'Value', defaultTitle1, 'Tag', 'title1');
        
        uilabel(fig, 'Position', [20, 175, 100, 22], 'Text', 'Titel Zeile 2:', 'Tag', 'titleLabel2'); 
        uieditfield(fig, 'text', 'Position', [120, 175, fig.Position(3) - 120, 22], 'Value', defaultTitle2, 'Tag', 'title2'); 
         
        label_width = 320;
        text_width = 50;
        
        uilabel(fig, 'Position', [130, 125, label_width, 22], 'Text', 'Mittelwert ab ... Sekunden vor jedem Stromabfall:', 'Tag', 'timeLabel');
        uieditfield(fig, 'numeric', 'Position', [(fig.Position(3) / 2) + 10 - text_width, 125, text_width, 22], 'Value', defaultTime, 'Tag', 'defaultTime');
        
        uilabel(fig, 'Position', [(fig.Position(3) / 2) - 191, 85, label_width, 22], 'Text', 'Messwerte pro Sekunde:', 'Tag', 'factorLabel');
        uieditfield(fig, 'numeric', 'Position', [(fig.Position(3) / 2) + 10 - text_width, 85, text_width, 22], 'Value', defaultFactor, 'Tag', 'defaultFactor');
        
        % Checkboxen ob Referenzdaten und DUT angezeigt werden sollen.
        uicheckbox(fig, ...
            'Text', 'Referenzdaten anzeigen', ...
            'Position', [620, 125, 150, 22], ...
            'Value', showReference, ...
            'Tag', 'showReference');
        
        uicheckbox(fig, ...
            'Text', 'DUT anzeigen', ...
            'Position', [(fig.Position(3) / 2) + 40, 125, 100, 22], ...
            'Value', showDUT, ...
            'Tag', 'showDUT');
        
        uicheckbox(fig, ...
            'Text', 'Werte in Plot anzeigen', ...
            'Position', [620, 85, 140, 22], ...
            'Value', showTxt, ...
            'Tag', 'showTxt');
        
        uicheckbox(fig, ...
            'Text', 'Export in Excel', ...
            'Position', [(fig.Position(3) / 2) + 40, 85, 100, 22], ...
            'Value', export, ...
            'Tag', 'export');

        % Dateiauswahlliste hinzufügen
        uilabel(fig, "Text", 'Dateiauswahl:', 'Position', [fig.Position(3)/2 + 10, fig.Position(4) - 37, 120, 22], 'Tag', 'fileListLabel', 'FontSize', 15.5)
        uilistbox(fig, 'Position', [fig.Position(3)/2 + 10, 250, fig.Position(3)/2 - 30, fig.Position(4) - 285], 'Tag', 'fileList', ...
            'Multiselect', 'on', 'Items', {});
    
        % Buttons hinzufügen
        uibutton(fig, 'Text', 'PK config', 'Position', [fig.Position(3) / 2 - 140, 276.5, 130, 22], ...
            'ButtonPushedFcn', @(btn, event) runMethodScript('PK', fig), 'Tag', 'configButton');

        uibutton(fig, 'push', 'Text', 'Neue Datei laden', ...
            'Position', [20, btn_y, btn_width, btn_height], ...
            'ButtonPushedFcn', @(btn, event) addFiles(fig), 'Tag', 'Neue Dateien');

        uibutton(fig, 'push', 'Text', 'Eigene PK erstellen', ...
            'Position', [240, btn_y, btn_width, btn_height], ...
            'ButtonPushedFcn', @(btn, event) addNewPKData(fig), 'Tag', 'Eigene Datei');

        uibutton(fig, 'push', 'Text', 'Plotten', ...
            'Position', [460, btn_y, btn_width, btn_height], ...
            'ButtonPushedFcn', @(btn, event) Plot(fig, headers), 'Tag', 'Plot'); 

        uibutton(fig, 'push', 'Text', 'Zurück zur Auswahl', ...
            'Position', [680, btn_y, btn_width, btn_height], ...
            'ButtonPushedFcn', @(btn, event) backToSelection(fig), 'Tag', 'backButton');
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
        resizeComponent(fig, 'infoText',        [margin,                    343 * heightScaleFactor,    420 * widthScaleFactor,     272 * heightScaleFactor]);
        resizeComponent(fig, 'dataTable',       [460 * widthScaleFactor,    195 * heightScaleFactor,    420 * widthScaleFactor,     420 * heightScaleFactor]);
        resizeComponent(fig, 'fileListLabel',   [margin,                    317 * heightScaleFactor,    110 * widthScaleFactor,      24 * heightScaleFactor]);
        resizeComponent(fig, 'fileList',        [margin,                    195 * heightScaleFactor,    420 * widthScaleFactor,     123 * heightScaleFactor]);
        resizeComponent(fig, 'configButton',    [310 * widthScaleFactor,    319.5*heightScaleFactor,    130 * widthScaleFactor,     height]);
    
        % Dropdown skalieren
        resizeComponent(fig, 'pkWahl',          [808.5*widthScaleFactor,    165 * heightScaleFactor,     70 * widthScaleFactor,     height])
    
        % Titelzeilen
        resizeComponent(fig, 'titleLabel1',     [margin,                    165 * heightScaleFactor,    100 * widthScaleFactor,     height]);
        resizeComponent(fig, 'title1',          [100 * widthScaleFactor,    165 * heightScaleFactor,    700 * widthScaleFactor,     height]);
        resizeComponent(fig, 'titleLabel2',     [margin,                    135 * heightScaleFactor,    100 * widthScaleFactor,     height]);
        resizeComponent(fig, 'title2',          [100 * widthScaleFactor,    135 * heightScaleFactor,    780 * widthScaleFactor,     height]);
    
        % Parameterfelder
        resizeComponent(fig, 'timeLabel',       [160 * widthScaleFactor,    105 * heightScaleFactor,    280 * widthScaleFactor,     height]);
        resizeComponent(fig, 'defaultTime',     [440 * widthScaleFactor,    105 * heightScaleFactor,     50 * widthScaleFactor,     height]);
        resizeComponent(fig, 'factorLabel',     [288 * widthScaleFactor,     65 * heightScaleFactor,    152 * widthScaleFactor,     height]);
        resizeComponent(fig, 'defaultFactor',   [440 * widthScaleFactor,     65 * heightScaleFactor,     50 * widthScaleFactor,     height]);
    
        % Checkboxen
        resizeComponent(fig, 'showReference',   [515 * widthScaleFactor,     85 * heightScaleFactor,    150 * widthScaleFactor,     height]);
        resizeComponent(fig, 'showDUT',         [515 * widthScaleFactor,    105 * heightScaleFactor,    100 * widthScaleFactor,     height]);
        resizeComponent(fig, 'showTxt',         [130 * widthScaleFactor,     65 * heightScaleFactor,    150 * widthScaleFactor,     height]);
        resizeComponent(fig, 'export',          [515 * widthScaleFactor,     65 * heightScaleFactor,    100 * widthScaleFactor,     height]);
        
        % Buttons
        btn_y = 10 * heightScaleFactor;
        btn_width = 200 * widthScaleFactor;
        btn_height = 50 * heightScaleFactor;

        resizeComponent(fig, 'Neue Dateien',    [ 20 * widthScaleFactor,    btn_y,                      btn_width,                  btn_height]);
        resizeComponent(fig, 'Eigene Datei',    [240 * widthScaleFactor,    btn_y,                      btn_width,                  btn_height]);
        resizeComponent(fig, 'Plot',            [460 * widthScaleFactor,    btn_y,                      btn_width,                  btn_height]);
        resizeComponent(fig, 'backButton',      [680 * widthScaleFactor,    btn_y,                      btn_width,                  btn_height]);
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
        if evalin('base', 'exist("referenceDataArray", "var")') == 1 
            evalin('base', 'clear referenceDataArray');
        end
        evalin("base", 'clear config')
        evalin('base', 'clear referenceFolder');
        evalin('base', 'clear fig');
        
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

%% Datenverarbeitungsfunktionen

function Plot(fig, headers)
    % Diese Funktion erstellt den Plot basierend auf den ausgewählten Daten.
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    %    headers (array): Array der Header der Spalten
    try
        d = uiprogressdlg(fig,'Title','Bitte Warten',...
            'Message','Plot wird erstellt');
        
        % config laden
        config = evalin("base", 'config');
        try
            lineWidth = config.lineWidth;
        catch ME
            if ~exist("fig", "var")
                fig = uifigure();
            end
            uialert(fig, 'config-Fenster bitte schließen.', 'Fehler beim Erstellen des Plots.')
            disp(ME.message)
            return
        end
        
        % Objekte im Fenster abrufen
        showReference = findobj(fig, 'Tag', 'showReference').Value;
        showDUT = findobj(fig, 'Tag', 'showDUT').Value;
        showTxt = findobj(fig, 'Tag', 'showTxt').Value;
        export = findobj(fig, 'Tag', 'export').Value;
        fileList = findobj(fig, 'Tag', 'fileList');
        PKIndex = findobj(fig, 'Tag', 'pkWahl').Value(end);
        pkTemp = config.(['tempPK', PKIndex]);
        pkInd = config.TempIndex;

        d.Value = 0.1;
        fileNames = {};
            
        if showDUT || export
            allTitles = fileList.Items;
            allData = fileList.ItemsData;
            data = fileList.Value;

            if isempty(data)
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

            selectedIndices = nan(1, numel(data));

            for i = 1:numel(data)
                innerSelected = data{i};
                if iscell(innerSelected) && numel(innerSelected) == 1
                    innerSelected = innerSelected{1}.Data;
                else
                    innerSelected = innerSelected.Data;
                end

                for j = 1:numel(allData)
                    currentData = allData{j}{1}.Data;

                    if isequal(size(innerSelected), size(currentData))
                        diffMat = innerSelected - currentData;

                        diffMat(isnan(diffMat)) = 0; % NaNs ignorieren
                        diffNorm = norm(diffMat, 'fro');

                        if diffNorm == 0
                            selectedIndices(i) = j;
                        end
                    end
                end
            end
            validIdx = ~isnan(selectedIndices);
            fileNames = allTitles(selectedIndices(validIdx));
        end
        
        % Erstellung des Plotfensters
        if showReference || showDUT
            allAvgCurrents = cell(1);
            allAvgVoltages = cell(1);

            if showDUT
                d.Value = 0.2;

                % Verarbeitung jeder Datei
                for i = 1:length(data)
                    currPK = data{i}{1}.(['PK', PKIndex]);
                    
                    if ~isstruct(currPK)
                        error('Richtige PK-Nummer auswählen oder Coolant-Temperatur in config anpassen.');
                    end

                    allAvgCurrents{i} = currPK.avgCurrents;
                    allAvgVoltages{i} = currPK.avgVoltages;
                end
            end

            d.Value = 0.3;

            figure('Units', 'normalized', 'OuterPosition', [0 0.01 1 0.99]);
            hold on;    % Erlaube weitere Plots im Fenster

            gradient();
            configureAxes(fig);
            
            % Ensure the plot line is on top
            ax = gca;
            ax.Layer = 'top'; % Ensure tick marks are on top
            
            referenceDataArray = evalin('base', 'referenceDataArray');
            % Wenn die Referenzdaten-Checkbox ausgewählt ist
            if showReference
                d.Value = 0.4;
                refValueArray = cellfun(@(refData) struct('avgCurrents', averageValues(refData(:, 3), findIndices(refData(:, 2)), fig), ...
                                                          'avgVoltages', averageValues(refData(:, 1), findIndices(refData(:, 2)), fig)), ...
                                                            referenceDataArray, 'UniformOutput', false);
                
                l = length(refValueArray);
                refFiles = evalin("base", 'refFiles');
                refFileNames = cell(1, l);
                allRefAvgCurrents = cell(1, l);
                allRefAvgVoltages = cell(1, l);
                for i = 1:l
                    refFileNames{i} = refFiles(i).name;
                    allRefAvgCurrents{i} = refValueArray{i}.avgCurrents;
                    allRefAvgVoltages{i} = refValueArray{i}.avgVoltages;
                end
                if ~showDUT
                    editTable(fig, allRefAvgCurrents, allRefAvgVoltages, refFileNames, nan, nan);  
                end
                d.Value = 0.5;
                plotReferenceData(refValueArray, lineWidth, showDUT, showTxt, fig, allRefAvgCurrents, allRefAvgVoltages)
                d.Value = 0.6;
            end
            
            if showDUT
                % Originaldaten zwischenspeichern für interaktive Entfernung
                setappdata(fig, 'plotData', struct('currents', allAvgCurrents, 'voltages', allAvgVoltages));
                % Plot line
                if length(allAvgCurrents) == 1
                    h = plot(allAvgCurrents{1}, allAvgVoltages{1}, '--o', 'LineWidth', lineWidth, 'Color', 'b', 'MarkerFaceColor', 'b', 'DisplayName', 'DUT');
                    d.Value = 0.7;
                    uistack(h, "top")
                    
                    % Unsichtbaren Scatter für Klicks auf Punkte erzeugen
                    hold on;
                    scatter(allAvgCurrents{1}, allAvgVoltages{1}, 36, ...
                                       'MarkerEdgeColor', 'b', ...
                                       'MarkerFaceColor', 'b', ...
                                       'HitTest', 'on', ...
                                       'PickableParts', 'all', ...
                                       'ButtonDownFcn', @(src, event) onPointRightClick(src, event, fig), ...
                                       'HandleVisibility', 'off');
                    
                    if showTxt
                        addLabels(allAvgCurrents{1}, allAvgVoltages{1}, 1, h.Color)
                    end
                else
                    colors = jet(length(allAvgCurrents)); % Farben für mehrere Kurven
                    for i = 1:length(allAvgCurrents)
                        name = strrep(fileNames{i}, '_', '\_');
                        h = plot(allAvgCurrents{i}, allAvgVoltages{i} , '--o', 'LineWidth', lineWidth, 'DisplayName', name, 'Color', colors(i,:));
                        uistack(h, "top")
                        h.MarkerFaceColor = h.Color;
                        
                        % Unsichtbaren Scatter für Klicks auf Punkte erzeugen
                        hold on;
                        scatter(allAvgCurrents{i}, allAvgVoltages{i}, 36, ...
                                       'MarkerEdgeColor', h.Color, ...
                                       'MarkerFaceColor', h.Color, ...
                                       'HitTest', 'on', ...
                                       'PickableParts', 'all', ...
                                       'ButtonDownFcn', @(src, event) onPointRightClick(src, event, fig), ...
                                       'HandleVisibility', 'off');
                        if showTxt
                            addLabels(allAvgCurrents{i}, allAvgVoltages{i}, i, h.Color)
                        end
                    end
                    d.Value = 0.7;
                end
                [losses, noLossCurrents] = calcLosses(refValueArray, allAvgVoltages, allAvgCurrents);
                editTable(fig, allAvgCurrents, allAvgVoltages, fileNames, losses, noLossCurrents); 
            end
    
            d.Value = 0.8;
            
            l = legend();
            l.FontSize = config.legendFontSize;
        end
        if export
            d.Value = 0.4;
            % Verarbeitung jeder Datei für den Export
            for i = 1:length(data)
                currData = data{i}{1};
                currData = currData.Data;

                temps = currData(:,pkInd);
                tempIndize = find(temps == pkTemp);
                try
                    currData = currData(tempIndize(1):tempIndize(end), :);
                catch ME
                    if strcmpi(ME.message, 'Index exceeds the number of array elements. Index must not exceed 0.')
                        error('Richtige PK-Nummer auswählen oder Coolant-Temperatur in config anpassen.');
                    end
                end
                indexArray = findIndices(currData(:, 5));
                avgArray = computeAverages(currData, indexArray, fig);
                exportToExcel(fig, headers, avgArray, fileNames{i}) % Export jeder Datei einzeln
            end
            d.Value = 0.8;
        end
        d.Value = 1;
        close(d)
    catch ME
        if ~exist("fig", "var") 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Plots.')
        disp(ME.message)
    end
end

function [losses, noLossCurrents] = calcLosses(refValueArray, allAvgVoltages, allAvgCurrents)
    l_avg = length(refValueArray);
    refVoltages = zeros(length(refValueArray{1}.avgVoltages), l_avg);
    refCurrents = zeros(length(refValueArray{1}.avgCurrents), l_avg);
    for i=1:l_avg
        refVoltages(:, i) = refValueArray{i}.avgVoltages;
        refCurrents(:, i) = refValueArray{i}.avgCurrents;
    end
    noLossVoltages = mean(refVoltages, 2);
    noLossCurrents = round(mean(refCurrents, 2), 2);
    
    l_dut = length(allAvgVoltages);
    losses = zeros(length(allAvgVoltages{1}), l_dut);
    for i = 1:l_dut
        current_dut_voltages = allAvgVoltages{i};
        current_dut_currents = round(allAvgCurrents{i}, 2);
        for k=1:length(current_dut_voltages)
            h = find(noLossCurrents == current_dut_currents(k));
            losses(h, i) = (noLossVoltages(h)-current_dut_voltages(k))/noLossVoltages(h)*100;
        end
    end
end

function onPointRightClick(src, event, fig)
    % Callback-Funktion, um bei click einen Punkt aus dem Plot zu entfernen und neu zu zeichnen
    try
        clickType = get(fig, 'SelectionType');
        if strcmp(clickType, 'normal') 
            clickPos = event.IntersectionPoint(1:2); % x,y Koordinaten
            
            % Hole alle Plot-Daten (als Zellarrays von Kurven)
            data = getappdata(fig, 'plotData');
            currentsCells = {data.currents}; % Zellarray mit Strömen pro Kurve
            voltagesCells = {data.voltages}; % Zellarray mit Spannungen pro Kurve
            
            % Finde die Index der Kurve, zu der der geklickte Punkt gehört
            % Annahme: src ist Scatter-Objekt, dessen XData und YData zum zu entfernenden Punkt gehören
            xDataScatter = src.XData;
            yDataScatter = src.YData;
            
            % Finde den Index des nächsten Punktes in der Scatter-Daten zu clickPos
            distances = hypot(xDataScatter - clickPos(1), yDataScatter - clickPos(2));
            [~, idxToRemove] = min(distances);
            
            % Nun finde die Kurve, die diesen Punkt enthält
            curveIndex = [];
            pointIndexInCurve = [];
            for i = 1:length(currentsCells)
                % Suche im i-ten Dataset den Punkt mit gleichem x- und y-Wert
                idx = find(abs(currentsCells{i} - xDataScatter(idxToRemove)) < 1e-12 & ...
                           abs(voltagesCells{i} - yDataScatter(idxToRemove)) < 1e-12);
                if ~isempty(idx)
                    curveIndex = i;
                    pointIndexInCurve = idx(1);
                    break;
                end
            end
            
            if isempty(curveIndex)
                return; % Punkt nicht gefunden, nichts tun
            end
            
            % Punkt aus der jeweiligen Kurve entfernen
            currentsCells{curveIndex}(pointIndexInCurve) = [];
            voltagesCells{curveIndex}(pointIndexInCurve) = [];
            
            % Aktualisiere die Daten in der AppData
            setappdata(fig, 'plotData', struct('currents', currentsCells, 'voltages', voltagesCells));
            
            % Plot neu zeichnen
            ax = gca;
            cla;
            delete(findall(ax, 'Type', 'scatter'));
            hold on;
            config = evalin('base', 'config');
            lineWidth = config.lineWidth;
            
            colors = jet(length(currentsCells)); % Farben für mehrere Kurven
            
            % Alle Kurven neu zeichnen
            if length(currentsCells) == 1
                plot(currentsCells{1}, voltagesCells{1}, '--o', 'LineWidth', lineWidth, ...
                         'Color', 'b', 'MarkerFaceColor', 'b', 'DisplayName', 'DUT');
                scatter(currentsCells{1}, voltagesCells{1}, 36, ...
                        'MarkerEdgeColor', 'b', ...
                        'MarkerFaceColor', 'b', ...
                        'HitTest', 'on', ...
                        'PickableParts', 'all', ...
                        'ButtonDownFcn', @(src, event) onPointRightClick(src, event, fig), ...
                        'HandleVisibility', 'off');
            else
                for i = 1:length(currentsCells)
                    plot(currentsCells{i}, voltagesCells{i}, '--o', 'LineWidth', lineWidth, ...
                             'Color', colors(i,:), 'MarkerFaceColor', colors(i,:), 'DisplayName', sprintf('DUT %d', i));
                    scatter(currentsCells{i}, voltagesCells{i}, 36, ...
                            'MarkerEdgeColor', colors(i,:), ...
                            'MarkerFaceColor', colors(i,:), ...
                            'HitTest', 'on', ...
                            'PickableParts', 'all', ...
                            'ButtonDownFcn', @(src, event) onPointRightClick(src, event, fig), ...
                            'HandleVisibility', 'off');
                end
            end
            
            configureAxes(fig); % Achsen neu konfigurieren
        end
    catch ME
        if ~exist('fig','var') || isempty(fig)
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Rechtsklick auf Punkt.')
        disp(ME.message)
    end
end

function editTable(fig, allAvgCurrents, allAvgVoltages, fileNames, losses, noLossCurrents)
    try
        dataTable = findobj(fig, 'Tag', 'dataTable');
        % Konvertiere allAvgCurrents und allAvgVoltages in Strings und erstelle Zellen
        avgCurrentsCell = {};
        avgVoltagesCell = {};
        lossesCell = {};
        
        for i = 1:length(allAvgCurrents)
            % Füge eine Zeile mit dem Dateinamen hinzu
            avgCurrentsCell = [avgCurrentsCell; fileNames(i)]; %#ok<AGROW> 
            avgVoltagesCell = [avgVoltagesCell; {' '}]; %#ok<AGROW> % Leere Zelle für Spannung
            lossesCell = [lossesCell; {' '}]; %#ok<AGROW> % Leere Zelle für Verlust
            
            % Füge die Daten hinzu
            newCurrentsCell = arrayfun(@(x) sprintf('%.5f', x), allAvgCurrents{i}, 'UniformOutput', false);
            newVoltagesCell = arrayfun(@(x) sprintf('%.5f', x), allAvgVoltages{i}, 'UniformOutput', false);
            newLossesCell = cell(length(newCurrentsCell), 1);
            if ~isnan(losses)
                for k = 1:length(newCurrentsCell)
                    h = find(noLossCurrents == round(str2double(newCurrentsCell{k}), 2));
                    newLossesCell{k} = losses(h, i); %#ok<FNDSB> 
                end
            end

            avgCurrentsCell = [avgCurrentsCell; newCurrentsCell]; %#ok<AGROW> 
            avgVoltagesCell = [avgVoltagesCell; newVoltagesCell]; %#ok<AGROW> 
            lossesCell = [lossesCell; newLossesCell]; %#ok<AGROW> 
        end
        
        % Erstelle die Tabelle als Zelle
        numRows = length(avgCurrentsCell);
        tableData = cell(numRows, 3);  % Ohne Index-Spalte
        tableData(:, 1) = avgCurrentsCell(:);
        tableData(:, 2) = avgVoltagesCell(:);
        tableData(:, 3) = lossesCell(:);
    
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

function plotReferenceData(refData, lineWidth, showDUT, showTxt, fig, allRefAvgCurrents, allRefAvgVoltages)
    % Diese Funktion plottet die Referenzdaten.
    %
    % Args:
    %    refData (cell array): Zellarray der Referenzdaten
    %    lineWidth (double): Breite der Linien
    %    showDUT (boolean): Flag, ob DUT-Daten angezeigt werden sollen
    %    showTxt (boolean): Flag, ob Werte im Plot angezeigt werden sollen
    try
        config = evalin("base", 'config');

        if ~showDUT     % Falls DUT nicht gezeigt wird, bunte normaldicke Linien
            setappdata(fig, 'plotData', struct('currents', allRefAvgCurrents, 'voltages', allRefAvgVoltages));
            for i = 1:length(refData)
                x = refData{i}.avgCurrents;
                y = refData{i}.avgVoltages;
                refName = sprintf('Referenz#%d', i);
                h = plot(x, y,'--o', 'LineWidth', lineWidth, 'DisplayName', refName);
                color = h.Color;
                h.MarkerFaceColor = color;
                if showTxt
                    addLabels(x, y, i, color)
                end
                hold on;
                scatter(x, y, 36, ...
                               'MarkerEdgeColor', color, ...
                               'MarkerFaceColor', color, ...
                               'HitTest', 'on', ...
                               'PickableParts', 'all', ...
                               'ButtonDownFcn', @(src, event) onPointRightClick(src, event, fig), ...
                               'HandleVisibility', 'off');
            end
        else            % Falls DUT gezeigt wird, graue dicke Linien
            numSteps = 6;
            maxLineWidth = lineWidth * 15;
            lineWidths = linspace(1, maxLineWidth, numSteps);
            for i = 1:length(refData)
                for k = 1:numSteps
                    h = plot(refData{i}.avgCurrents, refData{i}.avgVoltages, 'LineWidth', lineWidths(k), 'HandleVisibility', 'off', ...
                         'LineJoin', 'round', 'MarkerIndices', [1 13]); 
                    h.Color = [0.5 0.5 0.5 0.08 / length(refData)];
                    h.MarkerFaceColor = h.Color;
                end
            end
        end
        l = legend();
        l.FontSize = config.legendFontSize;
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Plotten der Referenzdaten.')
        disp(ME.message)
    end
end

function averageValues = averageValues(data, indexArray, fig)
    % Berechnet den Mittelwert der Daten in einem bestimmten Bereich.
    %
    % Args:
    %    data (array): Array der Daten
    %    indexArray (array): Array der Indizes
    %    fig (figure): Das GUI-Fenster
    %
    % Returns:
    %    averageValues (array): Array der Mittelwerte
    try
        if iscell(data)
            data = cell2mat(data);
        end
        l = length(indexArray);
        averageValues = NaN(l, 1);
        % Bereich für Durchschnitt: Sekunden vor Stromabfall * Anzahl[Messwerte pro Sekunde]:
        area = findobj(fig, 'Tag', 'defaultTime').Value * findobj(fig, 'Tag', 'defaultFactor').Value - 1;
        for i = 1:l
            if isempty(area:indexArray(i))
                error('Richtige PK-Nummer auswählen oder Coolant-Temperatur in config anpassen.');
            end
            subData = data(indexArray(i) - area:indexArray(i));
            averageValues(i) = mean(subData);
        end
    catch ME
        if strcmpi(ME.message, 'Richtige PK-Nummer auswählen oder Coolant-Temperatur in config anpassen.')
            error(ME.message);
        end
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Berechnen der Durchschnitte einer Spalte.')
        disp(ME.message)
    end
end

function avgArray = computeAverages(data, indexArray, fig)
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
        w = width(data);
        l = length(indexArray);
        avgArray = NaN(l, w);
        for n = 1:w
            avgArray(:, n) = averageValues(data(:, n), indexArray, fig);
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Berechnen aller Durchschnitte.')
        disp(ME.message)
    end
end

function [data, fileNames] = DataWrapper(fig)
    % Diese Funktion liest Daten aus ausgewählten Dateien ein.
    %
    % Args:
    %    columns (array): Array der auszuwertenden Spalten
    %
    % Returns:
    %    data (array): Eingelesene Daten
    try
        % config laden
        config = evalin("base", 'config');
        lines = config.Zeilen;
        columns = config.Spalten;
        lines = processInf(lines);
        columns = processInf(columns);
        
        % Standardpfad aus dem Base Workspace abrufen
        standardPath = evalin('base', 'standardPath');
        
        % Verzeichnis zum Standardpfad wechseln
        try
            oldFolder = cd(standardPath);     
            
            % Datei-Auswahldialog für mehrere CSV-Dateien öffnen
            [fileNames, filePath] = uigetfile('*.csv', 'Wählen Sie eine oder mehrere Dateien zur Auswertung aus', 'MultiSelect', 'on');
            
            % Zurück zum ursprünglichen Verzeichnis wechseln
            cd(oldFolder);
            
        catch ME
            fig = evalin('base', 'fig');
            uialert(fig, [ME.message], 'Standardordner nicht gültig, bitte in der config anpassen.', 'Icon', 'warning');
            [fileNames, filePath] = uigetfile('*.csv', 'Wählen Sie eine oder mehrere Dateien zur Auswertung aus', 'MultiSelect', 'on');
        end
        
        % Überprüfen, ob Dateien ausgewählt wurden
        if iscell(fileNames) || ischar(fileNames)
            % Dateipfade erstellen
            if ischar(fileNames)
                fileNames = {fileNames}; % Falls nur eine Datei ausgewählt wurde
            end
            dataFiles = cell(length(fileNames), 1);
            for i = 1:length(fileNames)
                dataFiles{i} = fullfile(filePath, fileNames{i});
            end

            % CSV-Dateien einlesen
            data = read_csv(dataFiles, lines, columns);
            
            % Daten in ein numerisches Array umwandeln und zusammenführen
            for i = 1:length(data)
                data(i) = cellfun(@(x) cell2mat(x), data(i), 'UniformOutput', false);
            end
            if ~iscell(data)
                data = {data};
            end

            assignin("base",'standardPath', filePath)

            data = calcPKTable(data, fig, config);
        else
            return
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Lesen der Daten.')
        disp(ME.message)
    end
end

function data = calcPKTable(data, fig, config)
    pkTemps = [config.tempPK1, config.tempPK2, config.tempPK3];
    pkInd = config.TempIndex;
    area = findobj(fig, 'Tag', 'defaultTime').Value * findobj(fig, 'Tag', 'defaultFactor').Value - 1;
    
    for i = 1:length(data)
        PK = cell(1, length(pkTemps));
        for k = 1:length(pkTemps)
            currData = data{i};
            tempIndize = find(currData(:,pkInd) == pkTemps(k));
            if length(tempIndize) < area
                PK{k} = NaN;
            else
                currData = currData(tempIndize(1):tempIndize(end), :);

                indexArray = findIndices(currData(:, config.StromSetIndex));
                avgArray = computeAverages(currData, indexArray, fig);
                avgCurrents = avgArray(:, config.StromdichteIndex);
                avgVoltages = avgArray(:, config.SpannungsIndex);
                PK{k} = struct('avgCurrents', avgCurrents, 'avgVoltages', avgVoltages);
            end
        end
        data{i} = struct('Data', data{i}, 'PK1', PK{1}, 'PK2', PK{2}, 'PK3', PK{3});
    end
end

function indexArray = findIndices(data)
    % Findet Indizes der Stromabfälle nach dem Strommaximum
    %
    % Args:
    %    data (array): Array mit den Stromdaten
    %
    % Returns:
    %    indexArray (array): Array der Indizes der Stromabfälle
    try
        % Maximum des Stroms und dessen Index finden
        if iscell(data)
            data = cell2mat(data);
        end
        [~, I] = max(data);
        
        % Daten ab dem Maximum betrachten
        data = data(I:end);
        
        % Differenzen zwischen aufeinanderfolgenden Elementen berechnen
        differences = diff(data);
        
        % Indizes finden, bei denen die Differenz negativ ist
        indexArray = find(differences < 0) + I - 1;
        
        % Index des letzten Elements hinzufügen
        indexArray(end + 1) = length(data) + I - 1;
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Suchen der Indize.')
        disp(ME.message)
    end
end

function exportToExcel(fig, headers, avgData, title)
    % Diese Funktion exportiert die Daten in eine Excel-Datei.
    %
    % Args:
    %    headers (cell array): Header der Daten
    %    avgData (array): Durchschnittswerte der Daten
    try
        % Header in eine Zelle konvertieren, um sie in die Excel-Datei zu schreiben
        headers_cell = cellstr(headers)';
        
        % Header und Daten kombinieren
        combined_data = [headers_cell; num2cell(avgData)];
        
        % Dateiauswahldialog öffnen, um Speicherort und Dateinamen auszuwählen
        [filename, pathname] = uiputfile('*.xlsx;*.xlsm', 'Wählen Sie einen Speicherort und Dateinamen', title);
                
        % Fortschrittsdialog erstellen
        d = uiprogressdlg(fig, 'Title', 'Bitte warten', 'Message', 'Exportiere nach Excel');
        
        % Überprüfen, ob der Benutzer den Dialog abgebrochen hat
        if isequal(filename, 0) || isequal(pathname, 0)
            disp('Benutzer hat den Dateiauswahldialog abgebrochen');
        else
            % Beispiel-Excel-Datei aus dem Base Workspace holen
            exampleExcelPath = evalin('base', 'exampleExcelPath');
    
            if ~isequal(filename(end-4:end), exampleExcelPath(end-4:end))
                filename = [filename, exampleExcelPath(end-4:end)];
            end
    
            fullpath = fullfile(pathname, filename);
            
            d.Value = 0.1;
            
            % Überprüfen, ob die Zieldatei bereits existiert und umbenennen, falls geöffnet
            while true
                if exist(fullpath, 'file')
                    [filepath, name, ext] = fileparts(fullpath);
                    tokens = regexp(name, '(([0123456789]+)', 'tokens');
                    if ~isempty(tokens) && endsWith(name, ')')
                        oldIntLen = length(num2str(tokens{end}{1}));
                        newIntStr = num2str(str2double(tokens{end}{1})+1);
                        name = name(1:end-oldIntLen-1);
                        name = [name, newIntStr, ')']; %#ok<AGROW> 
                    else
                        name = [name, '(1)']; %#ok<AGROW> 
                    end
                    fullpath = fullfile(filepath, [name ext]);
                else
                    break
                end
            end
            
            d.Value = 0.2;
    
            % Excel COM Server initialisieren
            Excel = actxserver('Excel.Application');
            Excel.Visible = false; % Excel nicht sichtbar machen
            try
                Workbook = Excel.Workbooks.Open(exampleExcelPath);
                sheet = Workbook.Sheets.Item('Werte'); % Annahme: Die Werte sind auf dem Blatt 'Werte'
    
                % Löschen der alten Daten auf dem Blatt 'Werte'
                sheet.UsedRange.ClearContents();
                fprintf('Alte Daten auf dem Blatt "Werte" gelöscht.\n');
                
                d.Value = 0.3;
    
                % Neue Daten in Blöcken schreiben
                blockSize = 1000; % Anzahl der Zeilen pro Block
                numRows = size(combined_data, 1);
                numCols = size(combined_data, 2);
                fprintf('Gesamtanzahl der Zeilen: %d, Gesamtanzahl der Spalten: %d\n', numRows, numCols);
                
                for startRow = 1:blockSize:numRows
                    if d.CancelRequested
                        break;
                    end
    
                    endRow = min(startRow + blockSize - 1, numRows);
                    
                    d.Value = d.Value + 0.15 * numRows / endRow;
                    
                    dataBlock = combined_data(startRow:endRow, :);
    
                    d.Value = d.Value + 0.15 * numRows / endRow;
                    
                    range = sprintf('A%d:%s%d', startRow, xlColLetter(numCols), endRow);
                    fprintf('Schreibe Block: Startreihe: %d, Endreihe: %d, Bereich: %s\n', startRow, endRow, range);
    
                    d.Value = d.Value + 0.15 * numRows / endRow;
                                    
                    % Überprüfen, ob der Bereich korrekt ist
                    try
                        sheetRange = sheet.Range(range);
                        sheetRange.Value = dataBlock;
                    catch rangeError
                        fprintf('Fehler bei der Bereichsangabe: %s\n', range);
                        rethrow(rangeError);
                    end                
    
                    d.Value = d.Value + 0.15 * numRows / endRow;
                    d.Message = sprintf('Exportiere Zeilen %d bis %d von %d', startRow, endRow, numRows);
                end
                
                % Fortschrittsdialog abschließen
                d.Message = 'Speichern und Schließen der Datei...';
                d.Value = 1.0;
                delete(d);
    
                % Excel-Datei speichern und schließen
                Workbook.SaveAs(fullpath);
                Workbook.Close(false);
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
        uialert(fig, ME.message, 'Fehler beim Exportieren der Daten.')
        disp(ME.message)
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
        uialert(fig, ME.message, 'Fehler beim Konvertieren der Spaltennummer.')
        disp(ME.message)
    end
end

%% Helfer- und Dienstprogramme

function updateTitleAndRef(fig, Value, config, referenceFolder)
    try
        % number neu bestimmen
        number = Value(end);
    
        % Titel anpassen
        title1 = findobj(fig, 'Tag', 'title1');
        newTitle1 = [config.Titel1{1}, number];
        title1.Value = newTitle1;
    
        title2 = findobj(fig, 'Tag', 'title2'); 
        newTitle2 = config.(['Titel2_PK', number]){1};
        title2.Value = newTitle2;
    
        % Neue Referenzdaten einlesen
        refstr = ['PK', number];
        referenceFolder = fullfile(referenceFolder, refstr);
        getReference(referenceFolder, fig);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Updaten von Titel und Referenz.')
        disp(ME.message)
    end
end

function addLabels(x, y, i, color)
    % Diese Funktion fügt Labels zu den Datenpunkten hinzu.
    %
    % Args:
    %    x (array): Array der x-Daten
    %    y (array): Array der y-Daten
    %    i (integer): Index der Datenreihe
    %    color (array): Farbe der Labels
    try
        config = evalin("base", 'config');

        offsets = [ 0.010,  0.010; -0.010, -0.025; -0.010,  0.025;  0.010, -0.045;...   %1-4
                    0.010,  0.040; -0.010, -0.065; -0.010,  0.055;  0.010, -0.085;...   %5-8
                    0.010,  0.070; -0.010, -0.105; -0.010,  0.085;  0.010, -0.125];     %9-12 => bis zu 12 Referenzen gleichzeitig
        for k = 1:length(x)
            label = strrep(num2str(y(k), '%0.3f'), '.', ',');
            t = text(x(k) + offsets(i, 1), y(k) + offsets(i, 2), label, 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'Color', color);
            t.ButtonDownFcn = @(src, event) startDragFcn(src, event, gca);
            t.FontSize = config.LabelFontSize;
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Schreiben der Werte.')
        disp(ME.message)
    end
end

function startDragFcn(src, ~, hAx)
    % Initiale Mausposition speichern und Drag-Funktion setzen. (Verschiebung der Gleichungstexte)
    %
    % Args:
    %    src (text object): Das Textobjekt, das verschoben wird
    %    hAx (axes): Die Achse, auf der sich das Textobjekt befindet
    try
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
    % Aktuelle Mausposition und Verschiebung berechnen und Textposition
    % aktualisieren. (Verschiebung der Gleichungstexte)
    %
    % Args:
    %    src (text object): Das Textobjekt, das verschoben wird
    %    hAx (axes): Die Achse, auf der sich das Textobjekt befindet
    %    initialMousePos (array): Die initiale Mausposition
    %    initialTextPos (array): Die initiale Textposition
    try
        currentMousePos = get(hAx, 'CurrentPoint');
        deltaX = currentMousePos(1, 1) - initialMousePos(1, 1);
        deltaY = currentMousePos(1, 2) - initialTextPos(1, 2);
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
    % Zurücksetzen der WindowButtonMotionFcn und WindowButtonUpFcn. (Verschiebung der Gleichungstexte)
    try
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
        uialert(fig, ME.message, 'Fehler beim Verarbeiten der "Inf"-Inputs.')
        disp(ME.message)
    end
end

function configureAxes(fig)
    % Konfiguriert die Achsen des Plots
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    try
        % config laden
        config = evalin("base", 'config');
        xLim = config.xAchsenLimits;
        yLim = config.yAchsenLimits;
        
        % Titelzeilen einlesen
        t1 = char(findobj(fig, 'Tag', 'title1').Value);
        t2 = char(findobj(fig, 'Tag', 'title2').Value);
        replaceSpecialChars = @(str) regexprep(regexprep(str, '_(?!{)', '\\_'), '\^(?!{)', '\\^');
        t1 = replaceSpecialChars(t1);
        t2 = replaceSpecialChars(t2);
        
        % Anpassung des Plotfensters
        ax = gca;
        ax.XGrid = 'on'; % Aktivieren des X-Gitters
        ax.YGrid = 'on'; % Aktivieren des Y-Gitters
        ax.GridLineStyle = '-'; % Durchgezogene Gitterlinien
        ax.GridColor = [170, 170, 170] / 255; % Gitterfarbe: Grau
        ax.GridAlpha = 0.7; % Transparenz
        ax.XLim = xLim; % X-Achsenlimit setzen
        ax.YLim = yLim; % Y-Achsenlimit setzen
        ax.XAxisLocation = 'origin'; % X-Achse am Ursprung
        ax.YAxisLocation = 'origin'; % Y-Achse am Ursprung
        ax.XColor = ax.GridColor;
        ax.YColor = ax.GridColor;
        
        % Festlegen der X- und Y-Tick-Positionen
        ax.XTick = -20:0.2:20; % X-Ticks alle 0,2 Einheiten
        ax.YTick = -10:0.1:10; % Y-Ticks alle 0,1 Einheiten
        
        % Titel und Achsenbeschriftung hinzufügen
        title(t1, t2);
        ylabel(config.ylabel, 'FontWeight', 'bold');
        xlabel(config.xlabel, 'FontWeight', 'bold');
    
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
    % updateTickLabels passt die Tick-Labels eines Achsenobjekts an.
    % Diese Funktion setzt die Tick-Labels auf Schwarz und ersetzt Punkte durch Kommata.
    %
    % Args:
    %   ax (Achsenobjekt): Achsenobjekt, dessen Tick-Labels angepasst werden sollen.
    try
        % Konvertiere X-Ticks in Strings mit einer Nachkommastelle
        xTickLabels = cellstr(num2str(ax.XTick', '%.1f'));
        
        % Konvertiere Y-Ticks in Strings mit einer Nachkommastelle
        yTickLabels = cellstr(num2str(ax.YTick', '%.1f'));
    
        % Setze die Farbe der X-Tick-Labels auf Schwarz
        for i = 1:length(xTickLabels)
            xTickLabels{i} = ['\color{black}' xTickLabels{i}];
        end
    
        % Setze die Farbe der Y-Tick-Labels auf Schwarz
        for i = 1:length(yTickLabels)
            yTickLabels{i} = ['\color{black}' yTickLabels{i}];
        end
    
        % Ersetze Punkte durch Kommata in den X-Tick-Labels
        xTickLabels = strrep(xTickLabels, '.', ',');
        
        % Ersetze Punkte durch Kommata in den Y-Tick-Labels
        yTickLabels = strrep(yTickLabels, '.', ',');
        
        % Setze die neuen Tick-Labels für die X-Achse
        ax.XTickLabel = xTickLabels;
        
        % Setze die neuen Tick-Labels für die Y-Achse
        ax.YTickLabel = yTickLabels;
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Updaten der Ticklabels.')
        disp(ME.message)
    end
end

function getReference(referenceFolder, fig)
    % Diese Funktion liest die Referenzdaten aus dem angegebenen Ordner ein.
    %
    % Args:
    %    referenceFolder (string): Pfad zum Ordner mit den Referenzdaten
    try
        % Alle .mat Dateien im Referenzordner finden
        matFiles = dir(fullfile(referenceFolder, 'Referenz#*.mat'));
        
        % Initialisierung eines Zellarrays für die Referenzdaten
        referenceDataArray = cell(numel(matFiles), 1);
        
        % Referenzdaten aus den .mat Dateien einlesen
        for i = 1:numel(matFiles)
            loadedData = load(fullfile(referenceFolder, matFiles(i).name));
            
            % Überprüfen, ob die geladene Datei die erwartete Variable enthält
            if isfield(loadedData, 'dataArray')
                referenceDataArray{i} = loadedData.dataArray{1}; % Entferne die zusätzliche Schicht
            else
                warning('Die Datei %s enthält nicht die erwartete Variable "dataArray".', matFiles(i).name);
                uialert(fig, 'Die Datei %s enthält nicht die erwartete Variable "dataArray".', 'Warnung', 'Icon', 'warning')
            end
        end
    
        % Speichern der Referenzdaten im Base Workspace
        assignin("base", 'refFiles', matFiles)
        assignin('base', 'referenceDataArray', referenceDataArray);
        
        % Suche nach der Beispiel-Excel-Datei im Referenzordner und speichere ihren Pfad im Base Workspace
        exampleExcel = dir(fullfile(fileparts(referenceFolder), '*.xlsx'));
        exampleExcelMakro = dir(fullfile(fileparts(referenceFolder), '*.xlsm'));
        if ~isempty(exampleExcel)
            exampleExcelPath = fullfile(fileparts(referenceFolder), exampleExcel(1).name);
            assignin('base', 'exampleExcelPath', exampleExcelPath);
        elseif ~isempty(exampleExcelMakro)
            exampleExcelPath = fullfile(fileparts(referenceFolder), exampleExcelMakro(1).name);
            assignin('base', 'exampleExcelPath', exampleExcelPath);
        else
            exampleExcelPath = fullfile(fileparts(fileparts(fileparts(referenceFolder))), 'Standard export.xlsx');
            assignin('base', 'exampleExcelPath', exampleExcelPath);
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Laden der Referenzdateien.')
        disp(ME.message)
    end
end

function gradient()
    % Diese Funktion erstellt einen Farbverlauf im Plot.
    %
    % Args:
    %    Keine
    try
        % config laden
        config = evalin("base", 'config');
        xLim = config.xAchsenLimits;
        yLim = config.yAchsenLimits;
        
        % Eckpunkte und Grenzen des Farbverlaufs
        xLimits = [xLim(1) - 0.2, xLim(2) + 0.2];
        yLimits = [yLim(1) - 0.1, yLim(2) + 0.1];
        x = [xLimits(1), xLimits(2), xLimits(2), xLimits(1)];
        y = [yLimits(1), yLimits(1), yLimits(2), yLimits(2)];
        
        % Farben für die Eckpunkte (unten links, unten rechts, oben rechts, oben links)
        cdata = [220/255, 220/255, 220/255; 235/255, 235/255, 235/255; 1, 1, 1; 245/255, 245/255, 245/255];
        
        % Patch für den Farbverlauf
        patch(x, y, [1 1 1], 'EdgeColor', 'none', 'FaceVertexCData', cdata, 'FaceColor', 'interp', 'HandleVisibility', 'off');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Fabverlaufs im Plothintergrund.')
        disp(ME.message)
    end
end