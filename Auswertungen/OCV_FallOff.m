%% Setup- und Initialisierungsfunktionen

function OCV_FallOff(referenceFolder)
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
        ocv_config = configData.OCV_FallOff;
        assignin("base", "config", ocv_config)
    
        referenceFolder = fullfile(referenceFolder, 'OCV_FallOff');
        
        % Zugriff auf das bisherige Auswahlfenster aus dem Base Workspace
        fig = evalin('base', 'fig'); 
        fig.Name = 'OCV-FallOff';
        
        % Setup des Fensters mit Buttons, Standardwerten und Textfeldern
        delete(fig.Children);
        createBackButton(fig); 
        setupFigure(fig); 
        createFileSelectionFields(fig, ocv_config)
        createParameterFields(fig); % Definition der Standardwerte und Plot-Button
        createConfigBtn(fig);
        
        % Zeichnen Sie die GUI und warten Sie kurz
        drawnow;
    
        % Hinzufügen der SizeChangedFcn, um die Größenänderung zu behandeln
        fig.SizeChangedFcn = @(src, event) resizeUIComponents(fig);
        fig.AutoResizeChildren = 'off';  % Deaktivieren der automatischen Größenanpassung
    
        % Initiale Größenanpassung auf aktuelle Fenstergröße
        resizeUIComponents(fig);
        
        % Referenzdaten einlesen 
        getReference(referenceFolder);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Öffnen des OCV-Fensters.')
        disp(ME.message)
    end
end

function setupFigure(fig)
    % Hinzufügen eines Textbereichs zum Anzeigen von Informationen
    try
        uitextarea(fig, ...
        'Position', [20, 250, fig.Position(3) / 2 - 30, fig.Position(4) - 260], ...
        'Value', ['Die Auswertungsmethode "OCV-FallOff" wurde ausgewählt:' newline ...
                  ['>> Titel Zeile 1 und 2: Titelanpassung (^{Text} für hochgestellten Text und _{Text} für tiefgestellten ' ...
                  'Text => [\{, \} und \\ um {, } und \ zu schreiben])'] newline ...
                  ['>> Grenzwert [V]: Sobald dieser Wert das erste mal erreicht wird wird ein Index gespeichert (sollte so gewählt werden, dass ' ...
                  'er nie vor dem ersten gesuchten Anstieg erreicht wird)'] newline ...
                  '>>> In config für Referenzdateien getrennt angeben' newline ...
                  ['>> Zeilen vor Grenzwert: Vom zuvor ermittelten Index wird diese Zeilenanzahl abgezogen, um auf die erste Zeile der CSV zu kommen, ' ...
                  'deren Daten dargestellt werden'] newline ...
                  '>> Startzeile manuell: Falls die erste Zeile, deren Daten zu sehen sein sollen bekannt ist, kann diese hier angegeben werden' newline ...
                  '>> Startzeile manuell angeben: Auswählen, wenn "Startzeile manuell" genutzt werden soll' newline ...
                  '>>> In config für Referenzdateien getrennt angeben' newline ...
                  '>> Referenzdaten anzeigen: Falls diese Checkbox gewählt wird, werden die Referenzdaten im Plot angezeigt' newline ...
                  '>> DUT anzeigen: Falls diese Checkbox gewählt wird, werden die DUT-Daten im Plot angezeigt' newline ...
                  '>> x-Achsen Min & Max: Die eingegebenen Zalen werden als x-Achsenlimits genommen ("auto" angeben um xMin = Startzeile und xMax 2900 ' ...
                  'Zeilen danach zu setzen, "last" angeben, um die letzte Zeile als Grenze zu setzen) (Falls xMin ≥ xMax => automatisch: xMin = xMax - 1)' newline ...
                  newline ...
                  'Erst "Neue Datei laden" dann "Plotten"'], ...
        'Tag', 'infoText');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Infotextes.')
        disp(ME.message)
    end
end

function createConfigBtn(fig)
    try
        uibutton(fig, 'Text', 'OCV-FallOff config', 'Position', [fig.Position(3) - 150, fig.Position(4) - 32, 130, 22], ...
            'ButtonPushedFcn', @(btn, event) runMethodScript('OCV_FallOff'), 'Tag', 'configButton');
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
            fig = findall(0, 'Type', 'figure', 'Name', 'OCV-FallOff Einstellungen'); 

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
        currentRef = evalin("base", 'referenceFolder');

        configFile = fullfile(currentRef, 'config.json');
        fid = fopen(configFile, 'r');
        jsonData = fscanf(fid, '%c');
        fclose(fid);
        configData = jsondecode(jsonData);
        ocv_config = configData.OCV_FallOff;
        assignin("base", "config", ocv_config)
        
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

function createFileSelectionFields(fig, config)
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
            'Multiselect', 'off', 'Items', {});
    
        % Datei-Button hinzufügen
        uibutton(fig, 'push', 'Text', 'Neue Datei laden', 'Position', [load_data_btn_x, load_data_btn_y, load_data_btn_width, load_data_btn_height], ...
            'ButtonPushedFcn', @(btn, event) addFiles(fig, config), 'Tag', 'Neue Dateien');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Dateiauswahlfeldes.')
        disp(ME.message)
    end
end

function addFiles(fig, config)
    % Funktion zum Hinzufügen von Dateien zur Liste
    try
        try
            [data, fileNames] = DataWrapper(config);
        catch
            return
        end
    
        fileList = findobj(fig, 'Tag', 'fileList');

        for i = 1:length(fileNames)
            addFileToList(fileList, fileNames{i}, data{i}, length(fileList.Items) + 1)
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

function createBackButton(fig)
    % Erzeugt einen Zurück-Button, um zur Auswahl zurückzukehren
    try
        back_btn_width = 200;
        back_btn_height = 50;
        back_btn_x = (fig.Position(3) / 2) + 120;
        back_btn_y = 10;
    
        % Erstelle den Zurück-Button
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

function createParameterFields(fig)
    try
        % config laden
        config = evalin("base", 'config');
        
        % Definition der Standardwerte
        defaultTitle1 = config.Titel1;
        defaultTitle2 = config.Titel2;
        defaultGrenzwert = config.Grenzwert;
        defaultAbstand = config.ZeilenVorGrenzwert;
        defaultStartwertanpassung = config.StartManuell;
        defaultxMin = config.xMin;
        defaultxMax = config.xMax;
    
        showReference = config.checkRef;
        showDUT = config.checkDUT;
        manuell = config.checkStartManuell;
        
        % Plot-Button Parameter
        plot_btn_width = 200;
        plot_btn_height = 50;
        plot_btn_x = (fig.Position(3) / 2) - 100;
        plot_btn_y = 10;
    
        % Textfelder hinzufügen um Standardwerte anzeigen und anpassen zu können
        % Titel:
        uilabel(fig, 'Position', [20, 215, 100, 22], 'Text', 'Titel Zeile 1:', 'Tag', 'title1Label'); 
        uieditfield(fig, 'text', 'Position', [120, 215, fig.Position(3) - 140, 22], 'Value', defaultTitle1{1}, 'Tag', 'title1');
    
        uilabel(fig, 'Position', [20, 175, 100, 22], 'Text', 'Titel Zeile 2:', 'Tag', 'title2Label');
        uieditfield(fig, 'text', 'Position', [120, 175, fig.Position(3) - 140, 22], 'Value', defaultTitle2{1}, 'Tag', 'title2');
        
        % xy-Bereich:
        label_width = 120;
        text_width = 50;
    
        uilabel(fig, 'Position', [20, 125, label_width, 22], 'Text', 'Grenzwert [V]:', 'Tag', 'GrenzwertLabel');
        uieditfield(fig, 'numeric', 'Position', [220 - text_width, 125, text_width, 22], 'Value', defaultGrenzwert, 'Tag', 'Grenzwert');
    
        uilabel(fig, 'Position', [240, 125, 150, 22], 'Text', 'Zeilen vor Grenzwert:', 'Tag', 'AbstandLabel');
        uieditfield(fig, 'numeric', 'Position', [440 - text_width, 125, text_width, 22], 'Value', defaultAbstand, 'Tag', 'Abstand');
    
        uilabel(fig, 'Position', [20, 85, label_width, 22], 'Text', 'Startzeile manuell:', 'Tag', 'StartwertLabel');
        uieditfield(fig, 'numeric', 'Position', [220 - text_width, 85, text_width, 22], 'Value', defaultStartwertanpassung, 'Tag', 'Startwert');
    
        % Neue Eingabefelder für x-Achsenlimits
        uilabel(fig, 'Position', [680, 125, label_width, 22], 'Text', 'x-Achsen Min:', 'Tag', 'xMinLabel');
        uieditfield(fig, 'text', 'Position', [880 - text_width, 125, text_width, 22], 'Value', defaultxMin{1}, 'Tag', 'xMin');
    
        uilabel(fig, 'Position', [680, 85, 150, 22], 'Text', 'x-Achsen Max:', 'Tag', 'xMaxLabel');
        uieditfield(fig, 'text', 'Position', [880 - text_width, 85, text_width, 22], 'Value', defaultxMax{1}, 'Tag', 'xMax');
    
        % Tooltips hinzufügen
        uilabel(fig, 'Position', [680, 65, 300, 22], 'Text', 'Geben Sie eine Zahl, "last" oder "auto" ein.', 'FontSize', 10, 'FontColor', [0.5 0.5 0.5], 'Tag', 'Tooltip1');
        uilabel(fig, 'Position', [100, 65, 300, 22], 'Text', 'Zeile bezieht sich jeweils auf die Zeile in der CSV-Datei.', 'FontSize', 10, 'FontColor', [0.5 0.5 0.5], 'Tag', 'Tooltip2');
    
        % Checkboxen ob Referenzdaten und DUT angezeigt werden sollen
        uicheckbox(fig, ...
            'Text', 'Referenzdaten anzeigen', ...
            'Position', [460, 125, 200, 22], ...
            'Value', showReference, ...
            'Tag', 'showReference');
    
        uicheckbox(fig, ...
            'Text', 'DUT anzeigen', ...
            'Position', [460, 85, 200, 22], ...
            'Value', showDUT, ...
            'Tag', 'showDUT');
    
        uicheckbox(fig, ...
            'Text', 'Startzeile manuell angeben?', ...
            'Position', [240, 85, 200, 22], ...
            'Value', manuell, ...
            'Tag', 'manuell');
    
        % Plot Button
        uibutton(fig, 'push', ...
            'Text', 'Plotten', ...
            'Tag', 'plotButton', ...
            'Position', [plot_btn_x, plot_btn_y, plot_btn_width, plot_btn_height], ...
            'ButtonPushedFcn', @(btn, event) plotDataWrapper(fig)); % Plot Button ruft plotDataWrapper auf
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
        resizeComponent(fig, 'infoText',            [margin,                    250 * heightScaleFactor,    420 * widthScaleFactor,     365 * heightScaleFactor])
        resizeComponent(fig, 'fileListLabel',       [460 * widthScaleFactor,    588 * heightScaleFactor,    120 * widthScaleFactor,      27 * heightScaleFactor])
        resizeComponent(fig, 'fileList',            [460 * widthScaleFactor,    250 * heightScaleFactor,    420 * widthScaleFactor,     340 * heightScaleFactor])
        resizeComponent(fig, 'configButton',        [750 * widthScaleFactor,    593 * heightScaleFactor,    130 * widthScaleFactor,     height])
    
        % Titelzeilen
        resizeComponent(fig, 'title1Label',         [margin,                    215 * heightScaleFactor,    100 * widthScaleFactor,     height])
        resizeComponent(fig, 'title1',              [120 * widthScaleFactor,    215 * heightScaleFactor,    760 * widthScaleFactor,     height])
        resizeComponent(fig, 'title2Label',         [margin,                    175 * heightScaleFactor,    100 * widthScaleFactor,     height])
        resizeComponent(fig, 'title2',              [120 * widthScaleFactor,    175 * heightScaleFactor,    760 * widthScaleFactor,     height])
    
        % Parameterfelder
        resizeComponent(fig, 'GrenzwertLabel',      [margin,                    125 * heightScaleFactor,    120 * widthScaleFactor,     height]);
        resizeComponent(fig, 'Grenzwert',           [170 * widthScaleFactor,    125 * heightScaleFactor,     50 * widthScaleFactor,     height]);
        resizeComponent(fig, 'AbstandLabel',        [240 * widthScaleFactor,    125 * heightScaleFactor,    150 * widthScaleFactor,     height]);
        resizeComponent(fig, 'Abstand',             [390 * widthScaleFactor,    125 * heightScaleFactor,     50 * widthScaleFactor,     height]);
        resizeComponent(fig, 'StartwertLabel',      [margin,                     85 * heightScaleFactor,    120 * widthScaleFactor,     height]);
        resizeComponent(fig, 'Startwert',           [170 * widthScaleFactor,     85 * heightScaleFactor,     50 * widthScaleFactor,     height]);
        resizeComponent(fig, 'xMinLabel',           [680 * widthScaleFactor,    125 * heightScaleFactor,    120 * widthScaleFactor,     height]);
        resizeComponent(fig, 'xMin',                [830 * widthScaleFactor,    125 * heightScaleFactor,     50 * widthScaleFactor,     height]);
        resizeComponent(fig, 'xMaxLabel',           [680 * widthScaleFactor,     85 * heightScaleFactor,    150 * widthScaleFactor,     height]);
        resizeComponent(fig, 'xMax',                [830 * widthScaleFactor,     85 * heightScaleFactor,     50 * widthScaleFactor,     height]);
        resizeComponent(fig, 'Tooltip1',            [680 * widthScaleFactor,     65 * heightScaleFactor,    300 * widthScaleFactor,     height]);
        resizeComponent(fig, 'Tooltip2',            [100 * widthScaleFactor,     65 * heightScaleFactor,    300 * widthScaleFactor,     height]);
    
        % Checkboxen
        btn_width = 200 * widthScaleFactor;
        resizeComponent(fig, 'showReference',       [460 * widthScaleFactor,    125 * heightScaleFactor,    btn_width,                  height]);
        resizeComponent(fig, 'showDUT',             [460 * widthScaleFactor,     85 * heightScaleFactor,    btn_width,                  height]);
        resizeComponent(fig, 'manuell',             [240 * widthScaleFactor,     85 * heightScaleFactor,    btn_width,                  height]);
    
        % Buttons
        btn_y = 10 * heightScaleFactor;
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

%% Datenverarbeitungsfunktionen

function plotData(data, fig, showReference, showDUT, manuell, referenceDataArray, d)
    try
        % config laden
        config = evalin("base", 'config');
    
        % Datenbereiche und Titel aus den Textfeldern lesen
        Abstand = findobj(fig, 'Tag', 'Abstand').Value;
        startwertArray = [];    % Array für Startwerte initialisieren
        t1 = char(findobj(fig, 'Tag', 'title1').Value);     % Titelzeilen einlesen 
        t2 = char(findobj(fig, 'Tag', 'title2').Value);
        replaceSpecialChars = @(str) regexprep(regexprep(str, '_(?!{)', '\\_'), '\^(?!{)', '\\^');
        t1 = replaceSpecialChars(t1);
        t2 = replaceSpecialChars(t2);
    
        d.Value = 0.3;
    
        if manuell && showDUT   % Startwert für DUT, wenn nötig einlesen/ermitteln
            startwertArray(end+1) = findobj(fig, 'Tag', 'Startwert').Value;
        elseif showDUT
            startwertArray(end+1) = findStart(data, fig, 0, config) - Abstand;
        end
    
        if showReference    % Startwerte für Referenz, wenn nötig ermitteln
            for i = 1:length(referenceDataArray)
                if config.RefStartzeileNutzen(i)
                    startwertArray(end+1) = config.RefStartzeile(i); %#ok<AGROW> 
                else
                    startwertArray(end+1) = findStart(referenceDataArray{i}, fig, i, config) - Abstand; %#ok<AGROW> 
                end
            end
        end
    
        xMinInput = char(findobj(fig, 'Tag', 'xMin').Value);
        xMaxInput = char(findobj(fig, 'Tag', 'xMax').Value);
        
        % Debugging-Informationen
        fprintf('Datenlänge: %d\n', length(data));
    
        d.Value = 0.4;
    
        % Validierung und Verarbeitung der x-Achsenlimits
        if showDUT
            dataLength = length(data);
        elseif showReference
            dataLength = length(referenceDataArray{1});
        end
        [xMin, xMax, errMsg] = processXAxisLimits(xMinInput, xMaxInput, dataLength, startwertArray(1), Abstand);
    
        if ~isempty(errMsg)
            info_text = findobj(fig, 'Tag', 'infoText');
            info_text.Value = [info_text.Value; {errMsg}];
            return;
        end
    
        lineWidth = config.lineWidth;
    
        d.Value = 0.5;
    
        % Plotten der Messdaten
        plotting(data, referenceDataArray, startwertArray, 'b', t1, t2, lineWidth, 0.1, showReference, showDUT, xMin, xMax, d);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des gesamten Plots.')
        disp(ME.message)
    end
end

function plotting(data, refData, startwertArray, color, t1, t2, lineWidth, alpha, showReference, showDUT, xMin, xMax, d)
    % Erstellen eines Plots mit: y = y-Daten; refData = Referenzdaten; 
    % startwertArray = Startwerte; color = Farbe des Plots (Ref immer grau); 
    % t1, t2 = 1. und 2. Titelzeile; 
    % lineWidth = LinienBreite des Plot (Ref immer 3*linewidth); 
    % alpha = Transparenz der Referenzdaten und Bereichsrechtecke (0 = unsichtbar, 1 = grau); 
    % showReference = sollen Referenzdaten gezeigt werden?
    % showDUT = sollen DUT-Daten gezeigt werden?
    try
        % config laden
        config = evalin("base", 'config');
    
        refcolor = [0.01, 0.01, 0.01]*alpha + [1, 1, 1]*(1-alpha);  % Referenzgrau mit Transparenz festlegen
    
        % Erstellung des Plotfensters
        figure('Units', 'normalized', 'OuterPosition', [0 0 1 1]);
        hold on;    % Erlaube weitere Plots im Fenster
    
        d.Value = 0.6;
    
        if showDUT %&& strcmp(xMinInput, 'auto') 
            plotDUTBackground(alpha);   % Bereichsrechtecke zeichnen
        end
    
        if showReference && ~isempty(refData)
            plotReferenceData(refData, startwertArray, lineWidth, refcolor, showDUT);   % Referenzdaten plotten
        end
    
        d.Value = 0.7;
    
        if showDUT 
            xArray = (1:length(data)) - startwertArray(1);
            plot(xArray, data, '-', 'MarkerFaceColor', 'auto', 'MarkerSize', lineWidth^2, 'Color', color, 'LineWidth', lineWidth, 'DisplayName', 'DUT','Marker','.');
        end
    
        d.Value = 0.8;
    
        % Titel und Achsenbeschriftung
        title(t1, t2);
        ylabel(config.ylabel, 'FontWeight', 'bold');
        xlabel(config.xlabel, 'FontWeight', 'bold');
        grid on;
        configureAxes(xMin, xMax, startwertArray(1));    % Plotfenster konfigurieren
        l = legend('Location', 'northeast');    % Hinzufügen einer Legende
        l.FontSize = config.legendFontSize;
    
        d.Value = 1;
        close(d)
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Plotten.')
        disp(ME.message)
    end
end

function plotReferenceData(refData, startwertArray, lineWidth, refcolor, showDUT)
    try
        % Plot the reference data
        if ~showDUT     % Falls DUT nicht gezeigt wird, bunte normaldicke Linien
            colors = jet(length(refData));
            for i = 1:length(refData)
                refName = sprintf('Referenz#%d', i);
                xArray = (1:length(refData{i})) - startwertArray(i);
                plot(xArray, refData{i},'-o', 'Color', colors(i, :), 'MarkerFaceColor', colors(i, :), 'MarkerSize', lineWidth/13, 'LineWidth', lineWidth, 'DisplayName', refName);
            end
        else            % Falls DUT gezeigt wird, graue dicke Linien
            for i = 1:length(refData)
                %y = refData{i}(startwertArray(i):end);
                xArray = (1:length(refData{i})) - startwertArray(i+1);
                plot(xArray, refData{i}, '.-', 'MarkerFaceColor', 'auto', 'MarkerSize', lineWidth*(4)*3.5, 'LineWidth', lineWidth * 4, 'Color', refcolor, 'HandleVisibility', 'off');
            end
            plot(nan, '-', 'MarkerFaceColor', 'auto', 'MarkerSize', lineWidth*(4)*3, 'LineWidth', lineWidth * 4,...
                    'Color', refcolor, 'DisplayName', 'Referenz', 'Marker', '.');
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Plotten der Referenzdaten.')
        disp(ME.message)
    end
end

function index = findStart(data, fig, num, config)
    try
        % Findet den Startindex, bei dem die Daten einen Grenzwert überschreiten
        if num == 0
            Grenzwert = findobj(fig, 'Tag', 'Grenzwert').Value;
        else
            Grenzwerte = config.RefGrenzenwerte;
            Grenzwert = Grenzwerte(num);
        end
        index = find(data > Grenzwert, 1);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Finden des Grenzwertindex.')
        disp(ME.message)
    end
end

%% Helfer- und Dienstprogramme

function plotDUTBackground(alpha)
    try
        % Plot the background for DUT
        fig = gcf;
    
        % config laden
        config = evalin("base", 'config');
        h2n2Limits = config.H2N2Grenzen;
        ocvLimits = config.OCVGrenzen;
        fallOffLimits = config.FallOffGrenzen;
        yLim = config.yAchsenLimits;
        
        % Rechtecke erstellen
        rect1 = rectangle('Position', [h2n2Limits(1), yLim(1), h2n2Limits(2) - h2n2Limits(1), yLim(2)], ...
            'FaceColor', [190/255, 152/255, 9/255]*alpha + [1, 1, 1]*(1-alpha), 'EdgeColor', 'none', 'ButtonDownFcn', @startDragFcn);
        rect2 = rectangle('Position', [ocvLimits(1), yLim(1), ocvLimits(2) - ocvLimits(1), yLim(2)], ...
            'FaceColor', [61/255, 106/255, 60/255]*alpha + [1, 1, 1]*(1-alpha), 'EdgeColor', 'none', 'ButtonDownFcn', @startDragFcn);
        rect3 = rectangle('Position', [fallOffLimits(1), yLim(1), fallOffLimits(2) - fallOffLimits(1), yLim(2)], ...
            'FaceColor', [173/255, 185/255, 206/255]*alpha + [1, 1, 1]*(1-alpha), 'EdgeColor', 'none', 'ButtonDownFcn', @startDragFcn);
    
        % Texte erstellen
        text1 = text(h2n2Limits(1) + (h2n2Limits(2) - h2n2Limits(1))/2, yLim(2), 'H_2/N_2 (Kurzschluss)', 'VerticalAlignment', 'top', ...
            'HorizontalAlignment', 'center', 'Color', 'k', 'FontSize', config.H2N2TextSize);
        text2 = text(ocvLimits(1) + (ocvLimits(2) - ocvLimits(1))/2, yLim(2), 'OCV', 'VerticalAlignment', 'top', ...
            'HorizontalAlignment', 'center', 'Color', 'k', 'FontSize', config.OCVTextSize);
        text3 = text(fallOffLimits(1) + (fallOffLimits(2) - fallOffLimits(1))/2, yLim(2), 'FallOff', 'VerticalAlignment', 'top', ...
            'HorizontalAlignment', 'center', 'Color', 'k', 'FontSize', config.FallOffTextSize);
    
        % Daten aller Rechtecke und Texte speichern
        data.rects = [rect1, rect2, rect3];
        data.texts = [text1, text2, text3];
        data.currentRect = [];
        data.currentText = [];
        
        % Benutzerdaten für das Plotfenster speichern
        set(fig, 'UserData', data);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen der Bereichsmarkierungen.')
        disp(ME.message)
    end
    
        % Callback-Funktionen definieren
        function startDragFcn(hObject, ~)
            try
                figData = get(fig, 'UserData');
                idx = find(figData.rects == hObject);
                figData.currentRect = figData.rects(idx);
                figData.currentText = figData.texts(idx);
                set(fig, 'UserData', figData);
                set(fig, 'WindowButtonMotionFcn', @draggingFcn);
                set(fig, 'WindowButtonUpFcn', @stopDragFcn);
            catch ME
                figure = uifigure();
                uialert(figure, ME.message, 'Fehler beim Verschieben der Markierung (1).')
                disp(ME.message)
            end
        end
    
        function draggingFcn(~, ~)
            try
                figData = get(gcf, 'UserData');
                currentPoint = get(gca, 'CurrentPoint');
                cpX = currentPoint(1, 1);
                
                % Verschieben des Rechtecks und Textes
                pos = get(figData.currentRect, 'Position');
                pos(1) = cpX - pos(3) / 2; % Berechnung der neuen x-Position
                set(figData.currentRect, 'Position', pos);
                set(figData.currentText, 'Position', [pos(1) + pos(3)/2, pos(2) + pos(4)]);
            catch ME
                figure = uifigure();
                uialert(figure, ME.message, 'Fehler beim Verschieben der Markierung (2).')
                disp(ME.message)
            end
        end
    
        function stopDragFcn(~, ~)
            try
                set(fig, 'WindowButtonMotionFcn', '');
                set(fig, 'WindowButtonUpFcn', '');
            catch ME
                figure = uifigure();
                uialert(figure, ME.message, 'Fehler beim Verschieben der Markierung (3).')
                disp(ME.message)
            end
        end
end

function configureAxes(xMin, xMax, StartWert)
    try
        % config laden
        config = evalin("base", 'config');
        yLim = config.yAchsenLimits;
    
        % Anpassung des Plotfensters
        ax = gca;
        ax.XGrid = 'on'; % Aktivieren des X-Gitters
        ax.YGrid = 'on'; % Aktivieren des Y-Gitters
        ax.GridLineStyle = '-'; % Durchgezogene Gitterlinien
        ax.GridColor = [0.5, 0.5, 0.5]; % Gitterfarbe: Grau
        ax.GridAlpha = 0.7; % Transparenz
        
        xMax = xMax - (StartWert);
        xMin = xMin - (StartWert);
    
        if xMax <= xMin
            xMin = xMax - 1;
        end
    
        ax.XLim = [xMin, xMax]; % X-Achsenlimit setzen
        ax.YLim = yLim; % Y-Achsenlimit setzen
        ax.Layer = 'top'; % Achsenbeschriftungen und Gitterlinien oben
        ax.ClippingStyle = 'rectangle'; % Clipping anpassen
        % Achsenbeschriftungen 
        ax.XTick = [];
        updateYTickLabels(ax);
        ax.YAxis.FontSize = config.yTickSize;
    
        % Listener hinzufügen, um die Y-Achsenbeschriftungen zu aktualisieren, wenn sich die YLim ändert
        addlistener(ax, 'YLim', 'PostSet', @(src, event) updateYTickLabels(ax));
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim .')
        disp(ME.message)
    end
end

function updateYTickLabels(ax)
    try
        ax.YTickLabel = strrep(cellstr(num2str(ax.YTick')), '.', ',');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Updaten der YTicks.')
        disp(ME.message)
    end
end

function getReference(referenceFolder)
    try
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
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Laden der Referenzdateien.')
        disp(ME.message)
    end
end

function [xMin, xMax, errMsg] = processXAxisLimits(xMinInput, xMaxInput, dataLength, startIndex, Abstand)
    try
        % config laden
        config = evalin("base", 'config');
        defaultEnde = config.Darstellungslaenge;
        defaultAbstand = config.ZeilenVorGrenzwert;
    
        % Initialisieren
        xMin = 1;
        xMax = defaultEnde - defaultAbstand; 
        errMsg = '';
    
        % Verarbeitung der x-Achsenlimits
        if strcmp(xMinInput, 'auto') || isempty(xMinInput)
            xMin = max(xMin, startIndex - Abstand);
        elseif strcmp(xMinInput, 'last')
            xMin = dataLength;
        else
            xMin = str2double(xMinInput);
            if isnan(xMin)
                xMin = 1;
            end
        end
    
        if strcmp(xMaxInput, 'auto')
            xMax = min(dataLength, startIndex + xMax);
        elseif strcmp(xMaxInput, 'last')
            xMax = dataLength;
        else
            xMax = str2double(xMaxInput);
            if isnan(xMax) || xMax > dataLength
                xMax = dataLength;
                if isempty(errMsg)
                    errMsg = 'Bitte ''last'' für den letzten Wert eingeben oder ''auto'' für automatische Grenzwerte nutzen.';
                else
                    errMsg = [errMsg, ' Bitte ''last'' für den letzten Wert eingeben oder ''auto'' für automatische Grenzwerte nutzen.'];
                end
            end
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Verarbeiten der Achsenlimits.')
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
        uialert(fig, ME.message, 'Fehler beim Verarbeiten von "Inf"-Eingaben.')
        disp(ME.message)
    end
end

%% Eingabe-/Ausgabefunktionen

function [dataArrays, fileNames] = DataWrapper(config) 
    try
        lines = config.Zeilen;
        columns = config.Spalten;
        lines = processInf(lines);
        columns = processInf(columns);
        
        % Einlesen der Daten
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
        [dataArrays, header] = read_csv(dataFiles, lines, columns);
        for i = 1:length(dataArrays)
            dataArrays{i} = cell2mat(dataArrays{i}(header+1:end));
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Verarbeiten der Dateien.')
        disp(ME.message)
    end
end

function plotDataWrapper(fig)
    try
        % Einlesen der Checkbox-Zustände
        showReference = findobj(fig, 'Tag', 'showReference').Value;
        showDUT = findobj(fig, 'Tag', 'showDUT').Value;
        manuell = findobj(fig, 'Tag', 'manuell').Value;
    
        % Wenn keine Checkbox ausgewählt ist, zeige eine Meldung an
        if ~showReference && ~showDUT
            return;
        end

        d = uiprogressdlg(fig,'Title','Bitte Warten',...
            'Message','Plot wird erstellt');
        fileList = findobj(fig, 'Tag', 'fileList');
        
        d.Value = 0.1;
    
        % Initialisiere leere Daten
        data = [];
        referenceDataArray = [];
    
        % Wenn die DUT-Checkbox ausgewählt ist
        if showDUT
            data = fileList.Value;
            if isempty(data)
                try
                    data = fileList.ItemsData{1};
                catch
                    uialert(fig, 'Bitte mindestens eine Datei laden.', 'Warnung', 'Icon', 'warning')
                    return
                end
            end
        end
    
        d.Value = 0.2;
    
        % Wenn die Referenzdaten-Checkbox ausgewählt ist
        if showReference
            referenceDataArray = evalin('base', 'referenceDataArray');
            for i = 1:length(referenceDataArray)
                referenceDataArray{i} = cell2mat(referenceDataArray{i});
            end
        end
        
        % Plot-Daten vorbereiten
        plotData(data, fig, showReference, showDUT, manuell, referenceDataArray, d);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Plots.')
        disp(ME.message)
    end
end