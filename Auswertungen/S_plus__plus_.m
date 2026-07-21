function S_plus__plus_(referenceFolder)
    % Hauptfunktion, die den gesamten Ablauf steuert.
    % Diese Funktion ruft die config.json ab, richtet die GUI ein und fügt erforderliche Pfade hinzu.
    %
    % Args:
    %    referenceFolder (string): Pfad zum Ordner mit den Referenzdaten
    %
    % Returns:
    %    None

    try
        % Abruf der config.json und vervollständigen des Pfades zum Referenzordner
        currentRef = referenceFolder;
        assignin("base", 'currentRef', currentRef)
        configData = jsondecode(fileread(fullfile(currentRef, 'config.json')));
        thisConfig = configData.S_plus__plus_;
        assignin("base", "config", thisConfig)

        % Aktuelles Fenster als 'fig' laden und benennen
        fig = evalin('base', 'fig');
        fig.Name = 'S++';

        % Setup von 'fig' mit Buttons, Standardwerten und Textfeldern
        delete(fig.Children); % Entfernt alle bestehenden UI-Komponenten
        createButtons(fig);   % Erstellt die Buttons
        setupFigure(fig);     % Richtet das Hauptfenster ein
        createParameterFields(fig); % Erstellt Eingabefelder für Parameter
        createFileSelectionFields(fig); % Erstellt Felder zur Dateiauswahl

        % Event-Listener für die Größenänderung des Fensters hinzufügen
        fig.SizeChangedFcn = @(src, event) resizeUIComponents(fig);
        fig.AutoResizeChildren = 'off';  % Deaktivieren der automatischen Größenanpassung

        % Initiale Größenanpassung auf aktuelle Fenstergröße
        resizeUIComponents(fig);
        
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException(fig, ME, 'Fehler beim Öffnen des S++-Fensters.');
    end
end

function createButtons(fig)
    % Erzeugt Exit- und Back-Buttons, um das Programm zu beenden und zur Auswahl zurückzukehren.
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    %
    % Returns:
    %    None

    try
        % Definieren der Breite und Höhe der Buttons
        buttonWidth = 200;
        buttonHeight = 50;
        centerX = fig.Position(3) / 2;

        % Button um gewählte Dateien zu laden erstellen
        uibutton(fig, 'push', 'Text', 'Ausgewählte Dateien laden', 'Tag', 'Dateien laden', ...
            'Position', [20, 10, buttonWidth, buttonHeight], ...
            'ButtonPushedFcn', @(btn, event) loadFiles(fig));

        % Testplot-Button erstellen
        uibutton(fig, 'push', 'Text', 'Testplot', 'Tag', 'Testplot', ...
            'Position', [centerX - 10 - buttonWidth, 10, buttonWidth, buttonHeight], ...
            'ButtonPushedFcn', @(btn, event) Plot(fig, false));

        % Plot-Button erstellen
        uibutton(fig, 'push', 'Text', 'Plot', 'Tag', 'Plot', ...
            'Position', [centerX + 10, 10, buttonWidth, buttonHeight], ...
            'ButtonPushedFcn', @(btn, event) Plot(fig, true));

        % Zurück-Button erstellen
        uibutton(fig, 'push', 'Text', 'Zurück zur Auswahl', 'Tag', 'backButton', ...
            'Position', [centerX + 30 + buttonWidth, 10, buttonWidth, buttonHeight], ...
            'ButtonPushedFcn', @(btn, event) backToSelection(fig));

        % Config-Button erstellen
        uibutton(fig, 'Text', 'S++ config', ...
            'Position', [fig.Position(3) - 150, fig.Position(4) - 32, 130, 22], ...
            'ButtonPushedFcn', @(btn, event) runMethodScript('S_plus__plus_'), ...
            'Tag', 'configButton');
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException(fig, ME, 'Fehler beim Erstellen der Buttons.');
    end
end

function backToSelection(fig)
    % Diese Funktion kehrt zur Auswahl zurück und löscht unnötige Informationen aus dem Base Workspace.
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    %
    % Returns:
    %    None

    try
        % Löschen der Variablen "referenceDataArray", "config", "referenceFolder" und "fig" aus dem Base Workspace
        evalin('base', 'clear referenceDataArray config referenceFolder fig');

        % Aufrufen der Auswahl-Funktion und Übergabe des aktuellen Fensters
        clc;  % Löscht das Command Window
        Auswahl(fig);  % Ruft die Auswahl-Funktion auf
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException(fig, ME, 'Fehler beim Schließen der Methode.');
    end
end

function setupFigure(fig)
    % Leeren von 'fig' und Hinzufügen eines Textbereichs zum Anzeigen von Informationen.
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    %
    % Returns:
    %    None

    try
        margin = 20; % Randabstand für die Positionierung des Textbereichs

        % Definition des Informationstextes als Zell-Array
        textCell = { 
            'Die Auswertungsmethode "S++" wurde ausgewählt:', ...
            'TD-Datei noch nicht geladen', ...
            'CD-Datei noch nicht geladen', ...
            'CSV-Dateien noch nicht sortiert', ...
            'Messwert:		  0 von 0 (0%)', ...
            'Vergangene Zeit:		00:00:00', ...
            'Erwartete Gesamtzeit:	00:00:00', ...
            'Verbleibende Zeit:		00:00:00', ...
            '', ...
            'Help:', ...
            'Links: Parameter für Auswertung und Videoerstellung', ...
            '>> "Videogeschwindigkeit ..."', ...
            '  => Messwerte werden nicht übersprungen, sind im Video aber kürzer zu sehen', ...
            '>> "Jeder wie vielte Messpunkt ..."', ...
            '  => Messwerte dazwischen werden übersprungen', ...
            '>> "Index/Zeitpunkt ..."', ...
            '  => Bei Zeitpunkt wird der Messwert angezeigt, der am nächsten am eingegebenen liegt.', ...
            '  => Als Format am besten das aus der CSV-/dat-Datei nehmen', ...
            '', ...
            'Rechts:', ...
            '>> Oben: Verteilungsdaten auswählen', ...
            '>> Mitte: CSV-Dateien Laden', ...
            '>> Unten: Koordinaten der Ausgeblendeten Segmente angeben', ...
            '>>>> Immer oben Y-Wert und unten X-Wert des Segments angeben', ...
            '', ...
            'Erst "Ausgewählte Dateien laden", dann "Testplot" oder "Plot"'
        };

        % Erstellen des Textbereichs und Positionierung innerhalb des Fensters
        uitextarea(fig, 'Position', [margin, 216, 500, fig.Position(4) - 226], ...
            'Value', textCell, ...
            'Tag', 'infoText');
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException(fig, ME, 'Fehler beim Erstellen des Infotextes.');
    end
end

function createParameterFields(fig)
    % Diese Funktion erstellt Parameterfelder und Buttons für die GUI.
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    %
    % Returns:
    %    None

    try
        % Laden der Konfiguration aus dem Basis-Workspace
        config = evalin("base", 'config');
        deviationBalancedArea = config.deviationBalancedArea;
        cdLinesToDelete = config.cdLinesToDelete;
        cdRowsToDelete = config.cdRowsToDelete;
        tdLinesToDelete = config.tdLinesToDelete;
        tdRowsToDelete = config.tdRowsToDelete;
        segmentArea = config.segmentArea;
        framerate = config.framerate;
        frequency = config.frequency;
        singleFrame = config.singleFrame;
        showPlotWindow = config.showPlotWindow;
        cdGridCheck = config.cdGridCheck;
        tdGridCheck = config.tdGridCheck;
        cdColorCheck = config.cdColorCheck;
        tdColorCheck = config.tdColorCheck;

        % UI-Parameter
        margin = 20;
        height = 22;

        % Erstellen der Parameterfelder mit entsprechenden Labels und Eingabefeldern
        addParameterField(fig, 'Erlaubte Abweichung vom Mittelwert [%] (für Balanced Area):', deviationBalancedArea, [margin, 186, 340, height], ...
            'deviationBalancedArea', false, 0.1, true);
        addParameterField(fig, 'Fläche der einzelnen Segmente [cm²]:', segmentArea, [margin, 161, 340, height], 'segmentArea', false, 0.1, true);
        addParameterField(fig, 'Videogeschwindigkeit [Bilder pro Sekunde]:', framerate, [margin, 136, 340, height], 'framerate', true, 1, false);
        addParameterField(fig, 'Jeder wie vielte Messpunkt soll angezeigt werden?:', frequency, [margin, 111, 340, height], 'frequency', true, 1, false);

        % Label und Eingabefeld für den Messpunkt im Testplot
        uilabel(fig, "Text", 'Index/Zeitpunkt des Messpunktes der im Testplot gezeigt wird:', 'Position', [margin, 86, 340, height], 'Tag', 'singleFrameLabel');
        uieditfield(fig, 'text', 'Value', num2str(singleFrame), 'Position', [margin, 65, 303, height], 'Tag', 'singleFrame');

        uicheckbox(fig, "Value", showPlotWindow, 'Text', 'Plotbild anzeigen', 'Position', [330, 65, 110, height], 'Tag', 'showPlotWindow');

        uilabel(fig, "Text", 'Feste Farbskala:', 'Position', [460, 90, 140, height], 'Tag', 'colorLabel');
        uicheckbox(fig, "Value", cdColorCheck, 'Text', 'Current Distribution', 'Position', [600, 90, 125, height], 'Tag', 'cdColorCheck');
        uicheckbox(fig, "Value", tdColorCheck, 'Text', 'Temperature Distribution', 'Position', [730, 90, 150, height], 'Tag', 'tdColorCheck');

        uilabel(fig, "Text", 'Plot mit Raster anzeigen:', 'Position', [460, 65, 140, height], 'Tag', 'gridLabel');
        uicheckbox(fig, "Value", cdGridCheck, 'Text', 'Current Distribution', 'Position', [600, 65, 125, height], 'Tag', 'cdGridCheck');
        uicheckbox(fig, "Value", tdGridCheck, 'Text', 'Temperature Distribution', 'Position', [730, 65, 150, height], 'Tag', 'tdGridCheck');

        % Labels und Eingabefelder für fehlerhafte Segmente der Temperaturverteilung
        uilabel(fig, "Text", 'Fehlerhafte Segmente der Temperature distribution:', 'Position', [460, 238, 300, height], 'Tag', 'tdSegmentsLabel');
        addParameterField(fig, 'Zeilen (Y):', tdLinesToDelete, [460, 217, 60, height], 'tdLinesToDelete');
        addParameterField(fig, 'Spalten (X):', tdRowsToDelete, [460, 192, 65, height], 'tdRowsToDelete');

        % Labels und Eingabefelder für fehlerhafte Segmente der Stromverteilung
        uilabel(fig, "Text", 'Fehlerhafte Segmente der Current distribution:', 'Position', [460, 163, 300, height], 'Tag', 'cdSegmentsLabel');
        addParameterField(fig, 'Zeilen (Y):', cdLinesToDelete, [460, 142, 60, height], 'cdLinesToDelete');
        addParameterField(fig, 'Spalten (X):', cdRowsToDelete, [460, 117, 65, height], 'cdRowsToDelete');

    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException(fig, ME, 'Fehler beim Erstellen der Parameterfelder.');
    end
end

function addParameterField(fig, label, value, position, tag, roundFrac, step, lowLimInc)
    % Hilfsfunktion zum Hinzufügen eines Parameterfeldes zur GUI.
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    %    label (string): Text des Labels
    %    value (any): Standardwert des Feldes
    %    position (array): Position und Größe des Feldes [x y width height]
    %    tag (string): Tag des Feldes
    %    roundFrac (logical): Bestimmt, ob der Spinner-Wert gerundet wird
    %    step (double): Schrittweite des Spinners
    %    lowLimInc (logical): Bestimmt, ob der untere Grenzwert inklusiv ist
    %
    % Returns:
    %    None

    try
        % Setze Positionen für Label und Eingabefeld
        labelPosition = position;
        editPosition = position;
        
        % Erstelle das Label
        uilabel(fig, "Text", label, 'Position', labelPosition, 'Tag', [tag, 'Label']);
        
        if isnumeric(value)
            % Anpassung der Position und Größe des Eingabefelds für numerische Werte (Spinner)
            editPosition(1) = editPosition(1) + labelPosition(3);
            editPosition(3) = 80;
            uispinner(fig, 'Value', value, 'Position', editPosition, 'Tag', tag, ...
                'ValueDisplayFormat', '%11.8g', 'Limits', [0, Inf], ...
                'RoundFractionalValues', roundFrac, 'Step', step, ...
                'LowerLimitInclusive', lowLimInc, 'UpperLimitInclusive', 'off');
        else
            % Anpassung der Position und Größe des Eingabefelds für Textwerte
            editPosition(1) = editPosition(1) + 70;
            editPosition(3) = 350;
            uieditfield(fig, 'text', 'Value', value, 'Position', editPosition, 'Tag', tag);
        end
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException(fig, ME, ['Fehler beim Hinzufügen des Parameterfeldes: ', label]);
    end
end

function createFileSelectionFields(fig)
    % Diese Funktion erstellt die Dateiauswahlliste
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    %
    % Returns:
    %    None

    try
        % Positions- und Größenparameter für die UI-Komponenten
        btn_x = 460;
        btn_width = 140;
        check_x = 866;
        check_width = 15;
        height = 22;

        % Label für Messdateien hinzufügen
        uitextarea(fig, "Value", 'Messdateien:', 'Position', [btn_x, fig.Position(4) - 37, 115, 27], ...
            'FontSize', 17.5, 'Tag', 'MessdateienLabel', 'Editable', 'off', 'BackgroundColor', fig.Color);

        % Dateiauswahlfelder für Temperature Distribution und Current Distribution hinzufügen
        addFileSelectionField(fig, 'Temperature Distribution', [btn_x, 560, btn_width, height], 'td');
        addFileSelectionField(fig, 'Current Distribution', [btn_x, 535, btn_width, height], 'cd');

        % Label für CSV-Dateien hinzufügen
        uitextarea(fig, "Value", 'CSV-Dateien:', 'Position', [btn_x, 510, 95, 22], 'FontSize', 14, 'Tag', 'fileListLabel', ...
            'Editable', 'off', 'BackgroundColor', fig.Color);

        % Label für "sortiert?" Checkbox hinzufügen
        uilabel(fig, "Text", 'sortiert?', 'Position', [check_x - 60 , 510, 50, height], 'Tag', 'csvText', 'HorizontalAlignment', 'right');

        % Checkbox für die CSV-Dateien hinzufügen
        uicheckbox(fig, "Value", false, 'Position', [check_x, 510, check_width, height], 'Tag', 'csvCheck', 'Text', '', 'Enable', 'off');

        % Checkbox für Strom-/Spannungsplot hinzufügen
        uicheckbox(fig, "Value", false, 'Position', [btn_x+btn_width+10, 510, 140, height], 'Tag', 'plotCheck', 'Text', 'Strom-/Spannungsplot');

        % Listbox für die Dateiauswahl hinzufügen
        uilistbox(fig, 'Position', [460, 291.5, 420, 215], 'Tag', 'fileList', 'Multiselect', 'on', 'Items', {});

        % Buttons für das Laden und Löschen von CSV-Dateien hinzufügen
        uibutton(fig, 'push', 'Text', 'Neue CSV-Datei laden', 'Tag', 'Neue CSV-Datei', 'Position', [460, 266, 205, 22], ...
            'ButtonPushedFcn', @(btn, event) addFiles(fig));
        uibutton(fig, 'push', 'Text', 'Löschen', 'Tag' , 'Löschen', 'Position', [675, 266, 205, 22], ...
            'ButtonPushedFcn', @(btn, event) clearSelectedFiles(fig));
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException(fig, ME, 'Fehler beim Erstellen des Dateiauswahlfeldes.');
    end
end

function addFileSelectionField(fig, buttonText, position, tag)
    % Hilfsfunktion zum Hinzufügen eines Dateiauswahlfeldes zur GUI
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    %    buttonText (string): Text des Buttons
    %    position (array): Position und Größe des Feldes [x, y, Breite, Höhe]
    %    tag (string): Tag des Feldes
    %
    % Returns:
    %    None

    try
        % Erstellen eines Buttons zur Dateiauswahl
        uibutton(fig, 'Text', buttonText, 'Position', position, 'Tag', [tag, 'Button'], ...
            'ButtonPushedFcn', @(btn, event) addFilePath(fig, [tag, 'Text'], [tag, 'Check']));

        % Erstellen eines nicht-editierbaren Textfeldes zur Anzeige des Dateipfades
        uitextarea(fig, "Value", '', 'Position', [position(1) + 150, position(2), 246, position(4)], ...
            'Tag', [tag, 'Text'], 'Editable', 'off');

        % Erstellen einer Checkbox zur Markierung der Dateiauswahl
        uicheckbox(fig, "Value", false, 'Position', [position(1) + 406, position(2), 15, position(4)], ...
            'Tag', [tag, 'Check'], 'Text', '', 'Enable', 'off');

    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException(fig, ME, ['Fehler beim Hinzufügen des Dateiauswahlfeldes: ', buttonText]);
    end
end

function addFilePath(fig, tagText, tagCheck)
    % Funktion zum Hinzufügen eines Dateipfades zur GUI
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    %    tagText (string): Tag des Textfeldes
    %    tagCheck (string): Tag der Checkbox
    %
    % Returns:
    %    None

    try
        % Finden der UI-Komponenten basierend auf ihren Tags
        text = findobj(fig, 'Tag', tagText);
        check = findobj(fig, 'Tag', tagCheck);

        % Standardverzeichnis für die Dateiauswahl aus dem Basis-Workspace abrufen
        scriptDir = evalin("base", 'standardPath');
        originalDir = cd(scriptDir); % Wechsel in das Standardverzeichnis

        % Öffnen des Datei-Auswahl-Dialogs
        [fileName, filePath] = uigetfile('*.dat', 'Wählen Sie eine .dat Datei aus');
        cd(originalDir); % Zurückkehren zum ursprünglichen Verzeichnis

        % Überprüfen, ob der Benutzer die Auswahl abgebrochen hat
        if isequal(fileName, 0)
            disp('Benutzer hat Abbrechen gewählt');
            return;
        else
            fullFilePath = fullfile(filePath, fileName);
        end

        assignin("base",'standardPath', filePath)

        % Aktualisieren des Textfeldes und der Checkbox
        text.Value = fileName;
        text.Tooltip = fullFilePath;
        check.Value = false;

    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException(fig, ME, 'Fehler beim Hinzufügen des Dateipfades.');
    end
end

function loadFiles(fig)
    % Funktion zum Laden der ausgewählten Dateien.
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    %
    % Returns:
    %    None

    try
        % Pointer anpassen, um anzuzeigen, dass das Programm läuft
        oldpointer = get(fig, 'pointer');
        set(fig, 'pointer', 'watch');
        drawnow;

        % Update der Info-Textfelder
        text = findobj(fig, 'Tag', 'infoText');
        textCell = text.Value;
        for i = 2:4
            textCell{i} = {};
        end

        % Laden der TD-Daten, sofern Pfad vorhanden und noch nicht geladen
        filePathText = findobj(fig, 'Tag', 'tdText');
        fullFilePath = filePathText.Tooltip;
        check = findobj(fig, 'Tag', 'tdCheck');
        if ~isempty(fullFilePath) && ~check.Value
            [tdData, timestamps] = read_s_plus__plus__dat(true, fullFilePath, text);
            check.Value = true;
            assignin("base", 'tdData', tdData)
            assignin("base", 'timestamps', timestamps)
        end

        % Laden der CD-Daten, sofern Pfad vorhanden und noch nicht geladen
        filePathText = findobj(fig, 'Tag', 'cdText');
        fullFilePath = filePathText.Tooltip;
        check = findobj(fig, 'Tag', 'cdCheck');
        if ~isempty(fullFilePath) && ~check.Value
            [cdData, ~] = read_s_plus__plus__dat(false, fullFilePath, text);
            check.Value = true;
            assignin("base", 'cdData', cdData)
        end

        % Laden und Sortieren der CSV-Dateien, sofern vorhanden und noch nicht geladen
        check = findobj(fig, 'Tag', 'csvCheck');
        items = findobj(fig, 'Tag', 'fileList').ItemsData;
        if ~isempty(items) && ~check.Value
            sortCSVFiles(fig)
            readText = text.Value;
            readText{4} = 'Sorted CSV-Files';
            text.Value = readText;
            check.Value = true;
        end

        % Pointer wieder zurücksetzen
        set(fig, 'pointer', oldpointer)
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException(fig, ME, 'Fehler beim Lesen der Dateien.');
        try
            set(fig, 'pointer', oldpointer);
        catch
            return
        end
    end 
end

function sortCSVFiles(fig)
    % Funktion zum Sortieren der CSV-Dateien.
    % Diese Funktion sortiert die CSV-Dateien in der Listbox basierend auf ihrem Datumszeitstempel.
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    %
    % Returns:
    %    None

    try
        % Zugriff auf die Listbox und deren ItemsData
        listbox = findobj(fig, 'Tag', 'fileList');
        itemsData = listbox.ItemsData;

        % Anzahl der Objekte in der Listbox
        numItems = numel(itemsData);

        % Initialisiere ein Array für die datetime-Objekte
        datetimeArray = NaT(numItems, 1);

        % Extrahiere die datetime-Objekte aus den ItemsData
        for i = 1:numItems
            datetimeArray(i) = itemsData{i}{1, 1};
        end

        % Sortiere die datetime-Objekte und erhalte die Sortierindizes
        [~, sortIdx] = sort(datetimeArray);

        % Sortiere die ItemsData basierend auf den Indizes
        sortedItemsData = itemsData(sortIdx);

        % Aktualisiere die uilistbox mit den sortierten ItemsData
        listbox.ItemsData = sortedItemsData;
        listbox.Items = listbox.Items(sortIdx); % Falls du auch die Items sortieren willst
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException(fig, ME, 'Fehler beim Sortieren der CSV-Dateien.');
    end
end

function runMethodScript(method)
    % Funktion zum Ausführen des Methodenskripts
    %
    % Args:
    %    method (string): Der Name der Methode
    %
    % Returns:
    %    None

    try
        % Hole den aktuellen Referenzordner aus den Anwendungsdaten
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
            fig = findall(0, 'Type', 'figure', 'Name', 'S++ Einstellungen'); 

            % Setze den CloseRequestFcn-Callback
            addlistener(fig, 'ObjectBeingDestroyed', @(src, event) onCloseCallback(src, event));
        else
            error('Das Skript %s existiert nicht.', scriptPath);
        end
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException([], ME, 'Fehler beim Öffnen der Config.');
    end
end

function onCloseCallback(src, ~)
    % Callback-Funktion, die aufgerufen wird, wenn das Fenster geschlossen wird.
    %
    % Args:
    %    src: Die Quelle des Ereignisses (das Fenster, das geschlossen wird)
    %
    % Returns:
    %    None

    try
        disp('closed');
        
        % Abrufen des aktuellen Referenzordners aus dem Basis-Workspace
        currentRef = evalin("base", 'currentRef');

        % Lesen der Konfigurationsdaten aus der config.json
        configData = jsondecode(fileread(fullfile(currentRef, 'config.json')));
        thisConfig = configData.S_plus__plus_;

        % Speichern der Konfigurationsdaten im Basis-Workspace
        assignin("base", "config", thisConfig);

        % Vermeiden Sie rekursive Aufrufe, indem Sie src löschen, falls es noch gültig ist
        if isvalid(src)
            delete(src);
        end
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException([], ME, 'Fehler beim Schließen des Fensters.');
    end
end

function resizeUIComponents(fig)
    % Diese Funktion passt die Größe und Position der UI-Elemente an, wenn die Fenstergröße geändert wird.
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    %
    % Returns:
    %    None

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
        resizeComponent(fig, 'infoText',                    [margin,                    216 * heightScaleFactor,    420 * widthScaleFactor,     399 * heightScaleFactor]);
        resizeComponent(fig, 'MessdateienLabel',            [460 * widthScaleFactor,    588 * heightScaleFactor,    115 * widthScaleFactor,      27 * heightScaleFactor]);
        resizeComponent(fig, 'fileList',                    [460 * widthScaleFactor,    291.5 * heightScaleFactor,  420 * widthScaleFactor,     215 * heightScaleFactor]);
        resizeComponent(fig, 'fileListLabel',               [460 * widthScaleFactor,    510 * heightScaleFactor,     95 * widthScaleFactor,     height]);
        resizeComponent(fig, 'tdText',                      [610 * widthScaleFactor,    560 * heightScaleFactor,    246 * widthScaleFactor,     height]);
        resizeComponent(fig, 'cdText',                      [610 * widthScaleFactor,    535 * heightScaleFactor,    246 * widthScaleFactor,     height]);
        resizeComponent(fig, 'csvText',                     [806 * widthScaleFactor,    510 * heightScaleFactor,     50 * widthScaleFactor,     height]);

        % Parameterfelder
        resizeComponent(fig, 'deviationBalancedAreaLabel',  [margin,                    186 * heightScaleFactor,    340 * widthScaleFactor,     height]);
        resizeComponent(fig, 'deviationBalancedArea',       [360 * widthScaleFactor,    185 * heightScaleFactor,     80 * widthScaleFactor,     height]);
        resizeComponent(fig, 'segmentAreaLabel',            [margin,                    161 * heightScaleFactor,    340 * widthScaleFactor,     height]);
        resizeComponent(fig, 'segmentArea',                 [360 * widthScaleFactor,    161 * heightScaleFactor,     80 * widthScaleFactor,     height]);
        resizeComponent(fig, 'framerateLabel',              [margin,                    136 * heightScaleFactor,    340 * widthScaleFactor,     height]);
        resizeComponent(fig, 'framerate',                   [360 * widthScaleFactor,    136 * heightScaleFactor,     80 * widthScaleFactor,     height]);
        resizeComponent(fig, 'frequencyLabel',              [margin,                    111 * heightScaleFactor,    340 * widthScaleFactor,     height]);
        resizeComponent(fig, 'frequency',                   [360 * widthScaleFactor,    111 * heightScaleFactor,     80 * widthScaleFactor,     height]);
        resizeComponent(fig, 'singleFrameLabel',            [margin,                     86 * heightScaleFactor,    340 * widthScaleFactor,     height]);
        resizeComponent(fig, 'singleFrame',                 [margin,                     65 * heightScaleFactor,    303 * widthScaleFactor,     height]);

        resizeComponent(fig, 'tdSegmentsLabel',             [460 * widthScaleFactor,    238 * heightScaleFactor,    300 * widthScaleFactor,     height]);
        resizeComponent(fig, 'tdLinesToDeleteLabel',        [460 * widthScaleFactor,    217 * heightScaleFactor,     60 * widthScaleFactor,     height]);
        resizeComponent(fig, 'tdLinesToDelete',             [530 * widthScaleFactor,    217 * heightScaleFactor,    350 * widthScaleFactor,     height]);
        resizeComponent(fig, 'tdRowsToDeleteLabel',         [460 * widthScaleFactor,    192 * heightScaleFactor,     65 * widthScaleFactor,     height]);
        resizeComponent(fig, 'tdRowsToDelete',              [530 * widthScaleFactor,    192 * heightScaleFactor,    350 * widthScaleFactor,     height]);
        resizeComponent(fig, 'cdSegmentsLabel',             [460 * widthScaleFactor,    163 * heightScaleFactor,    300 * widthScaleFactor,     height]);
        resizeComponent(fig, 'cdLinesToDeleteLabel',        [460 * widthScaleFactor,    142 * heightScaleFactor,     60 * widthScaleFactor,     height]);
        resizeComponent(fig, 'cdLinesToDelete',             [530 * widthScaleFactor,    142 * heightScaleFactor,    350 * widthScaleFactor,     height]);
        resizeComponent(fig, 'cdRowsToDeleteLabel',         [460 * widthScaleFactor,    117 * heightScaleFactor,     65 * widthScaleFactor,     height]);
        resizeComponent(fig, 'cdRowsToDelete',              [530 * widthScaleFactor,    117 * heightScaleFactor,    350 * widthScaleFactor,     height]);

        resizeComponent(fig, 'colorLabel',                  [460 * widthScaleFactor,     90 * heightScaleFactor,    140 * widthScaleFactor,     height]);
        resizeComponent(fig, 'gridLabel',                   [460 * widthScaleFactor,     65 * heightScaleFactor,    140 * widthScaleFactor,     height]);

        % Checkboxen
        resizeComponent(fig, 'tdCheck',                     [866 * widthScaleFactor,    560 * heightScaleFactor,     15 * widthScaleFactor,     height]);
        resizeComponent(fig, 'cdCheck',                     [866 * widthScaleFactor,    535 * heightScaleFactor,     15 * widthScaleFactor,     height]);
        resizeComponent(fig, 'csvCheck',                    [866 * widthScaleFactor,    510 * heightScaleFactor,     15 * widthScaleFactor,     height]);
        resizeComponent(fig, 'showPlotWindow',              [330 * widthScaleFactor,     65 * heightScaleFactor,    110 * widthScaleFactor,     height]);
        resizeComponent(fig, 'cdColorCheck',                [600 * widthScaleFactor,     90 * heightScaleFactor,    125 * widthScaleFactor,     height]);
        resizeComponent(fig, 'tdColorCheck',                [730 * widthScaleFactor,     90 * heightScaleFactor,    150 * widthScaleFactor,     height]);
        resizeComponent(fig, 'cdGridCheck',                 [600 * widthScaleFactor,     65 * heightScaleFactor,    125 * widthScaleFactor,     height]);
        resizeComponent(fig, 'tdGridCheck',                 [730 * widthScaleFactor,     65 * heightScaleFactor,    150 * widthScaleFactor,     height]);

        % Buttons
        btn_y = 10 * heightScaleFactor;
        btn_width = 200 * widthScaleFactor;
        btn_height = 50 * heightScaleFactor;

        resizeComponent(fig, 'configButton',                [750 * widthScaleFactor,    593 * heightScaleFactor,    130 * widthScaleFactor,     height]);
        resizeComponent(fig, 'tdButton',                    [460 * widthScaleFactor,    560 * heightScaleFactor,    140 * widthScaleFactor,     height]);
        resizeComponent(fig, 'cdButton',                    [460 * widthScaleFactor,    535 * heightScaleFactor,    140 * widthScaleFactor,     height]);

        resizeComponent(fig, 'Neue CSV-Datei',              [460 * widthScaleFactor,    266 * heightScaleFactor,    205 * widthScaleFactor,     height]);
        resizeComponent(fig, 'Löschen',                     [675 * widthScaleFactor,    266 * heightScaleFactor,    205 * widthScaleFactor,     height]);

        resizeComponent(fig, 'Dateien laden',               [ 20 * widthScaleFactor,    btn_y,                      btn_width,                  btn_height]);
        resizeComponent(fig, 'Testplot',                    [240 * widthScaleFactor,    btn_y,                      btn_width,                  btn_height]);
        resizeComponent(fig, 'Plot',                        [460 * widthScaleFactor,    btn_y,                      btn_width,                  btn_height]);
        resizeComponent(fig, 'backButton',                  [680 * widthScaleFactor,    btn_y,                      btn_width,                  btn_height]);
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException(fig, ME, 'Fehler beim Anpassen der Objektgrößen.');
    end
end

function resizeComponent(fig, tag, position)
    % Hilfsfunktion zum Anpassen der Größe und Position eines UI-Elements
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    %    tag (string): Tag des UI-Elements
    %    position (array): Die neue Position und Größe des UI-Elements
    %
    % Returns:
    %    None

    try
        % Suche nach dem UI-Element mit dem angegebenen Tag
        component = findobj(fig, 'Tag', tag);
        if ~isempty(component)
            % Setze die neue Position und Größe des UI-Elements
            component.Position = position;
        end
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException(fig, ME, ['Fehler beim Anpassen der Größe von ', tag]);
    end
end

function addFiles(fig)
    % Funktion zum Hinzufügen von Dateien zur Liste
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    %
    % Returns:
    %    None

    try
        % Daten und Dateinamen abrufen
        [allData, fileNames] = DataWrapper();

        % Suche nach der Datei-Liste im GUI
        fileList = findobj(fig, 'Tag', 'fileList');
        for i = 1:length(fileNames)
            fileName = fileNames{i};
            % Datei zur Liste hinzufügen
            addFileToList(fileList, fileName, allData{i}, length(fileList.Items) + 1);
        end

        % Suche nach dem CSV-Check-Element und setze seinen Wert auf false
        check = findobj(fig, 'Tag', 'csvCheck');
        check.Value = false;
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException(fig, ME, 'Fehler beim Hinzufügen der Dateien.');
    end
end

function addFileToList(fileList, fileName, data, position)
    % Hilfsfunktion zum Hinzufügen einer einzelnen Datei zur Liste an einer bestimmten Position
    %
    % Args:
    %    fileList (uilistbox): Die Liste, zu der die Datei hinzugefügt werden soll
    %    fileName (string): Der Name der Datei
    %    data (array): Die Daten der Datei
    %    position (int): Die Position, an der die Datei hinzugefügt werden soll
    %
    % Returns:
    %    None

    try
        if isempty(fileList.Items)
            % Wenn die Liste leer ist, füge die erste Datei hinzu
            fileList.Items = {fileName};
            fileList.ItemsData = {data};
        else
            % Überprüfe, ob die Datei bereits in der Liste vorhanden ist
            index = find(cellfun(@(x) isequal(x, fileName), fileList.Items));
            if ~isempty(index)
                % Entferne die Datei, wenn sie bereits vorhanden ist
                fileList.Items(index) = [];
                fileList.ItemsData(index) = [];
                if index < position
                    position = position - 1;
                end
            end
            % Füge die Datei an der angegebenen Position hinzu
            fileList.Items = [fileList.Items(1:position-1), {fileName}, fileList.Items(position:end)];
            fileList.ItemsData = [fileList.ItemsData(1:position-1), {data}, fileList.ItemsData(position:end)];
        end
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException([], ME, 'Fehler beim Hinzufügen einer Datei.');
    end
end

function [allData, fileNames] = DataWrapper()
    % Diese Funktion liest Daten aus ausgewählten Dateien ein.
    %
    % Returns:
    %    allData (cell array): Eingelesene Daten
    %    fileNames (cell array): Namen der eingelesenen Dateien

    try
        % Konfiguration aus dem Basis-Workspace abrufen
        config = evalin("base", 'config');
        lines = processInf(config.Zeilen);
        columns = processInf(config.Spalten);
        standardPath = evalin("base", 'standardPath');

        try
            % Standardordner wechseln und Dateiauswahldialog öffnen
            oldFolder = cd(standardPath);
            [fileNames, filePath] = uigetfile('*.csv', 'Wählen Sie eine Datei zur Auswertung aus', 'MultiSelect', 'on');
            cd(oldFolder);
        catch ME
            % Fehlerbehandlung: Warnung bei ungültigem Standardordner
            fig = evalin('base', 'fig');
            uialert(fig, [ME.message], 'Standardordner nicht gültig, bitte in der config anpassen.', 'Icon', 'warning');
            [fileNames, filePath] = uigetfile('*.csv', 'Wählen Sie eine Datei zur Auswertung aus');
        end

        % Prüfung, ob Dateien ausgewählt wurden
        if iscell(fileNames) || ischar(fileNames)
            if ischar(fileNames)
                fileNames = {fileNames};
            end

            allData = cell(length(fileNames), 1);

            % Daten aus den ausgewählten Dateien einlesen und verarbeiten
            for i = 1:length(fileNames)
                file = fileNames{i};
                dataFile = fullfile(filePath, file);
                [data, headerRow] = read_csv({dataFile}, lines, columns);
                data = data{1}(headerRow+1:end,:);

                try
                    % Versuch, die Daten in eine numerische Matrix umzuwandeln
                    allData{i} = cell2mat(data);
                catch
                    % Fehlerbehandlung bei gemischten Datentypen
                    datetimeColumn = data(:, 1);
                    numericData = cell2mat(data(:, 2:end));
                    allData{i} = [datetimeColumn, num2cell(numericData)];
                end
            end
            assignin("base",'standardPath', filePath)
        else
            allData = {};
            fileNames = {};
        end
        
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException([], ME, 'Fehler beim Lesen der Daten. (Wahrscheinlich sind falsche Spalten gewählt)');
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
                    data{i} = strrep(data{i}, '"', '');
                elseif isnumeric(data{i}) && isinf(data{i})
                    data{i} = Inf;
                end
            end
            data = reshape(cell2mat(data), 1, 2);
        end
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException([], ME, 'Fehler beim Verarbeiten von "Inf"-Eingaben.');
    end
end

function clearSelectedFiles(fig)
    % Funktion zum Löschen der ausgewählten Dateien aus der Liste
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    %
    % Returns:
    %    None

    try
        % Suche nach der Datei-Liste im GUI
        fileList = findobj(fig, 'Tag', 'fileList');
        selectedItems = fileList.Value;  % Ausgewählte Elemente

        % Überprüfen, ob keine Elemente ausgewählt sind
        if isempty(selectedItems)
            return;
        end

        % Konvertiere ausgewählte Elemente in Zell-Array, falls nötig
        if ischar(selectedItems)
            selectedItems = {selectedItems};
        end

        % Konvertiere Items und ItemsData in Zell-Array, falls nötig
        if ischar(fileList.Items)
            fileList.Items = {fileList.Items};
        end

        if ischar(fileList.ItemsData)
            fileList.ItemsData = {fileList.ItemsData};
        end

        % Initialisierung der zu entfernenden Indizes
        indicesToRemove = [];

        % Anzeige eines Fortschrittsdialogs
        d = uiprogressdlg(fig, 'Title', 'Bitte Warten', 'Message', 'Dateien werden gelöscht');
        factor = 1 / numel(selectedItems);

        % Finden der Indizes der zu entfernenden Elemente
        for i = 1:numel(selectedItems)
            index = find(cellfun(@(x) isequal(x, selectedItems{i}), fileList.ItemsData));
            if ~isempty(index)
                indicesToRemove = [indicesToRemove, index]; %#ok<AGROW> 
            end
            d.Value = factor * i;  % Fortschrittsanzeige aktualisieren
        end
        close(d);  % Schließen des Fortschrittsdialogs

        % Entfernen der Elemente aus der Liste, sortiert in absteigender Reihenfolge
        indicesToRemove = sort(indicesToRemove, 'descend');
        for i = 1:numel(indicesToRemove)
            fileList.Items(indicesToRemove(i)) = [];
            fileList.ItemsData(indicesToRemove(i)) = [];
        end

        % Zurücksetzen der Auswahl
        fileList.Value = {};

        if isempty(fileList.Items)
            % Suche nach dem CSV-Check-Element und setze seinen Wert auf false, falls nach der Löschung keine Dateien mehr geladen sind
            check = findobj(fig, 'Tag', 'csvCheck');
            check.Value = false;
        end
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException(fig, ME, 'Fehler beim Löschen der Dateien.');
    end
end

function Plot(fig, showAll)
    % Funktion zum Plotten der Daten
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    %    showAll (bool): Gibt an, ob alle Daten geplottet werden sollen
    %
    % Returns:
    %    None

    try
        % Überprüfen der Checkbox-Werte
        cdCheck = findobj(fig, 'Tag', 'cdCheck').Value;
        tdCheck = findobj(fig, 'Tag', 'tdCheck').Value;
        csvCheck = findobj(fig, 'Tag', 'csvCheck').Value;
        showPlotWindow = findobj(fig, 'Tag', 'showPlotWindow').Value;
        cdGridCheck = findobj(fig, 'Tag', 'cdGridCheck').Value;
        tdGridCheck = findobj(fig, 'Tag', 'tdGridCheck').Value;
        cdColorCheck = findobj(fig, 'Tag', 'cdColorCheck').Value;
        tdColorCheck = findobj(fig, 'Tag', 'tdColorCheck').Value;
        plotCheck = findobj(fig, 'Tag', 'plotCheck').Value;

        if ~showAll
            showPlotWindow = true;
        end

        % Einlesen und Verarbeiten der zu löschenden Zeilen für CD-Daten
        cdLinesToDelete = findobj(fig, 'Tag', 'cdLinesToDelete').Value;
        cdLinesToDelete = str2double(strsplit(cdLinesToDelete, ','));
        cdRowsToDelete = findobj(fig, 'Tag', 'cdRowsToDelete').Value;
        cdRowsToDelete = str2double(strsplit(cdRowsToDelete, ','));
        cdDel = all(~isnan(cdLinesToDelete)) && (length(cdLinesToDelete) == length(cdRowsToDelete));

        % Einlesen und Verarbeiten der zu löschenden Zeilen für TD-Daten
        tdLinesToDelete = findobj(fig, 'Tag', 'tdLinesToDelete').Value;
        tdLinesToDelete = str2double(strsplit(tdLinesToDelete, ','));
        tdRowsToDelete = findobj(fig, 'Tag', 'tdRowsToDelete').Value;
        tdRowsToDelete = str2double(strsplit(tdRowsToDelete, ','));
        tdDel = all(~isnan(tdLinesToDelete)) && (length(tdLinesToDelete) == length(tdRowsToDelete));

        % Einlesen weiterer Parameter aus der GUI
        area = findobj(fig, 'Tag', 'segmentArea').Value;
        framerate = findobj(fig, 'Tag', 'framerate').Value;
        frequency = findobj(fig, 'Tag', 'frequency').Value;
        infotext = findobj(fig, 'Tag', 'infoText');
        textCell = infotext.Value;

        if cdCheck && tdCheck
            % Fortschrittsdialog erstellen
            d = uiprogressdlg(fig, 'Title', 'Bitte Warten', 'Message', 'Daten werden geplottet');
            if showAll
                [file, path] = uiputfile('*.mp4', 'Speicherort für das Video auswählen');
                if isequal(file, 0) || isequal(path, 0)
                    disp('Videoerstellung abgebrochen');
                    return;
                end
                videoFileName = fullfile(path, file);
                v = VideoWriter(videoFileName, 'MPEG-4');
                v.FrameRate = framerate;
                open(v);
            end
            d.Value = 0.05;

            % CD-Daten aus dem Basis-Workspace abrufen und NaN-Werte entfernen
            allCdData = evalin("base", 'cdData');
            cdNaNIndex = find(isnan(allCdData{:, end}), 1) - 1;
            cdDataNoNaN = allCdData(~any(ismissing(allCdData), 2), :);
            cdDataNoNaN{:, :} = cdDataNoNaN{:, :} / area;

            d.Value = 0.1;

            % TD-Daten aus dem Basis-Workspace abrufen und NaN-Werte entfernen
            allTdData = evalin("base", 'tdData');
            tdNaNIndex = find(isnan(allTdData{:, end}), 1) - 1;
            tdDataNoNaN = allTdData(~any(ismissing(allTdData), 2), :);

            % Zeitstempel aus dem Basis-Workspace abrufen
            timestamps = evalin("base", 'timestamps');

            % Dateiliste aus der GUI abrufen
            fileList = findobj(fig, 'Tag', 'fileList');
            items = fileList.ItemsData;

            d.Value = 0.2;

            % CSV-Daten anhand der Zeitstempel abgleichen und verarbeiten
            if csvCheck
                csvData = compareTimeAndCSV(timestamps, items);
            else
                csvData = NaN;
            end

            % Neues Plot-Fenster erstellen
            p = figure('Units', 'normalized', 'OuterPosition', [0 0 1 1], 'Visible', showPlotWindow);

            % CD-Daten vorbereiten
            % Anzahl der Zeilen in der Tabelle
            numRows = size(cdDataNoNaN, 1);
            if cdDel
                for i = 1:length(cdLinesToDelete)
                    % Berechnen der kompletten Indizes für cdLinesToDelete(i)
                    indices = cdLinesToDelete(i):cdNaNIndex:numRows;

                    % Spaltenindex, der gelöscht werden soll
                    colIndex = cdRowsToDelete(i);

                    % Werte durch NaN ersetzen
                    cdDataNoNaN(indices, colIndex) = {NaN};
                end
            end
            cdDataNoNaN = fillmissing(cdDataNoNaN, 'linear');
            cdAbsoluteMin = -(max(cdDataNoNaN{:,:}, [], 'all'));
            cdAbsoluteMax = -(min(cdDataNoNaN{:,:}, [], 'all'));
            if cdAbsoluteMin > cdAbsoluteMax
                b = cdAbsoluteMin;
                cdAbsoluteMin = cdAbsoluteMax;
                cdAbsoluteMax = b;
                clear b;
            end

            cdData = cdDataNoNaN{1:cdNaNIndex, :};

            cdMin = min(min(cdData));
            cdMax = max(max(cdData));

            d.Value = 0.3;

            % Berechnung der ausgeglichenen Fläche
            balancedArea = calcBalancedArea(cdData, fig);

            % TD-Daten vorbereiten
            % Anzahl der Zeilen in der Tabelle
            numRows = size(tdDataNoNaN, 1);
            if tdDel
                for i = 1:length(tdLinesToDelete)
                    % Berechnen der kompletten Indizes für cdLinesToDelete(i)
                    indices = tdLinesToDelete(i):tdNaNIndex:numRows;

                    % Spaltenindex, der gelöscht werden soll
                    colIndex = tdRowsToDelete(i);

                    % Werte durch NaN ersetzen
                    tdDataNoNaN(indices, colIndex) = {NaN};
                end
            end
            tdDataNoNaN = fillmissing(tdDataNoNaN, 'linear');
            tdAbsoluteMin = min(tdDataNoNaN{:,:}, [], 'all');
            tdAbsoluteMax = max(tdDataNoNaN{:,:}, [], 'all');

            tdData = tdDataNoNaN{1:tdNaNIndex, :};

            d.Value = 0.45;

            % Initialisieren der Texte für die Annotationen
            initAnnotations(plotCheck);

            % Initialisieren der Plots
            [plot1, plot2, plot3] = initPlots(cdData, tdData, cdAbsoluteMin, cdAbsoluteMax, tdAbsoluteMin, tdAbsoluteMax, cdGridCheck, tdGridCheck, cdColorCheck, tdColorCheck, plotCheck, csvData);
            d.Value = 0.7;

            % Initialisieren des Zeitstempel-Textes und anderer CSV-Daten
            [timeText, csvText1, csvText2, csvText3, csvText4] = initCSVTextFields(timestamps, csvData, balancedArea, cdMin, cdMax, csvCheck);

            if showAll
                showVideoInfo(framerate, frequency)
                drawnow;
                frame = getframe(gcf);
                writeVideo(v, frame);
            end

            tic;
            cdIndices = 1:cdNaNIndex;
            tdIndices = 1:tdNaNIndex;

            d.Value = 1;
            close(d)
            l = length(timestamps);
            for i = 2:frequency:l
                if mod(i-2, frequency) == 0 && showAll && i > 2
                    timeS = toc;
                    fullTimeS = timeS * l / i;
                    timeLeftS = fullTimeS - timeS;
                    percentStr = [num2str(round(i / l * 100, 2)), '%'];
                    formattedTime = datestr(seconds(timeS), 'HH:MM:SS');
                    formattedFullTime = datestr(seconds(fullTimeS), 'HH:MM:SS');
                    formattedTimeLeft = datestr(seconds(timeLeftS), 'HH:MM:SS');
                    disp([percentStr, ': ', formattedTime, ' gesamt: ', formattedFullTime, ' verbleibend: ', formattedTimeLeft]);
                    textCell{5} = ['Messwert: ', num2str(i), ' von ', num2str(l), ' (', percentStr, ')'];
                    textCell{6} = ['Vergangene Zeit:		', formattedTime];
                    textCell{7} = ['Erwartete Gesamtzeit:	', formattedFullTime];
                    textCell{8} = ['Verbleibende Zeit:		', formattedTimeLeft];
                    infotext.Value = textCell;
                end

                if ~showAll
                    singleFrame = findobj(fig, 'Tag', 'singleFrame').Value; 
                    i = str2double(singleFrame); %#ok<FXSET> 
                    if isnan(i)
                        try
                            dt = datetime(singleFrame);
                        catch
                            try
                                dt = datetime(singleFrame, 'InputFormat', 'MM/dd/yyyy h:mm:ss a.SSS');
                            catch
                                dt = datetime(singleFrame, 'InputFormat', 'MM/dd/yyyy h:mm:ssa');
                            end
                        end
                        timestampsArray = datetime(timestamps, 'InputFormat', 'MM/dd/yyyy h:mm:ssa.SSS');
                        differences = abs(timestampsArray - dt);
                        [~, i] = min(differences); %#ok<FXSET> 
                    end
                end

                cdData = updateData(cdDataNoNaN, cdIndices, cdNaNIndex, i, 1);
                balancedArea = calcBalancedArea(cdData, fig);

                tdData = updateData(tdDataNoNaN, tdIndices, tdNaNIndex, i, 0);

                updatePlots(plot1, plot2, plot3, cdData, tdData);

                if plotCheck
                    % Hole das axes Handle
                    ax4 = evalin("base", 'ax4');
                
                    % Lösche alte Linie falls vorhanden
                    oldLine = getappdata(ax4, 'currentIndexLine');
                    if ~isempty(oldLine) && isvalid(oldLine)
                        delete(oldLine);
                    end
                
                    % Zeichne neue vertikale Linie bei aktuellem Index i
                    hold(ax4, 'on');
                    newLine = plot(ax4, [i i], ylim(ax4), 'r-', 'LineWidth', 2);
                    hold(ax4, 'off');
                
                    % Speichere Handle für nächste Iteration
                    setappdata(ax4, 'currentIndexLine', newLine);
                end

                cdMin = min(min(cdData));
                cdMax = max(max(cdData));
                
                if csvCheck
                    csvDataI = csvData(i, :);
                else
                    csvDataI = cell(1, 17);
                end
                updateCSVTextFields(timeText, csvText1, csvText2, csvText3, csvText4, timestamps, csvDataI, i, balancedArea, cdMin, cdMax);

                drawnow;

                if ~showAll
                    return;
                else
                    frame = getframe(gcf);
                    writeVideo(v, frame);
                end
            end
            if showAll
                close(v);
            end
            toc
            if ~showPlotWindow
                delete(p)
                clear p
            end
        end
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException(fig, ME, 'Fehler beim Plotten.');
        if ~showPlotWindow
            delete(p)
            clear p
        end
    end
end

function initAnnotations(plotCheck)
    % Initialisiert die Annotationen für den Plot
    %
    % Args:
    %    None
    %
    % Returns:
    %    None

    try
        config = evalin("base", 'config');
        plotOffset = 0;
        if plotCheck
            plotOffset = 0.14;
        end
        anodeIn = config.anodeIn;
        switch anodeIn
            case 'X=Y=1'
                arrowAnIn = '\uparrow';
                posLabelAnIn = [0.105 0.08+plotOffset 0.1 0.1];
                posArrowAnInCD = [0.645 0.095+plotOffset 0.1 0.1];
                posArrowAnInTD = [0.895 0.095+plotOffset 0.1 0.1];
                posH2AnInCD = [0.64 0.075+plotOffset 0.1 0.1];
                posH2AnInTD = [0.89 0.075+plotOffset 0.1 0.1];
            case 'X>Y=1'
                arrowAnIn = '\uparrow';
                posLabelAnIn = [0 0.205+plotOffset 0.1 0.1];
                posArrowAnInCD = [0.5 0.095+plotOffset 0.1 0.1];
                posArrowAnInTD = [0.75 0.095+plotOffset 0.1 0.1];
                posH2AnInTD = [0.495 0.075+plotOffset 0.1 0.1];
                posH2AnInCD = [0.745 0.075+plotOffset 0.1 0.1];
            case 'Y>X=1'
                arrowAnIn = '\downarrow';
                posLabelAnIn = [0.36 0.265+plotOffset 0.1 0.1];
                posArrowAnInCD = [0.645 0.667+plotOffset 0.1 0.1];
                posArrowAnInTD = [0.895 0.667+plotOffset 0.1 0.1];
                posH2AnInTD = [0.64 0.69+plotOffset 0.1 0.1];
                posH2AnInCD = [0.89 0.69+plotOffset 0.1 0.1];
            case 'X>1<Y'
                arrowAnIn = '\downarrow';
                posLabelAnIn = [0.3 0.48+plotOffset 0.1 0.1];
                posArrowAnInCD = [0.5 0.667+plotOffset 0.1 0.1];
                posArrowAnInTD = [0.75 0.667+plotOffset 0.1 0.1];
                posH2AnInTD = [0.495 0.69+plotOffset 0.1 0.1];
                posH2AnInCD = [0.745 0.69+plotOffset 0.1 0.1];
        end
        annotation('textbox', posLabelAnIn, 'String', 'Anode In', 'EdgeColor', 'none', 'FontSize', 13, 'Color', 'k');
        annotation('textbox', posArrowAnInCD, 'String', arrowAnIn, 'EdgeColor', 'none', 'FontSize', 10, 'Color', 'k');
        annotation('textbox', posH2AnInCD, 'String', 'H2', 'EdgeColor', 'none', 'FontSize', 13, 'Color', 'k');
        annotation('textbox', posArrowAnInTD, 'String', arrowAnIn, 'EdgeColor', 'none', 'FontSize', 10, 'Color', 'k');
        annotation('textbox', posH2AnInTD, 'String', 'H2', 'EdgeColor', 'none', 'FontSize', 13, 'Color', 'k');

        anodeOut = config.anodeOut;
        switch anodeOut
            case 'X=Y=1'
                arrowAnOut = '\downarrow';
                posLabelAnOut = [0.105 0.08+plotOffset 0.1 0.1];
                posArrowAnOutCD = [0.645 0.095+plotOffset 0.1 0.1];
                posArrowAnOutTD = [0.895 0.095+plotOffset 0.1 0.1];
                posH2AnOutCD = [0.64 0.075+plotOffset 0.1 0.1];
                posH2AnOutTD = [0.89 0.075+plotOffset 0.1 0.1];
            case 'X>Y=1'
                arrowAnOut = '\downarrow';
                posLabelAnOut = [0 0.205+plotOffset 0.1 0.1];
                posArrowAnOutCD = [0.5 0.095+plotOffset 0.1 0.1];
                posArrowAnOutTD = [0.75 0.095+plotOffset 0.1 0.1];
                posH2AnOutCD = [0.495 0.075+plotOffset 0.1 0.1];
                posH2AnOutTD = [0.745 0.075+plotOffset 0.1 0.1];
            case 'Y>X=1'
                arrowAnOut = '\uparrow';
                posLabelAnOut = [0.36 0.265+plotOffset 0.1 0.1];
                posArrowAnOutCD = [0.645 0.667+plotOffset 0.1 0.1];
                posArrowAnOutTD = [0.895 0.667+plotOffset 0.1 0.1];
                posH2AnOutCD = [0.64 0.69+plotOffset 0.1 0.1];
                posH2AnOutTD = [0.89 0.69+plotOffset 0.1 0.1];
            case 'X>1<Y'
                arrowAnOut = '\uparrow';
                posLabelAnOut = [0.3 0.48+plotOffset 0.1 0.1];
                posArrowAnOutCD = [0.5 0.667+plotOffset 0.1 0.1];
                posArrowAnOutTD = [0.75 0.667+plotOffset 0.1 0.1];
                posH2AnOutCD = [0.495 0.69+plotOffset 0.1 0.1];
                posH2AnOutTD = [0.745 0.69+plotOffset 0.1 0.1];
        end
        annotation('textbox', posLabelAnOut, 'String', 'Anode Out', 'EdgeColor', 'none', 'FontSize', 13, 'Color', 'k');
        annotation('textbox', posArrowAnOutCD, 'String', arrowAnOut, 'EdgeColor', 'none', 'FontSize', 10, 'Color', 'k');
        annotation('textbox', posH2AnOutCD, 'String', 'H2', 'EdgeColor', 'none', 'FontSize', 13, 'Color', 'k');
        annotation('textbox', posArrowAnOutTD, 'String', arrowAnOut, 'EdgeColor', 'none', 'FontSize', 10, 'Color', 'k');
        annotation('textbox', posH2AnOutTD, 'String', 'H2', 'EdgeColor', 'none', 'FontSize', 13, 'Color', 'k');

       cathodeIn = config.cathodeIn;
       switch cathodeIn
            case 'X=Y=1'
                arrowCaIn = '\uparrow';
                posLabelCaIn = [0.105 0.08+plotOffset 0.1 0.1];
                posArrowCaInCD = [0.645 0.095+plotOffset 0.1 0.1];
                posArrowCaInTD = [0.895 0.095+plotOffset 0.1 0.1];
                posH2CaInCD = [0.64 0.075+plotOffset 0.1 0.1];
                posH2CaInTD = [0.89 0.075+plotOffset 0.1 0.1];
            case 'X>Y=1'
                arrowCaIn = '\uparrow';
                posLabelCaIn = [0 0.205+plotOffset 0.1 0.1];
                posArrowCaInCD = [0.5 0.095+plotOffset 0.1 0.1];
                posArrowCaInTD = [0.75 0.095+plotOffset 0.1 0.1];
                posH2CaInCD = [0.495 0.075+plotOffset 0.1 0.1];
                posH2CaInTD = [0.745 0.075+plotOffset 0.1 0.1];
            case 'Y>X=1'
                arrowCaIn = '\downarrow';
                posLabelCaIn = [0.36 0.265+plotOffset 0.1 0.1];
                posArrowCaInCD = [0.645 0.667+plotOffset 0.1 0.1];
                posArrowCaInTD = [0.895 0.667+plotOffset 0.1 0.1];
                posH2CaInCD = [0.64 0.69+plotOffset 0.1 0.1];
                posH2CaInTD = [0.89 0.69+plotOffset 0.1 0.1];
            case 'X>1<Y'
                arrowCaIn = '\downarrow';
                posLabelCaIn = [0.3 0.48+plotOffset 0.1 0.1];
                posArrowCaInCD = [0.5 0.667+plotOffset 0.1 0.1];
                posArrowCaInTD = [0.75 0.667+plotOffset 0.1 0.1];
                posH2CaInCD = [0.495 0.69+plotOffset 0.1 0.1];
                posH2CaInTD = [0.745 0.69+plotOffset 0.1 0.1];
        end
        annotation('textbox', posLabelCaIn, 'String', 'Cathode In', 'EdgeColor', 'none', 'FontSize', 13, 'Color', 'k');
        annotation('textbox', posArrowCaInCD, 'String', arrowCaIn, 'EdgeColor', 'none', 'FontSize', 10, 'Color', 'k');
        annotation('textbox', posH2CaInCD, 'String', 'O2', 'EdgeColor', 'none', 'FontSize', 13, 'Color', 'k');
        annotation('textbox', posArrowCaInTD, 'String', arrowCaIn, 'EdgeColor', 'none', 'FontSize', 10, 'Color', 'k');
        annotation('textbox', posH2CaInTD, 'String', 'O2', 'EdgeColor', 'none', 'FontSize', 13, 'Color', 'k');
        
        cathodeOut = config.cathodeOut;
        switch cathodeOut
            case 'X=Y=1'
                arrowCaOut = '\downarrow';
                posLabelCaOut = [0.105 0.08+plotOffset 0.1 0.1];
                posArrowCaOutCD = [0.645 0.095+plotOffset 0.1 0.1];
                posArrowCaOutTD = [0.895 0.095+plotOffset 0.1 0.1];
                posH2CaOutCD = [0.64 0.075+plotOffset 0.1 0.1];
                posH2CaOutTD = [0.89 0.075+plotOffset 0.1 0.1];
            case 'X>Y=1'
                arrowCaOut = '\downarrow';
                posLabelCaOut = [0 0.205+plotOffset 0.1 0.1];
                posArrowCaOutCD = [0.5 0.095+plotOffset 0.1 0.1];
                posArrowCaOutTD = [0.75 0.095+plotOffset 0.1 0.1];
                posH2CaOutCD = [0.495 0.075+plotOffset 0.1 0.1];
                posH2CaOutTD = [0.745 0.075+plotOffset 0.1 0.1];
            case 'Y>X=1'
                arrowCaOut = '\uparrow';
                posLabelCaOut = [0.36 0.265+plotOffset 0.1 0.1];
                posArrowCaOutCD = [0.645 0.667+plotOffset 0.1 0.1];
                posArrowCaOutTD = [0.895 0.667+plotOffset 0.1 0.1];
                posH2CaOutCD = [0.64 0.69+plotOffset 0.1 0.1];
                posH2CaOutTD = [0.89 0.69+plotOffset 0.1 0.1];
            case 'X>1<Y'
                arrowCaOut = '\uparrow';
                posLabelCaOut = [0.3 0.48+plotOffset 0.1 0.1];
                posArrowCaOutCD = [0.5 0.667+plotOffset 0.1 0.1];
                posArrowCaOutTD = [0.75 0.667+plotOffset 0.1 0.1];
                posH2CaOutCD = [0.495 0.69+plotOffset 0.1 0.1];
                posH2CaOutTD = [0.745 0.69+plotOffset 0.1 0.1];
        end
        annotation('textbox', posLabelCaOut, 'String', 'Cathode Out', 'EdgeColor', 'none', 'FontSize', 13, 'Color', 'k');
        annotation('textbox', posArrowCaOutCD, 'String', arrowCaOut, 'EdgeColor', 'none', 'FontSize', 10, 'Color', 'k');
        annotation('textbox', posH2CaOutCD, 'String', 'O2', 'EdgeColor', 'none', 'FontSize', 13, 'Color', 'k');
        annotation('textbox', posArrowCaOutTD, 'String', arrowCaOut, 'EdgeColor', 'none', 'FontSize', 10, 'Color', 'k');
        annotation('textbox', posH2CaOutTD, 'String', 'O2', 'EdgeColor', 'none', 'FontSize', 13, 'Color', 'k');

        
        annotation('textbox', [0.5 0.15+plotOffset 0.16 0.01], 'String', 'Current distribution', 'EdgeColor', 'none', 'FontSize', 14, 'Color', 'k', ...
            'FontWeight', 'bold', 'HorizontalAlignment', 'center');
        annotation('textbox', [0.73 0.15+plotOffset 0.2 0.01], 'String', 'Temperature distribution', 'EdgeColor', 'none', 'FontSize', 14, 'Color', 'k', ...
            'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        fig = gcf; % Holt das aktuelle Figure-Handle
        handleException(fig, ME, 'Fehler beim Erstellen der Beschriftungen.');
    end
end

function [plot1, plot2, plot3] = initPlots(cdData, tdData, cdAbsoluteMin, cdAbsoluteMax, tdAbsoluteMin, tdAbsoluteMax, cdGridCheck, tdGridCheck, cdColorCheck, tdColorCheck, plotCheck, csvData)
    % Initialisiert die Plots
    %
    % Args:
    %    cdData (matrix): Datenmatrix für die Stromdichte
    %    tdData (matrix): Datenmatrix für die Temperatur
    %    area (double): Fläche zur Normalisierung der Stromdichte
    %    cdAbsoluteMin (double): Minimalwert für die Stromdichte-Achse
    %    cdAbsoluteMax (double): Maximalwert für die Stromdichte-Achse
    %    tdAbsoluteMin (double): Minimalwert für die Temperatur-Achse
    %    tdAbsoluteMax (double): Maximalwert für die Temperatur-Achse
    %
    % Returns:
    %    plot1 (surface): 3D-Plot der Stromdichte
    %    plot2 (surface): 3D-Plot der Stromdichte (kleiner Bereich)
    %    plot3 (surface): 3D-Plot der Temperatur

    try
        config = evalin("base", 'config');
        plotOffset = 0;
        if plotCheck
            plotOffset = 0.14;
        end
        % Erstellt ein Meshgrid für die Plotdaten
        [X, Y] = meshgrid(1:size(cdData, 2), 1:size(cdData, 1));

        % Erster Plot: Stromdichte in 3D
        ax1 = axes('Position', [0.05, 0.06+plotOffset, 0.35, 0.8]);
        plot1 = surf(ax1, X, Y, -cdData);
        configurePlot(ax1, cdAbsoluteMin, cdAbsoluteMax, 'Current density [A/cm²]', cdColorCheck, plotOffset);

        % Zweiter Plot: Stromdichte von oben
        ax2 = axes('Position', [0.50, 0.185+plotOffset, 0.16, 0.55]);
        plot2 = surf(ax2, X, Y, -cdData);
        configurePlot(ax2, cdAbsoluteMin, cdAbsoluteMax, cdGridCheck, cdColorCheck, plotOffset);

        % Erstellt ein Meshgrid für die Temperaturdaten
        [X, Y] = meshgrid(1:size(tdData, 2), 1:size(tdData, 1));

        % Dritter Plot: Temperatur
        ax3 = axes('Position', [0.75, 0.185+plotOffset, 0.16, 0.55]);
        plot3 = surf(ax3, X, Y, tdData);
        configurePlot(ax3, tdAbsoluteMin, tdAbsoluteMax, tdGridCheck, tdColorCheck, plotOffset);
        
        if plotCheck
            nRows = size(csvData,1);
            
            % Initialisiere numerische Arrays mit NaN
            numCol3 = NaN(nRows,1);
            numCol18 = NaN(nRows,1);
            
            for i = 1:nRows
                % Spalte 3
                val3 = csvData{i,3};
                if ~isempty(val3) && isnumeric(val3)
                    numCol3(i) = val3;
                end
                
                % Spalte 18
                val18 = csvData{i,18};
                if ~isempty(val18) && isnumeric(val18)
                    numCol18(i) = val18;
                end
            end
            
            % Finde gültige Indizes, bei denen mindestens einer der Werte nicht NaN ist
            validIdx = ~isnan(numCol3) | ~isnan(numCol18);
            
            x = find(validIdx);
            y3 = numCol3(validIdx);
            y18 = numCol18(validIdx);
            
            % Plotten
            ax4 = axes('Position', [0.05, 0.03, 0.9, 0.22]);
            % Speichere ax4 im Figure-Handle für späteren Zugriff
            assignin("base", 'ax4', ax4)
            axes(ax4);
            
            yyaxis left;
            hex = config.Farbe_I;
            rgb = sscanf(hex(2:end),'%2x%2x%2x',[1 3])/255;
            plot(x, y18, '-', 'Color', rgb, 'LineWidth', 1);
            ylabel('Current [A]', 'Color', rgb);
            ax4.YColor = rgb;
            minY1 = min(y18);
            maxY1 = max(y18);
            puffer1 = 0.05 * (maxY1 - minY1); % 5% Puffer nach oben und unten
            ylim([minY1 - puffer1, maxY1 + puffer1]);

            yyaxis right;
            hex = config.Farbe_U;
            rgb = sscanf(hex(2:end),'%2x%2x%2x',[1 3])/255;
            plot(x, y3, '-', 'Color', rgb, 'LineWidth', 1);
            ylabel('Voltage [V]', 'Color', rgb);
            ax4.YColor = rgb; 
            minY1 = min(y3);
            maxY1 = max(y3);
            puffer1 = 0.05 * (maxY1 - minY1); % 5% Puffer nach oben und unten
            ylim([minY1 - puffer1, maxY1 + puffer1]);

            xticks(ax4, []);
            xlim([1, x(end)]);
        end
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException([], ME, 'Fehler beim Initialisieren der Plots.');
    end
end

function configurePlot(ax, zMin, zMax, gridOrZLabel, colorCheck, plotOffset)
    % Konfiguriert die Eigenschaften eines Plots
    %
    % Args:
    %    ax (axes): Achsenobjekt des Plots
    %    zMin (double): Minimalwert der Z-Achse
    %    zMax (double): Maximalwert der Z-Achse
    %    zLabel (string, optional): Label der Z-Achse
    %
    % Returns:
    %    None

    try
        % Setzt die Achsen- und Plot-Eigenschaften
        axis(ax, 'equal');
        zlim(ax, [zMin - 0.5 zMax + 0.5]);

        if colorCheck
            caxis(ax, [zMin zMax]);
        end

        colormap(ax, 'jet');
        hcb = colorbar(ax);
        hcb.Position = [ax.Position(1) + ax.Position(3) + 0.03, 0.11+plotOffset*1.1, 0.015, 0.7-0.3*plotOffset];
        view(ax, [55 35]);
        set(ax, 'XDir', 'reverse');
        xticks(ax, [1 round(ax.XLim(1,2) / 2) ax.XLim(1,2)]);
        yticks(ax, [1 round(ax.YLim(1,2) / 2) ax.YLim(1,2)]);

        if ~islogical(gridOrZLabel)
            % Anpassungen, wenn ein zLabel angegeben ist
            hcb.Position = [ax.Position(1) + ax.Position(3) + 0.04, 0.11+plotOffset*1.1, 0.015, 0.7-0.3*plotOffset];
            ax.ZLabel.String = ['\fontsize{14} ', gridOrZLabel];
            set(ax, 'DataAspectRatio', [1 1 0.25]);
            shading(ax, 'interp');
        else
            % Anpassungen, wenn kein zLabel angegeben ist
            hcb.Position = [ax.Position(1) + ax.Position(3) + 0.02, 0.11+plotOffset*1.1, 0.015, 0.7-0.3*plotOffset];
            view(ax, 2);
            xticks(ax, []);
            yticks(ax, []);
            if ~gridOrZLabel
                shading(ax, 'interp');
            end
        end

    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException([], ME, 'Fehler beim Konfigurieren des Plots.');
    end
end

function [timeText, csvText1, csvText2, csvText3, csvText4] = initCSVTextFields(timestamps, csvData, balancedArea, cdMin, cdMax, csvCheck)
    % Initialisiert die Textfelder für die CSV-Daten
    %
    % Args:
    %    timestamps (cell array): Zeitstempel der Daten
    %    csvData (cell array): CSV-Daten
    %    balancedArea (double): Berechnete ausgeglichene Fläche in Prozent
    %    cdMin (double): Minimalwert der Stromdichte
    %    cdMax (double): Maximalwert der Stromdichte
    %
    % Returns:
    %    timeText (textbox): Textfeld für den Zeitstempel
    %    csvText1 (textbox): Textfeld für Stromdichte und Spannung
    %    csvText2 (textbox): Textfeld für Stöchiometrie, Durchfluss und Kühlmitteltemperatur
    %    csvText3 (textbox): Textfeld für Druckdifferenz und Druck an Ein- und Auslass
    %    csvText4 (textbox): Textfeld für Temperatur, ausgeglichene Fläche und Stromdichte

    try
        % Initialisiert die verschiedenen Textfelder für die CSV-Daten
        if ~csvCheck
            csvData = cell(1, 17);
        end
        timeText = annotation('textbox', [0 0.965 0.235 0.035], 'String', ['Time: ', timestamps{1}], 'EdgeColor', 'none', 'FontSize', 12, 'Color', 'k');
        annotation('textbox', [0 0.9 0.105 0.1], 'EdgeColor', 'none', 'FontSize', 12, 'Color', 'k', 'String', {'', 'Current Density:', 'Voltage:'});
        csvText1 = annotation('textbox', [0.098 0.9 0.05 0.1], 'EdgeColor', 'none', 'FontSize', 12, 'Color', 'k', 'HorizontalAlignment', 'right', ...
            'String', {'', num2str(csvData{1, 2}, '%.2f'), num2str(csvData{1, 3}, '%.3f')});
        annotation('textbox', [0.143 0.9 0.048 0.1], 'EdgeColor', 'none', 'FontSize', 12, 'Color', 'k', 'String', {'', '[A/cm²]', '[V]'});
        annotation('textbox', [0.2455 0.9 0.128 0.1], 'EdgeColor', 'none', 'FontSize', 12, 'Color', 'k', 'String', {'stoic A/C:', 'mflow An/Ca:', 'Coolant Temp in/out:'});
        csvText2 = annotation('textbox', [0.3739 0.9 0.065 0.1], 'EdgeColor', 'none', 'FontSize', 12, 'Color', 'k', 'HorizontalAlignment', 'center', ...
            'String', {[num2str(csvData{1, 4}, '%.2f'), '/', num2str(csvData{1, 5}, '%.2f')], [num2str(csvData{1, 6}, '%.2f'), '/', num2str(csvData{1, 7}, '%.2f')], ...
            [num2str(csvData{1, 8}, '%.1f'), '/', num2str(csvData{1, 9}, '%.1f')]});
        annotation('textbox', [0.4334 0.9 0.05 0.1], 'EdgeColor', 'none', 'FontSize', 12, 'Color', 'k', 'String', {'', '[nl/min]', '[°C]'});
        annotation('textbox', [0.5379 0.9 0.092 0.1], 'EdgeColor', 'none', 'FontSize', 12, 'Color', 'k', 'String', {'DP A/C:', 'P An In/Out:', 'P Cath In/Out:'});
        csvText3 = annotation('textbox', [0.6239 0.9 0.077 0.1], 'EdgeColor', 'none', 'FontSize', 12, 'Color', 'k', 'HorizontalAlignment', 'center', ...
            'String', {[num2str(csvData{1, 10}, '%.1f'), '/', num2str(csvData{1, 11}, '%.1f')], ...
            [num2str(csvData{1, 12}, '%.3f'), '/', num2str(csvData{1, 13}, '%.3f')], [num2str(csvData{1, 14}, '%.3f'), '/', num2str(csvData{1, 15}, '%.3f')]});
        annotation('textbox', [0.6959 0.9 0.041 0.1], 'EdgeColor', 'none', 'FontSize', 12, 'Color', 'k', 'String', {'[°C]', '[bara]', '[bara]'});
        annotation('textbox', [0.7915 0.9 0.092 0.1], 'EdgeColor', 'none', 'FontSize', 12, 'Color', 'k', 'String', ...
            {'Temp An/Ca:', 'Balance area:', 'CSS min/max:'});
        csvText4 = annotation('textbox', [0.8795 0.9 0.075 0.1], 'EdgeColor', 'none', 'FontSize', 12, 'Color', 'k', 'HorizontalAlignment', 'center', ...
            'String', {[num2str(csvData{1, 16}, '%.1f'), '/', num2str(csvData{1, 17}, '%.1f')], num2str(balancedArea, '%.2f'), ...
            [num2str(cdMin, '%.3f'), '/', num2str(cdMax, '%.3f')]});
        annotation('textbox', [0.95 0.9 0.05 0.1], 'EdgeColor', 'none', 'FontSize', 12, 'Color', 'k', 'String', {'[°C]', '[%]', '[A/cm²]'});

    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException([], ME, 'Fehler beim Initialisieren der CSV-Textfelder.');
    end
end

function showVideoInfo(framerate, frequency)
    if frequency == 1
        annotation('textbox', [0 0 0.5 0.035], 'String', ['Jeder Messwert wird angezeigt.  Videogeschwindigkeit: ', num2str(framerate), ' FPS'], ...
            'EdgeColor', 'none', 'FontSize', 12, 'Color', 'k', 'VerticalAlignment', 'bottom');
    else
        annotation('textbox', [0 0 0.5 0.035], 'String', ['Jeder ', num2str(frequency), '. Messwert wird angezeigt.  Videogeschwindigkeit: ', num2str(framerate), ' FPS'], ...
            'EdgeColor', 'none', 'FontSize', 12, 'Color', 'k', 'VerticalAlignment', 'bottom');
    end
end

function data = updateData(dataNoNaN, indices, NaNIndex, i, cd)
    % Aktualisiert die Daten für den aktuellen Zeitschritt
    %
    % Args:
    %    dataNoNaN (cell array): Daten ohne NaN-Werte
    %    indices (integer): Indizes der aktuellen Daten
    %    NaNIndex (integer): NaN-Index zur Berechnung
    %    i (integer): Aktueller Zeitschritt
    %    del (logical): Flag zum Löschen von Zeilen
    %    linesToDelete (array): Zeilen, die gelöscht werden sollen
    %    rowsToDelete (array): Spalten, die gelöscht werden sollen
    %    area (double): Fläche zur Normalisierung der Daten (optional)
    %
    % Returns:
    %    data (matrix): Aktualisierte Datenmatrix

    try
        % Aktualisiert die Daten für den aktuellen Zeitschritt
        data = dataNoNaN{indices + (i-1)*NaNIndex, :};
        
        data = fillmissing(data, 'linear');
        
        if cd
            data = abs(data);
        end

    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException([], ME, 'Fehler beim Anpassen der Daten.');
    end
end

function updatePlots(plot1, plot2, plot3, cdData, tdData)
    % Aktualisiert die Plots mit den neuen Daten
    %
    % Args:
    %    plot1 (surface): 3D-Plot der Stromdichte
    %    plot2 (surface): 3D-Plot der Stromdichte (kleiner Bereich)
    %    plot3 (surface): 3D-Plot der Temperatur
    %    cdData (matrix): Datenmatrix für die Stromdichte
    %    tdData (matrix): Datenmatrix für die Temperatur
    %
    % Returns:
    %    None

    try
        % Aktualisiert die Z-Daten der Plots
        set(plot1, 'ZData', cdData);
        set(plot2, 'ZData', cdData);
        set(plot3, 'ZData', tdData);

    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException([], ME, 'Fehler beim Aktualisieren der Plots.');
    end
end

function updateCSVTextFields(timeText, csvText1, csvText2, csvText3, csvText4, timestamps, csvData, i, balancedArea, cdMin, cdMax)
    % Aktualisiert die Textfelder mit den neuen CSV-Daten
    %
    % Args:
    %    timeText (textbox): Textfeld für den Zeitstempel
    %    csvText1 (textbox): Textfeld für die ersten CSV-Daten
    %    csvText2 (textbox): Textfeld für die zweiten CSV-Daten
    %    csvText3 (textbox): Textfeld für die dritten CSV-Daten
    %    csvText4 (textbox): Textfeld für die vierten CSV-Daten
    %    timestamps (cell array): Liste der Zeitstempel
    %    csvData (cell array): Liste der CSV-Daten
    %    i (int): Index des aktuellen Zeitpunkts
    %    balancedArea (double): Berechnete ausgeglichene Fläche
    %    cdMin (double): Minimum der Stromdichte
    %    cdMax (double): Maximum der Stromdichte
    %
    % Returns:
    %    None

    try
        % Aktualisiert das Zeitstempel-Textfeld
        set(timeText, 'String', ['Time: ', timestamps{i}]);

        if iscell(csvData)
            % Aktualisiert das erste CSV-Textfeld mit formatierten Daten
            set(csvText1, 'String', {'', num2str(csvData{1, 2}, '%.2f'), num2str(csvData{1, 3}, '%.3f')});
    
            % Aktualisiert das zweite CSV-Textfeld mit formatierten Daten
            set(csvText2, 'String', {[num2str(csvData{1, 4}, '%.2f'), '/', num2str(csvData{1, 5}, '%.2f')], ...
                                     [num2str(csvData{1, 6}, '%.2f'), '/', num2str(csvData{1, 7}, '%.2f')], ...
                                     [num2str(csvData{1, 8}, '%.1f'), '/', num2str(csvData{1, 9}, '%.1f')]});
    
            % Aktualisiert das dritte CSV-Textfeld mit formatierten Daten
            set(csvText3, 'String', {[num2str(csvData{1, 10}, '%.1f'), '/', num2str(csvData{1, 11}, '%.1f')], ...
                                     [num2str(csvData{1, 12}, '%.3f'), '/', num2str(csvData{1, 13}, '%.3f')], ...
                                     [num2str(csvData{1, 14}, '%.3f'), '/', num2str(csvData{1, 15}, '%.3f')]});
    
            % Aktualisiert das vierte CSV-Textfeld mit formatierten Daten
            set(csvText4, 'String', {[num2str(csvData{1, 16}, '%.1f'), '/', num2str(csvData{1, 17}, '%.1f')], ...
                                     num2str(balancedArea, '%.2f'), ...
                                     [num2str(cdMin, '%.3f'), '/', num2str(cdMax, '%.3f')]});
        end
    catch ME
        % Fehlerbehandlung: zeigt eine Fehlermeldung an und protokolliert den Fehler
        handleException([], ME, 'Fehler beim Aktualisieren der CSV-Textfelder.');
    end
end

function handleException(fig, ME, message)
    % Hilfsfunktion zum Anzeigen von Fehlern in einem UI-Alert
    %
    % Args:
    %    fig (figure): Das GUI-Fenster
    %    ME (MException): Die Ausnahme, die abgefangen wurde
    %    message (string): Die Fehlermeldung, die angezeigt werden soll
    %
    % Returns:
    %    None

    if ~exist("fig", 'var') || isempty(fig)
        fig = uifigure();
    end
    uialert(fig, ME.message, message);
    disp(ME.message);
end

function csvData = compareTimeAndCSV(timestamps, items)
    % Vergleicht die Timestamps der .dat und der .csv-Dateien und ordnet sie einander zu
    %
    % Args:
    %    timestamps (cell array): Liste der Zeitstempel
    %    items (cell array): Liste der CSV-Daten
    %
    % Returns:
    %    csvData (cell array): Angepasste CSV-Daten

    try
        % Konvertiere Zeitstempel zu datetime-Objekten
        timestamps = datetime(timestamps', 'InputFormat', 'MM/dd/yyyy h:mm:ss a.SSS');

        % Berechne Zeitdifferenzen zwischen Einträgen
        delta_csv = seconds(mean(diff([items{1}{1:end, 1}])));
        delta_dat = seconds(mean(diff(timestamps)));
        factor = round(delta_dat / delta_csv);

        if factor < 1
            factor = 1;
            handleException('', ['Abstand zwischen csv-Messwerten ist größer als zwischen dat-Messwerten, eventuell werden für die Parameter oben ' ...
                'deswegen falsche Werte angezeigt'], 'Fehler beim Vergleichen der Timestamps.');
        end

        % Anpassung der CSV-Daten durch Faktor
        n = length(items);
        if factor > 1
            for i = 1:n
                items{i} = items{i}(1:factor:end, :);
            end
            delta_csv = delta_csv * factor;
        end

        % Berechne fehlende Werte zwischen CSV-Dateien
        missing_between_csv_files = NaN(1, n-1);
        for i = 2:n
            delta_csv_files = seconds(items{i}{1, 1} - items{i-1}{end, 1});
            missing_between_csv_files(i-1) = round(delta_csv_files / delta_csv - 1);
        end

        % Bestimme die Länge der CSV-Dateien
        lengths = nan(1, n);
        [l, b] = size(items{1});
        lengths(1) = l;
        for i = 2:n
            lengths(i) = length(items{i});
        end

        % Initialisiere csvData
        csvData = cell(length(timestamps), b);

        % Finde den minimalen Index für die Zuordnung
        [~, min_index] = min(abs([items{1}{1:end, 1}] - timestamps(1)));
        [~, min_check] = min(abs([items{1}{min_index, 1}] - timestamps));

        % Fülle csvData für das erste Element
        for row = min_check:(lengths(1) - (min_index - 1) + min_check - 1)
            csvData(row, :) = items{1}(min_index + row - 1 - min_check + 1, :);
        end 

        % Fülle csvData für die restlichen Elemente
        current_index = lengths(1) - (min_index - 1) + min_check - 1;
        for i = 2:n
            current_index = current_index + missing_between_csv_files(i-1);
            for row = 1:lengths(i)
                current_index = current_index + 1;
                csvData(current_index, :) = items{i}(row, :);
            end
        end

    catch ME
        handleException('', ME, 'Fehler beim Vergleichen der Timestamps.');
    end
end

function balancedArea = calcBalancedArea(data, fig)
    % Berechnet die Balanced Area basierend auf den Daten und den Deviation Balanced Area Parameter
    %
    % Args:
    %    data (matrix): Die Datenmatrix
    %    fig (figure): Das GUI-Fenster
    %
    % Returns:
    %    balancedArea (double): Die berechnete ausgeglichene Fläche in Prozent

    try
        % Hole den Deviation Balanced Area Parameter aus der GUI
        deviationBalancedArea = findobj(fig, 'Tag', 'deviationBalancedArea').Value / 100;
        [x, y] = size(data);

        % Berechne den Mittelwert der absoluten Werte der Daten
        mittelwert = abs(mean(mean(data)));
        numBalanced = 0;

        % Zähle die Anzahl der Werte, die innerhalb des erlaubten Abweichungsbereichs liegen
        for a = 1:x
            for b = 1:y
                difference = abs(data(a, b)) / mittelwert - 1;
                if -deviationBalancedArea <= difference && difference <= deviationBalancedArea
                    numBalanced = numBalanced + 1;
                end
            end
        end

        % Berechne die ausgeglichene Fläche in Prozent
        balancedArea = numBalanced / (x * y) * 100;

    catch ME
        handleException(fig, ME, 'Fehler beim Berechnen der balanced Area.');
    end
end