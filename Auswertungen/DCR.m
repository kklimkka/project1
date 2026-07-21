%% Setup- und Initialisierungsfunktionen

function DCR(referenceFolder)
    % Hauptfunktion, die den gesamten Ablauf steuert
    %
    % Args:
    %    referenceFolder (string): Pfad zum Referenzordner
    %
    % Diese Funktion lädt die Konfiguration aus der config.json Datei, 
    % initialisiert die GUI und liest die Referenzdaten ein.
    try
        % Abruf der config.json und vervollständigen des Pfades zum Referenzordner
        currentRef = referenceFolder;
        assignin("base", "currentRef", currentRef)
        configFile = fullfile(currentRef, 'config.json');
        fid = fopen(configFile, 'r');
        jsonData = fscanf(fid, '%c');
        fclose(fid);
        configData = jsondecode(jsonData);
        dcr_config = configData.DCR;
        assignin("base", "config", dcr_config)

        referenceFolder = fullfile(referenceFolder, 'DCR');

        % Zugriff auf 'fig' aus dem Base Workspace
        fig = evalin('base', 'fig'); 
        fig.Name = 'DCR';

        % Setup von 'fig' mit Buttons, Standardwerten und Textfeldern
        delete(fig.Children);
        createBackButton(fig); 
        setupFigure(fig); 
        createFileSelectionFields(fig);
        createParameterFields(fig);     % Definition der Standardwerte und Plot-Button
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
        assignin('base', 'refFiles', matFiles);
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
        uialert(fig, ME.message, 'Fehler beim Öffnen des DCR-Fensters')
        disp(ME.message)
    end
end

function createConfigBtn(fig)
    try
        uibutton(fig, 'Text', 'DCR config', 'Position', [fig.Position(3) - 150, fig.Position(4) - 32, 130, 22], ...
            'ButtonPushedFcn', @(btn, event) runMethodScript('DCR'), 'Tag', 'configButton');
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
            fig = findall(0, 'Type', 'figure', 'Name', 'DCR Einstellungen'); 

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
        dcr_config = configData.DCR;
        assignin("base", "config", dcr_config)
        
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
    % Leeren von 'fig'
    %
    % Args:
    %    fig (Figure): Das GUI-Fenster
    %
    % Diese Funktion initialisiert das GUI-Fenster, indem sie alle Kinder 
    % Elemente löscht und ein Textbereich hinzufügt, um Informationen anzuzeigen.
    try
        % Hinzufügen eines Textbereichs zum Anzeigen von Informationen
        uitextarea(fig, ...
            'Position', [20, 250, fig.Position(3)/2 - 30, fig.Position(4) - 260], ...
            'Value', ['Die Auswertungsmethode "DCR" wurde ausgewählt:' newline ...
                  ['>> Titel Zeile 1 und 2: Titelanpassung (^{Text} für hochgestellten Text und _{Text} für tiefgestellten ' ...
                  'Text => [\{, \} und \\ um {, } und \ zu schreiben])'] newline ...
                  '>> xyUnten/xyOben Start/Ende: Zeilen der Messdatei mit den Start- und Endwerte der oberen und unteren Fitgerade zur DCR-Berechnung' newline ...
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
        uitextarea(fig, "Value", 'Dateiauswahl:', 'Position', [fig.Position(3)/2 + 0.5 * margin, fig.Position(4) - 37, 120, 27], 'FontSize', 17.5, ...
            'Tag', 'fileListLabel', 'Editable', 'off', 'BackgroundColor', fig.Color);
        uilistbox(fig, 'Position', [fig.Position(3)/2 + 0.5 * margin, 250, fig.Position(3)/2 - 30, fig.Position(4) - 285], 'Tag', 'fileList', ...
            'Multiselect', 'on', 'Items', {});
    
        % Datei-Button hinzufügen
        uibutton(fig, 'push', 'Text', 'Neue Datei laden', 'Position', [load_data_btn_x, load_data_btn_y, load_data_btn_width, ...
            load_data_btn_height], 'ButtonPushedFcn', @(btn, event) addFiles(fig), 'Tag', 'Neue Dateien');
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
            [data, fileNames] = DataWrapper(fig);
        catch
            return
        end

        if isequal(fileNames, 0)
            return
        end

        fileList = findobj(fig, 'Tag', 'fileList');
        try
            for i = 1:length(fileNames)
                fileName = fileNames{i};
                addFileToList(fileList, fileName, data{i}, length(fileList.Items) + 1)
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

function createBackButton(fig)
    % Erstellt den Zurück-Button
    %
    % Args:
    %    fig (Figure): Das GUI-Fenster
    %
    % Diese Funktion erstellt und positioniert den Zurück-Button im GUI-Fenster.
    try
        % Zurück-Button Position
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
    % Erstellt die Parameterfelder und den Plot-Button
    %
    % Args:
    %    fig (Figure): Das GUI-Fenster
    %
    % Diese Funktion erstellt Textfelder zur Eingabe von Parametern und 
    % Checkboxen zur Auswahl der anzuzeigenden Daten sowie den Plot-Button.
    try
        % config laden
        config = evalin("base", 'config');
    
        % Definition der Standardwerte
        defaultTitle1 = config.Titel1;
        defaultTitle2 = config.Titel2;
        defaultXYUntenStart = config.xyUntenStart;
        defaultXYUntenEnd = config.xyUntenEnde;
        defaultXYObenStart = config.xyObenStart;
        defaultXYObenEnd = config.xyObenEnde;
        showReference = config.checkRef;
        showDUT = config.checkDUT;
        
        % Plot-Button Parameter
        plot_btn_width = 200;
        plot_btn_height = 50;
        plot_btn_x = (fig.Position(3) / 2) - plot_btn_width / 2;
        plot_btn_y = 10;
    
        % Textfelder hinzufügen um Standardwerte anzeigen und anpassen zu können
        % Titel:
        uilabel(fig, 'Position', [20, 215, 100, 22], 'Text', 'Titel Zeile 1:', 'Tag', 'title1label'); 
        uieditfield(fig, 'text', 'Position', [100, 215, fig.Position(3) - 300, 22], 'Value', defaultTitle1{1}, 'Tag', 'title1');
    
        uilabel(fig, 'Position', [20, 175, 100, 22], 'Text', 'Titel Zeile 2:', 'Tag', 'title2label');
        uieditfield(fig, 'text', 'Position', [100, 175, fig.Position(3) - 120, 22], 'Value', defaultTitle2{1}, 'Tag', 'title2');
        
        % xy-Bereich:
        label_width = 120;
        text_width = 100;
    
        uilabel(fig, 'Position', [(fig.Position(3) / 2) - (200) - 120 , 125, label_width, 22], 'Text', 'xyUnten Start:', 'Tag', 'xyUntenStartLabel');
        uieditfield(fig, 'numeric', 'Position', [(fig.Position(3) / 2) - (200) - 120 + 120, 125, text_width, 22], 'Value', defaultXYUntenStart, ...
            'Tag', 'xyUntenStart');
    
        uilabel(fig, 'Position', [(fig.Position(3) / 2) - 100, 125, label_width, 22], 'Text', 'xyUnten Ende:', 'Tag', 'xyUntenEndLabel');
        uieditfield(fig, 'numeric', 'Position', [(fig.Position(3) / 2) - 100 + 120, 125, text_width, 22], 'Value', defaultXYUntenEnd, ...
            'Tag', 'xyUntenEnd');
    
        uilabel(fig, 'Position', [(fig.Position(3) / 2) - (200) - 120, 85, label_width, 22], 'Text', 'xyOben Start:', 'Tag', 'xyObenStartLabel');
        uieditfield(fig, 'numeric', 'Position', [(fig.Position(3) / 2) - (200) - 120 + 120, 85, text_width, 22], 'Value', defaultXYObenStart, ...
            'Tag', 'xyObenStart');
    
        uilabel(fig, 'Position', [(fig.Position(3) / 2) - 100, 85, label_width, 22], 'Text', 'xyOben Ende:', 'Tag', 'xyObenEndLabel');
        uieditfield(fig, 'numeric', 'Position', [(fig.Position(3) / 2) - 100 + 120, 85, text_width, 22], 'Value', defaultXYObenEnd, ...
            'Tag', 'xyObenEnd');
    
        % Ergebnisfeld
        uilabel(fig, 'Position', [fig.Position(3) - 190, 215, label_width, 22], 'Text', 'Widerstand [Ω]:', 'Tag', 'resistanceLabel');
        uieditfield(fig, 'text', 'Position', [fig.Position(3) - 80, 215, 60, 22], 'Value', '', 'Tag', 'resistance', 'Editable', 'off');
    
        % Checkboxen ob Referenzdaten und DUT angezeigt werden sollen
        uicheckbox(fig, ...
            'Text', 'Referenzdaten anzeigen', ...
            'Position', [(fig.Position(3) / 2) + 120, 125, 200, 22], ...
            'Value', showReference, ...
            'Tag', 'showReference');
        
        uicheckbox(fig, ...
            'Text', 'DUT anzeigen', ...
            'Position', [(fig.Position(3) / 2) + 120, 85, 200, 22], ...
            'Value', showDUT, ...
            'Tag', 'showDUT');
        
        % Plot Button
        uibutton(fig, 'push', ...
            'Text', 'Plotten', ...
            'Position', [plot_btn_x, plot_btn_y, plot_btn_width, plot_btn_height], ...
            'ButtonPushedFcn', @(btn, event) Plot(fig), ...
            'Tag', 'plotButton'); % Plot Button ruft plotDataWrapper auf
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
    % Passt die Größe und Position der UI-Elemente an, wenn die Fenstergröße geändert wird
    %
    % Args:
    %    fig (Figure): Das GUI-Fenster
    %
    % Diese Funktion berechnet die neuen Positionen und Größen der 
    % UI-Elemente basierend auf der aktuellen Fenstergröße und skaliert sie entsprechend.
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
        resizeComponent(fig, 'infoText',                [margin,                    250 * heightScaleFactor,    420 * widthScaleFactor,     365 * heightScaleFactor])
        resizeComponent(fig, 'fileListLabel',           [460 * widthScaleFactor,    588 * heightScaleFactor,    120 * widthScaleFactor,      27 * heightScaleFactor])
        resizeComponent(fig, 'fileList',                [460 * widthScaleFactor,    250 * heightScaleFactor,    420 * widthScaleFactor,     340 * heightScaleFactor])
        resizeComponent(fig, 'configButton',            [750 * widthScaleFactor,    593 * heightScaleFactor,    130 * widthScaleFactor,     height])
    
        % Titelzeilen
        resizeComponent(fig, 'title1',                  [100 * widthScaleFactor,    215 * heightScaleFactor,    620 * widthScaleFactor,     height])
        resizeComponent(fig, 'title2',                  [100 * widthScaleFactor,    175 * heightScaleFactor,    780 * widthScaleFactor,     height])
        resizeComponent(fig, 'title1label',             [ 20 * widthScaleFactor,    215 * heightScaleFactor,    760 * widthScaleFactor,     height])
        resizeComponent(fig, 'title2label',             [margin,                    175 * heightScaleFactor,    100 * widthScaleFactor,     height])
    
        % Parameterfelder
        paramLabelWidth = 120 * widthScaleFactor;
        paramWidth = 80 * widthScaleFactor;
        param_y1 = 125 * heightScaleFactor;
        param_y2 = 85 * heightScaleFactor;

        resizeComponent(fig, 'xyUntenStartLabel',       [130 * widthScaleFactor,    param_y1,                   paramLabelWidth,            height])
        resizeComponent(fig, 'xyUntenStart',            [250 * widthScaleFactor,    param_y1,                   paramWidth,                 height])
        resizeComponent(fig, 'xyUntenEndLabel',         [350 * widthScaleFactor,    param_y1,                   paramLabelWidth,            height])
        resizeComponent(fig, 'xyUntenEnd',              [470 * widthScaleFactor,    param_y1,                   paramWidth,                 height])
        resizeComponent(fig, 'xyObenStartLabel',        [130 * widthScaleFactor,    param_y2,                   paramLabelWidth,            height])
        resizeComponent(fig, 'xyObenStart',             [250 * widthScaleFactor,    param_y2,                   paramWidth,                 height])
        resizeComponent(fig, 'xyObenEndLabel',          [350 * widthScaleFactor,    param_y2,                   paramLabelWidth,            height])
        resizeComponent(fig, 'xyObenEnd',               [470 * widthScaleFactor,    param_y2,                   paramWidth,                 height])
    
        % Checkboxen
        width = 200 * widthScaleFactor;

        resizeComponent(fig, 'showReference',           [570 * widthScaleFactor,    param_y1,                   width,                      height])
        resizeComponent(fig, 'showDUT',                 [570 * widthScaleFactor,    param_y2,                   width,                      height])
    
        % Buttons
        btn_y = 10 * heightScaleFactor;
        btn_height = 50 * heightScaleFactor;
        
        resizeComponent(fig, 'Neue Dateien',            [130 * widthScaleFactor,    btn_y,                      width,                      btn_height])
        resizeComponent(fig, 'plotButton',              [350 * widthScaleFactor,    btn_y,                      width,                      btn_height])
        resizeComponent(fig, 'backButton',              [570 * widthScaleFactor,    btn_y,                      width,                      btn_height])
    
        % Ergebnisfeld
        resizeComponent(fig, 'resistanceLabel',         [730 * widthScaleFactor,    215 * heightScaleFactor,    paramLabelWidth,            height])
        resizeComponent(fig, 'resistance',              [820 * widthScaleFactor,    215 * heightScaleFactor,     60 * widthScaleFactor,     height])
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Anpassen der Objektgrößen.')
        disp(ME.message)
    end
end

function resizeComponent(fig, tag, position)
    % Ändert die Größe und Position eines UI-Komponenten
    %
    % Args:
    %    fig (Figure): Das GUI-Fenster
    %    tag (string): Tag der UI-Komponente
    %    position (array): Neue Position und Größe der UI-Komponente
    %
    % Diese Funktion sucht die UI-Komponente anhand ihres Tags und 
    % ändert ihre Position und Größe.
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
    % Löscht unnötige Informationen und ruft die Auswahlfunktion auf
    %
    % Args:
    %    fig (Figure): Das GUI-Fenster
    %
    % Diese Funktion löscht spezifische Variablen aus dem Base Workspace
    % und ruft die Auswahlfunktion auf, um zum Auswahlbildschirm 
    % zurückzukehren.
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
        uialert(fig, ME.message, 'Fehler beim schließen der Methode.')
        disp(ME.message)
    end
end

%% Datenverarbeitungsfunktionen

function Plot(fig)
    % Funktion für das Plotten der Daten
    %
    % Args:
    %    fig (Figure): Das GUI-Fenster
    %    config (struct): Konfigurationsdaten
    %
    % Diese Funktion liest die Konfiguration und die Checkbox-Zustände aus, 
    % lädt die Daten und ruft die Plot-Funktion auf. Sie zeigt auch 
    % eine Fehlermeldung an, falls keine Checkbox ausgewählt ist.
    try
        showReference = findobj(fig, 'Tag', 'showReference').Value;
        showDUT = findobj(fig, 'Tag', 'showDUT').Value;

        if ~showReference && ~showDUT
            return;
        end
        
        % config laden
        config = evalin("base", 'config');
        d = uiprogressdlg(fig,'Title','Bitte Warten',...
            'Message','Datei wird ausgelesen');
    
        d.Value = 0.1;
    
        % Einlesen der Titel
        t1 = char(findobj(fig, 'Tag', 'title1').Value);
        t2 = char(findobj(fig, 'Tag', 'title2').Value);
        replaceSpecialChars = @(str) regexprep(regexprep(str, '_(?!{)', '\\_'), '\^(?!{)', '\\^');
        t1 = replaceSpecialChars(t1);
        t2 = replaceSpecialChars(t2);
        
        % Meldungstext-Objekt
        info_text = findobj(fig, 'Tag', 'infoText');
    
        d.Value = 0.2;
    
        % Daten laden 
        fileList = findobj(fig, 'Tag', 'fileList');
        data = fileList.Value;
        if isempty(data) && showDUT
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
    
        d.Value = 0.5;
    
        % Wenn die Referenzdaten-Checkbox ausgewählt ist
        if showReference
            referenceDataArray = evalin('base', 'referenceDataArray');
        end
    
        d.Value = 0.6;
    
        % Wenn nur die Referenzdaten-Checkbox ausgewählt ist
        if showReference && ~showDUT
            % Plotten der kompletten Referenzdaten
            plotting([], referenceDataArray, 1:length(referenceDataArray{1}), 'b', t1, t2, config.Linienbreite, showReference, showDUT);
            
            d.Value = 0.7;
    
            % Plotten der relevanten Bereiche der Referenzdaten
            xyUntenStart = findobj(fig, 'Tag', 'xyUntenStart').Value;
            xyUntenEnd = findobj(fig, 'Tag', 'xyUntenEnd').Value;
            xyObenStart = findobj(fig, 'Tag', 'xyObenStart').Value;
            xyObenEnd = findobj(fig, 'Tag', 'xyObenEnd').Value;
            plotting([], referenceDataArray, [xyUntenStart:xyUntenEnd, xyObenStart:xyObenEnd], 'r', t1, t2, config.Linienbreite, ...
            showReference, showDUT);
    
            info_text.Value = [info_text.Value; newline; 'DCR der Referenzdateien:'];
            refFiles = evalin("base", 'refFiles');
            columns = config.Spalten;
            
            d.Value = 0.8;
    
            for i = 1:length(referenceDataArray)
                refData = referenceDataArray{i};
                refDCR = Widerstand({refData(:, columns)}, xyUntenStart, xyUntenEnd, xyObenStart, xyObenEnd);
                numstr = num2str(refDCR, '%.4f');
                switch length(numstr)
                    case 9
                        numstr = ['  ', numstr]; %#ok<*AGROW> 
                    case 8
                        numstr = ['  ', '  ', numstr];
                    case 7
                        numstr = ['  ', '  ', '  ', numstr];
                    case 6
                        numstr = ['  ', '  ', '  ', '  ', numstr];
                end
                info_text.Value = [info_text.Value; sprintf('%s:\t%s Ω', refFiles(i).name, numstr)];
            end
            return;
        end
    
        % Wenn die DUT-Checkbox ausgewählt ist (mit oder ohne Referenzdaten)
        if showDUT
            d.Value = 0.7;
    
            % Berechnung des DCR und Plot der Daten
            DCR = plotData(data, fig, showReference, showDUT, config.Linienbreite);
            
            d.Value = 0.8;
    
            decimal = config.Nachkommastellen;
            % Bearbeitung des Infotextes
            formatString = sprintf('%%.%df', decimal);
            resistance = findobj(fig, 'Tag', 'resistance');
            resistance.Value = sprintf(formatString, DCR);
            d.Value = 0.9;
        end
        d.Value = 1;
        close(d)
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des gesamten Plots.')
        disp(ME.message)
    end
end

function [dataArray, fileNames] = DataWrapper(fig)
    % Wrapper-Funktion für das Laden der Daten
    %
    % Args:
    %    fig (Figure): Das GUI-Fenster
    %    config (struct): Konfigurationsdaten
    %
    % Returns:
    %    data (array): Geladene DUT-Daten
    try
        config = evalin("base", 'config');

        columns = config.Spalten;
        
        % Einlesen der Checkbox-Zustände
        showDUT = findobj(fig, 'Tag', 'showDUT').Value;
        
        % Initialisiere leere Daten
        dataArray = [];
    
        % Wenn die DUT-Checkbox ausgewählt ist
        if showDUT
            % Einlesen der Daten
            standardPath = evalin('base', 'standardPath');
            currentRef = evalin("base", 'currentRef');
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

            if ischar(fileNames)
                fileNames = {fileNames};
            end
            dataFiles = cell(length(fileNames), 1);
            for i = 1:length(fileNames)
                dataFiles{i} = fullfile(filePath, fileNames{i});
            end
            [dataArray, ~] = read_txt(dataFiles, currentRef);
            for i = 1:length(dataArray)
                dataArray{i} = dataArray{i}(:, columns);
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

function DCR = plotData(data, fig, showReference, showDUT, lineWidth)
    % Plotten der Daten und Berechnung des Widerstands
    %
    % Args:
    %    data (array): Die zu plotenden Daten
    %    fig (Figure): Das GUI-Fenster
    %    showReference (logical): Ob Referenzdaten angezeigt werden sollen
    %    showDUT (logical): Ob DUT-Daten angezeigt werden sollen
    %    lineWidth (double): Die Breite der Linien im Plot
    %
    % Returns:
    %    DCR (double): Der berechnete Widerstand
    %
    % Diese Funktion liest die Referenzdaten, den zu plottenden Bereich 
    % und die Titel aus den GUI-Elementen, plotet die Daten und berechnet 
    % den Differential Conductance (DCR) Wert.
    try
        % Einlesen der Referenzdaten aus dem Base Workspace
        referenceDataArray = evalin('base', 'referenceDataArray');
    
        % Datenbereiche und Titel aus den Textfeldern lesen
        xyUntenStart = findobj(fig, 'Tag', 'xyUntenStart').Value;
        xyUntenEnd = findobj(fig, 'Tag', 'xyUntenEnd').Value;
        xyObenStart = findobj(fig, 'Tag', 'xyObenStart').Value;
        xyObenEnd = findobj(fig, 'Tag', 'xyObenEnd').Value;
        t1 = char(findobj(fig, 'Tag', 'title1').Value);
        t2 = char(findobj(fig, 'Tag', 'title2').Value);
    
        data1 = data{1};
        x = data1(:, 1); % Alle U-Werte
    
        % Debugging-Informationen
        fprintf('xyUntenStart: %d, xyUntenEnd: %d\n', xyUntenStart, xyUntenEnd);
        fprintf('xyObenStart: %d, xyObenEnd: %d\n', xyObenStart, xyObenEnd);
        fprintf('Datenlänge: %d\n', length(x));
    
        % Überprüfen der Indizes
        if xyUntenStart < 1 || xyUntenEnd > length(x) || xyObenStart < 1 || xyObenEnd > length(x)
            error('Die angegebenen Bereichsindizes liegen außerhalb des gültigen Bereichs der Daten.');
        end
        
        % Plotten der Messdaten
        plotting(data, referenceDataArray, 1:length(x), 'b', t1, t2, lineWidth, showReference, showDUT);
        plotting(data, referenceDataArray, [xyUntenStart:xyUntenEnd, xyObenStart:xyObenEnd], 'r', t1, t2, lineWidth, showReference, showDUT);
    
        % Berechnung des DCR
        if showDUT
            DCR = Widerstand(data, xyUntenStart, xyUntenEnd, xyObenStart, xyObenEnd);
        else
            DCR = NaN; % Falls keine DUT-Daten vorhanden sind, wird kein DCR berechnet
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Plotten der Daten.')
        disp(ME.message)
    end
end

function plotting(data, refData, area, color, t1, t2, lineWidth, showReference, showDUT)
    % Erstellen eines Plots
    %
    % Args:
    %    data (array): Daten
    %    refData (cell array): Referenzdaten
    %    area (array): Genutzter Datenbereich
    %    color (string): Farbe des Plots (Referenzdaten sind immer grau)
    %    t1 (string): 1. Titelzeile
    %    t2 (string): 2. Titelzeile
    %    lineWidth (double): Linienbreite des Plots
    %    showReference (logical): Ob Referenzdaten angezeigt werden sollen
    %    showDUT (logical): Ob DUT-Daten angezeigt werden sollen
    %
    % Diese Funktion erstellt ein Plotfenster, plotet die Messdaten und 
    % ggf. die Referenzdaten und passt die Achsen und Titel an.
    try
        config = evalin("base", 'config');
        columns = config.Spalten;
    
        % Erstellung des Plotfensters
        figure('Units', 'normalized', 'OuterPosition', [0 0 1 1]);
        hold on;    % Erlaube weitere Plots im Fenster
    
        % Zugriff auf die ColorOrder-Eigenschaft der aktuellen Achse
        colors = jet(length(refData));
        % Anzahl der verfügbaren Farben im ColorOrder
        numColors = size(colors, 1);
    
        % Finden der Trennstelle zwischen xyUnten und xyOben, falls vorhanden
        splitIndex = find(diff(area) > 1, 1);
        if isempty(splitIndex)
            splitIndex = length(area);
        end
    
        % Plotten der Referenzdaten (graue Linien), falls gewollt
        if showReference && ~isempty(refData) && showDUT
            for i = 1:length(refData)
                refU = refData{i}(:, columns(1));
                refI = refData{i}(:, columns(2)); 
                plotReferenceData(refU, refI, area, lineWidth, splitIndex);  % Plotfunktion für Referenzdaten
            end
            % Hinzufügen einer Legende für die Referenzdaten
            plot(nan, nan, '-o', 'LineWidth', lineWidth*3, 'MarkerSize', 8, ...
                'MarkerFaceColor', [0.9, 0.9, 0.9], ...
                'Color', [0.9, 0.9, 0.9], 'DisplayName', 'Referenz');
        elseif showReference && ~isempty(refData) && ~showDUT
            for i = 1:length(refData)
                refU = refData{i}(:, columns(1)); 
                refI = refData{i}(:, columns(2));
                colorIndex = mod(i-1, numColors) + 1; % Zyklischer Zugriff auf die Farben
                refName = sprintf('Referenz#%d', i);
                plotDataSegments(refU, refI, area, colors(colorIndex, :), lineWidth, splitIndex, refName);  % Plotfunktion für Referenzdaten
            end
        end
        
        % Anpassung der Achsen und des Gitters
        configureAxes();
        
        % Plotten der Daten in zwei Segmente (DUT-Linie)
        if showDUT
            for i = 1:length(data)
                currentData = data{i};
                x = currentData(:, 1); % Alle U-Werte
                y = currentData(:, 2); % Alle I-Werte
                plotDataSegments(x, y, area, color, lineWidth, splitIndex, 'DUT');
            end
        end
        
        % Titel und Achsenbeschriftung
        title(t1, t2);
        xlabel(config.xlabel, 'Position', ...
            [mean(config.xAchsenLimits) + diff(config.xAchsenLimits) * 0.018, config.yAchsenLimits(1) - diff(config.yAchsenLimits) * 0.035], ...
            'FontWeight', 'bold');
        ylabel(config.ylabel, 'Position', ...
            [config.xAchsenLimits(1) - diff(config.xAchsenLimits) * 0.0233, mean(config.yAchsenLimits) - diff(config.yAchsenLimits) * 0.03], ...
            'FontWeight', 'bold', 'Rotation', 90);
    
        grid on;
        
        % Hinzufügen einer Legende
        l = legend('Location', 'northeast');
        l.FontSize = config.legendFontSize;
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Plots.')
        disp(ME.message)
    end
end

function plotReferenceData(refU, refI, area, lineWidth, splitIndex)
    % Plotten der Referenzdaten
    %
    % Args:
    %    refU (array): U-Werte der Referenzdaten
    %    refI (array): I-Werte der Referenzdaten
    %    area (array): Genutzter Datenbereich
    %    lineWidth (double): Linienbreite des Plots
    %    splitIndex (int): Trennstelle zwischen xyUnten und xyOben
    %
    % Diese Funktion plotet die Referenzdaten in zwei Teilen, falls nötig.
    try
        % Plot der Referenzdaten (in zwei Teilen, wenn Area zwei Bereiche hat)
        plot(refU(area(1:splitIndex)), refI(area(1:splitIndex)), '-o', ...
            'LineWidth', lineWidth * 3, 'MarkerSize', 8, ...
            'MarkerFaceColor', [0.9, 0.9, 0.9], ...
            'Color', [0.9, 0.9, 0.9], ...
            'HandleVisibility', 'off');
        if splitIndex < length(area)
            plot(refU(area(splitIndex + 1:end)), refI(area(splitIndex + 1:end)), '-o', ...
                'LineWidth', lineWidth * 3, 'MarkerSize', 8, ...
                'MarkerFaceColor', [0.9, 0.9, 0.9], ...
                'Color', [0.9, 0.9, 0.9], ...
                'HandleVisibility', 'off');
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Plotten der Referenzdaten.')
        disp(ME.message)
    end
end

function plotDataSegments(x, y, area, color, lineWidth, splitIndex, name)
    % Plotten der Daten in Segmente
    %
    % Args:
    %    x (array): x-Daten
    %    y (array): y-Daten
    %    area (array): Genutzter Datenbereich
    %    color (string): Farbe des Plots
    %    lineWidth (double): Linienbreite des Plots
    %    splitIndex (int): Trennstelle zwischen xyUnten und xyOben
    %    name (string): Name des Plots für die Legende
    %
    % Diese Funktion plotet die Daten in zwei Teilen, falls nötig, und 
    % erstellt eine Legende.
    try
        % Plot der Daten (in zwei Teilen, wenn Area zwei Bereiche hat)
        plot(x(area(1:splitIndex)), y(area(1:splitIndex)), '-o', ...
            'LineWidth', lineWidth, 'MarkerSize', 4, ...
            'MarkerFaceColor', color, 'Color', color, 'DisplayName', name);
        if splitIndex < length(area)
            plot(x(area(splitIndex + 1:end)), y(area(splitIndex + 1:end)), '-o', ...
                'LineWidth', lineWidth, 'MarkerSize', 4, ...
                'MarkerFaceColor', color, 'Color', color, 'HandleVisibility', 'off');
        end
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Plotten eines Datensegments.')
        disp(ME.message)
    end
end

function DCR = Widerstand(data, xyUntenStart, xyUntenEnd, xyObenStart, xyObenEnd)
    % Berechnung des Widerstands mit Fit der oberen und unteren Linie
    %
    % Args:
    %    x (array): x-Daten
    %    y (array): y-Daten
    %    xyUntenStart (int): Startindex des unteren Bereichs
    %    xyUntenEnd (int): Endindex des unteren Bereichs
    %    xyObenStart (int): Startindex des oberen Bereichs
    %    xyObenEnd (int): Endindex des oberen Bereichs
    %
    % Returns:
    %    DCR (double): Der berechnete Widerstand
    %
    % Diese Funktion berechnet den Differential Conductance (DCR) Wert durch 
    % Linearfits der oberen und unteren Datenbereiche und mittelt die Steigungen.
    try
        DCR = nan(1, length(data));
    
        for i = 1:length(data)
            currentData = data{i};
            x = currentData(:, 1); % Alle U-Werte
            y = currentData(:, 2); % Alle I-Werte
            
            % Daten für DCR-Berechnung
            xUnten = x(xyUntenStart:xyUntenEnd);
            yUnten = y(xyUntenStart:xyUntenEnd);
            xOben = x(xyObenStart:xyObenEnd);
            yOben = y(xyObenStart:xyObenEnd);
        
            % Fit der Daten per Least-squares
            fitUnten = polyfit(xUnten, yUnten, 1);
            fitOben = polyfit(xOben, yOben, 1);
        
            % Durchschnitt der Steigung berechnen und DCR bestimmen
            slope = mean([fitUnten(1), fitOben(1)]);
            DCR(i) = 1 / slope;
        end
        DCR = mean(DCR);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Berechnen des DCR.')
        disp(ME.message)
    end
end

%% Helfer- und Dienstprogramme

function configureAxes()
    % Anpassung der Achsen und des Gitters
    %
    % Diese Funktion passt die Achsen und das Gitter des Plots an, setzt 
    % die Achsenlimits und fügt Achsenbeschriftungen mit Komma als Dezimaltrennzeichen hinzu.
    try
        % config laden
        config = evalin("base", 'config');
        upperLim = config.obererGrenzwert;
        lowerLim = config.untererGrenzwert;
        XLim = config.xAchsenLimits;
        yLim = config.yAchsenLimits;
    
        ax = gca;
        ax.XGrid = 'on'; % Aktivieren des X-Gitters
        ax.YGrid = 'on'; % Aktivieren des Y-Gitters
        ax.GridLineStyle = '-'; % Durchgezogene Gitterlinien
        ax.GridColor = [0.5, 0.5, 0.5]; % Gitterfarbe: Grau
        ax.GridAlpha = 0.7; % Transparenz des Gitters
        ax.XLim = XLim; % X-Achsenlimit setzen
        ax.YLim = yLim; % Y-Achsenlimit setzen
        ax.Layer = 'top'; % Achsenbeschriftungen und Gitterlinien oben
        ax.XAxisLocation = 'origin'; % X-Achse am Ursprung
        ax.YAxisLocation = 'origin'; % Y-Achse am Ursprung
        % Halbtransparente Grenzwertlinien bei y = +-0.1
        yline(upperLim, '-', 'Color', [1, 0.5, 0], 'Alpha', 0.5, 'LineWidth', 2, 'HandleVisibility', 'off');
        yline(lowerLim, '-', 'Color', [1, 0.5, 0], 'Alpha', 0.5, 'LineWidth', 2, 'HandleVisibility', 'off');
        
        % Achsenbeschriftungen mit Komma als Dezimaltrennzeichen
        updateTickLabels(ax);
        
        xTickSize = config.xTickSize;
        yTickSize = config.yTickSize;
        ax.XAxis.FontSize = xTickSize;
        ax.YAxis.FontSize = yTickSize;
    
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
        ax.XTickLabels = strrep(cellstr(num2str(ax.XTick', '%.2f')), '.', ',');
        ax.YTickLabel  = strrep(cellstr(num2str(ax.YTick', '%.2f')), '.', ',');
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Anpassen der Ticklabels.')
        disp(ME.message)
    end
end

%% Eingabe-/Ausgabefunktionen