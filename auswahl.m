%% Setup- und Initialisierungsfunktionen
function Auswahl(existingFig)
    % Hauptfunktion, die den Auswahlbildschirm erstellt und steuert.
    % Diese Funktion initialisiert das Auswahlfenster und erstellt die
    % notwendigen Knöpfe und Labels für die verschiedenen Methoden.
    try
        % Definition der Abstände und Größen
        margin = 20;
        labelHeight = 20;
        btnWidth = 273.3333;
        btnHeight = 160;
        exitBtnHeight = 50;
        % Anzahl der Spalten und Zeilen für die Buttons
        numColumns = 3;
        if nargin < 1 || isempty(existingFig) || ~isvalid(existingFig)
            % Fenster erstellen, wenn keines vorhanden ist
            existingFig = createSelectionWindow();
        else
            % Leere existingFig
            existingFig.Name = 'Auswahlfenster';
            delete(existingFig.Children);
        end
        % Methoden definieren
        methods = {'DCR', 'Leckage', 'OCV_FallOff', 'CV_ECSA', 'H2_Crossover', 'PK', 'Load__Points', 'EIS', 'S_plus__plus_'};
        % Laden des Referenzordnerpfads
        refDir = loadReferencePath();
        if isempty(refDir)
            % Anzeige des Infofelds, wenn kein gültiger Referenzordner vorhanden ist
            displayInfo(existingFig, margin, labelHeight);
        else
            % Erstellung der Knöpfe für alle Methoden
            createButtonsAndLabels(existingFig, methods, margin, labelHeight, btnWidth, btnHeight, numColumns);
        end
        % Erstellung des Exit Buttons und des Referenz-Buttons
        createExitAndReferenceButtons(existingFig, margin, exitBtnHeight, methods);
        % Anzeige des aktuell verwendeten Referenzordners
        displayCurrentReference(existingFig, margin, btnWidth, exitBtnHeight, labelHeight, refDir);
        % Hinzufügen der SizeChangedFcn, um die Größenänderung zu behandeln
        existingFig.AutoResizeChildren = 'off';  % Deaktivieren der automatischen Größenanpassung
        existingFig.SizeChangedFcn = @(src, event) resizeUIComponents(src, margin, labelHeight, btnWidth, btnHeight, exitBtnHeight, numColumns, methods);
        % Initiale Größenanpassung auf aktuelle Fenstergröße
        resizeUIComponents(existingFig, margin, labelHeight, btnWidth, btnHeight, exitBtnHeight, numColumns, methods);
    catch ME
        if ~exist("existingFig") %#ok<EXIST> 
            existingFig = uifigure();
        end
        uialert(existingFig, ME.message, 'Fehler beim Öffnen des Auswahlfensters')
        disp(ME.message)
    end
end
function fig = createSelectionWindow()
    % Diese Funktion erstellt das Auswahlfenster und positioniert es auf dem Bildschirm.
    try
        % Berechnung der Fenstergröße
        windowWidth = 900;
        windowHeight = 625;
        % Erkennung der Bildschirmgröße
        screenSize = get(0, 'ScreenSize');
        % Berechnung der Position, um das Fenster zu zentrieren
        windowX = (screenSize(3) - windowWidth) / 2;
        windowY = (screenSize(4) - windowHeight) / 2;
        % Erstellung des Auswahlfensters
        fig = uifigure('Name', 'Auswahlfenster', 'Position', [windowX, windowY, windowWidth, windowHeight]);
    catch ME
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Erstellen des Fensters')
        disp(ME.message)
    end
end
function createButtonsAndLabels(fig, methods, margin, labelHeight, btnWidth, btnHeight, numColumns)
    % Diese Funktion erstellt dynamisch die Buttons und Labels für die verschiedenen Methoden.
    try
        % Erkennung des Dateipfades
        scriptDir = fileparts(mfilename('fullpath'));
        % Dynamische Erstellung der Buttons und Labels
        for i = 1:length(methods)
            method = methods{i};
            imagePath = fullfile(scriptDir, 'Bilder', [method, '.PNG']);
            [btnX, btnY] = callcButtonPos(margin, margin, fig, btnHeight, i, numColumns, btnWidth, labelHeight);
            createButtonAndLabel(fig, imagePath, method, btnX, btnY, btnWidth, btnHeight, labelHeight, @(btn, event) methodAction(fig, method, scriptDir));
        end
    catch ME
        uialert(fig, ME.message, 'Fehler beim Erstellen der Methodenbuttons')
        disp(ME.message)
    end
end
function createButtonAndLabel(fig, imagePath, method, btnX, btnY, btnWidth, btnHeight, labelHeight, callback)
    % Diese Funktion erstellt einen Button und das zugehörige Label.
    try
        % Erstelle den Button
        uibutton(fig, 'push', 'Position', [btnX, btnY, btnWidth, btnHeight], 'Icon', imagePath, 'Text', '', 'ButtonPushedFcn', callback, 'Tag', method);
        % Erstelle das Label unter dem Button
        labelY = btnY - labelHeight;
        % Ersetze Unterstriche durch Bindestriche
        methodLabel = strrep(method, '_plus_', '+');
        methodLabel = strrep(methodLabel, '__', ' ');
        methodLabel = strrep(methodLabel, '_', '-');
        uilabel(fig, 'Position', [btnX, labelY, btnWidth, labelHeight], 'HorizontalAlignment', 'center', 'Text', methodLabel, 'Tag', [method, 'label']);
    catch ME
        uialert(fig, ME.message, ['Fehler beim Erstellen des ', method, ' Buttons oder Labels.'])
        disp(ME.message)
    end
end
function createExitAndReferenceButtons(fig, margin, exitBtnHeight, methods)
    % Diese Funktion erstellt die Exit-, Help- und Referenz-Buttons und positioniert sie.
    try
        % Berechnung der Fenstergröße
        windowWidth = fig.Position(3);
        windowHeight = fig.Position(4);
        % Berechnung der neuen Positionen und Größen
        newMargin = margin * (windowWidth / 900);
        newBtnWidth = 200 * (windowWidth / 900);
        newExitBtnHeight = exitBtnHeight * (windowHeight / 625);
        % Erstellung des Exit-Buttons
        uibutton(fig, 'push', 'Text', 'Tool Beenden', 'Position', ...
            [windowWidth - newBtnWidth - newMargin, newMargin / 2, newBtnWidth, newExitBtnHeight], ...
            'ButtonPushedFcn', @(btn, event) closeAndCleanup(fig), 'Tag', 'Beenden');
        % Erstellung des Referenz-Buttons
        uibutton(fig, 'push', 'Text', 'Referenzen', 'Position', ...
            [newMargin, newMargin / 2, newBtnWidth, newExitBtnHeight], 'ButtonPushedFcn', ...
            @(btn, event) openReferenceManagement(fig, methods), 'Tag', 'Referenzen');
        % Erstellung des Help-Buttons
        uibutton(fig, 'push', 'Text', 'Help', ...
            'Position', [(windowWidth - newBtnWidth)/2, 15, newBtnWidth, newExitBtnHeight/2], ...
            'ButtonPushedFcn', @(btn, event) helpButton(), ...
            'Tag', 'Help', 'HorizontalAlignment', 'center');
    catch ME
        uialert(fig, ME.message, 'Fehler beim Erstellen der unteren Buttons')
        disp(ME.message)
    end
end
%% Event-Handler und Callback-Funktionen
function resizeUIComponents(fig, margin, labelHeight, btnWidth, btnHeight, exitBtnHeight, numColumns, methods)
    % Diese Funktion passt die Größe und Position der UI-Elemente an, wenn die Fenstergröße geändert wird.
    try
        % Berechnung der Fenstergröße
        windowWidth = fig.Position(3);
        windowHeight = fig.Position(4);
        % Berechnung der neuen Positionen und Größen
        newWidthMargin = margin * (windowWidth / 900);
        newHeightMargin = margin * (windowHeight / 625);
        newLabelHeight = labelHeight * (windowHeight / 625);
        newBtnWidth = btnWidth * (windowWidth / 900);
        newBtnHeight = btnHeight * (windowHeight / 625);
        newExitBtnHeight = exitBtnHeight * (windowHeight / 625);
        % Skalierung des Infofelds
        resizeComponent(fig, 'noRef', [newWidthMargin, windowHeight - newHeightMargin - newLabelHeight, windowWidth - 2 * newWidthMargin, labelHeight])
        for i = 1:length(methods)
            [newBtnX, newBtnY] = callcButtonPos(newWidthMargin, newHeightMargin, fig, newBtnHeight, i, numColumns, newBtnWidth, newLabelHeight);
            resizeComponent(fig, methods{i}, [newBtnX, newBtnY, newBtnWidth, newBtnHeight])
            newlabelY = newBtnY - newLabelHeight;
            resizeComponent(fig, [methods{i}, 'label'], [newBtnX, newlabelY, newBtnWidth, newLabelHeight])
        end
        % Skalierung des Exit Buttons und des Referenz-Buttons
        if newExitBtnHeight < labelHeight
            newExitBtnHeight = labelHeight;
        end
        resizeComponent(fig, 'Beenden',     [windowWidth - newBtnWidth - newWidthMargin, newHeightMargin / 2, newBtnWidth, newExitBtnHeight])
        resizeComponent(fig, 'Referenzen',  [newWidthMargin, newHeightMargin / 2, newBtnWidth, newExitBtnHeight])
        % Skalierung des aktuell verwendeten Referenzordners
        resizeComponent(fig, 'refLabel',    [newWidthMargin + newBtnWidth, newHeightMargin / 2 + newExitBtnHeight - labelHeight, windowWidth - 2 * (newWidthMargin + newBtnWidth), labelHeight])
        resizeComponent(fig, 'Help',        [(windowWidth - newBtnWidth)/2, newHeightMargin / 2, newBtnWidth, newExitBtnHeight/2])
    catch 
        return
    end
end
function resizeComponent(fig, tag, position)
    component = findobj(fig, 'Tag', tag);
    if ~isempty(component)
        component.Position = position;
    end
end
%% Datenverarbeitungsfunktionen
function [btnX, btnY] = callcButtonPos(newWidthMargin, newHeightMargin, fig, btnHeight, number, numColumns, btnWidth, labelHeight)
    try
        % Berechnung der Startpositionen für die erste Reihe und Spalte
        startX = newWidthMargin;
        startY = fig.Position(4) - btnHeight - newHeightMargin / 2;
        % Berechnung der Positionen für die Buttons
        col = mod(number - 1, numColumns);  % Spalte berechnen
        row = floor((number - 1) / numColumns);  % Zeile berechnen
        btnX = startX + col * (btnWidth + newWidthMargin);
        btnY = startY - row * (btnHeight + newHeightMargin + labelHeight / 4);
    catch ME
        uialert(fig, ME.message, 'Fehler beim Berechnen der Buttonpositionen')
        disp(ME.message)
    end
end
%% Helfer- und Dienstprogramme
function closeAndCleanup(fig)
    % Diese Funktion schließt das Fenster, löscht alle Variablen und den Text im Command Window
    try
        % Lösche alle Variablen im Base Workspace
        evalin('base', 'clear');
        % Lösche den Text im Command Window
        clc;
        % Schließe das Fenster
        delete(fig);
    catch ME
        uialert(fig, ME.message, 'Fehler beim Schließen des Fensters')
        disp(ME.message)
    end
end
function helpButton()
    helpdlg(['>> "aktuelle Referenz:" zeigt den aktuell für Auswertungen gewählten Referenzdatensatz' newline ...
             '>> Methodenbuttons öffnen Methoden' newline ...
             '>> "Referenzen" öffnet die Referenzverwaltung' newline ...
             '>>> "Standardconfig anpassen" öffnet ein Menü in dem die Standard-Config-Dateien für die Methoden angepasst werden können' newline ...
             '>>> "Referenz importieren/exportieren" ermöglicht den import/export eines Referenzsatzes als .zip' newline ...
             '>>> "Referenz bearbeiten" öffnet ein Bearbeitungsmenü für die Referenzen' newline ...
             '>>> "Neue Referenz" erstellt einen neuen Referenzdatensatz' newline ...
             '>>>> Im Referenzdatensatz gibt es vorerst nur eine config-Datei und leere Methodenordner' newline ...
             '>>>>> Die "Allgemeine Config" muss der Zelle entsprechend angepasst werden' newline ...
             '>>>>> Danach erst Dateien in die Methodenordner hochladen' newline ...
             '>>>>>> Methoden-Configs können auch in der Methode selber noch bearbeitet werden.' ...
             ], 'Information');
end
%% Eingabe-/Ausgabefunktionen
function displayCurrentReference(fig, margin, btnWidth, exitBtnHeight, labelHeight, refDir)
    % Diese Funktion zeigt den aktuell verwendeten Referenzordner an.
    try    
        if ~isempty(refDir)
            [~, folderName, ~] = fileparts(refDir); % Nur den Ordnernamen extrahieren
            text = ['aktuelle Referenz: ', folderName];
        else
            text = 'Bitte Referenz wählen.';
        end
        uilabel(fig, 'Position', [margin + btnWidth, margin / 2 + exitBtnHeight - labelHeight, fig.Position(3) - 2 * (margin + btnWidth), labelHeight], ...
                'Text', text, 'HorizontalAlignment', 'center', 'Tag', 'refLabel');
    catch ME
        uialert(fig, ME.message, 'Fehler beim Anzeigen der Referenz')
        disp(ME.message)
    end
end
function methodAction(fig, method, scriptDir)
    % Diese Funktion wird aufgerufen, wenn eine Methode ausgewählt wird.
    % Sie entfernt die bestehenden Elemente und lädt die neue Methode.
    try
        % Pfad zum Methodenskript
        methodScriptPath = fullfile(scriptDir, 'Auswertungen', method);
        % Einlesen des aktuellen Referenzordners
        referenceFolder = getappdata(0, 'currentReference');
        runMethodScript(methodScriptPath, fig, referenceFolder);
    catch ME
        uialert(fig, ME.message, 'Beim Öffnen der Methode ist folgender Fehler aufgetreten')
        disp(ME.message)
    end
end
function runMethodScript(scriptPath, fig, referenceFolder)
    % Diese Funktion führt das Auswertungsskript aus.
    % Speichere das Figur-Handle und den Referenzordner im Base Workspace
    assignin('base', 'fig', fig);
    assignin('base', 'referenceFolder', referenceFolder);
    % Extrahiere den Dateinamen ohne Pfad und Erweiterung
    [scriptDir, scriptName, ~] = fileparts(scriptPath);
    % Erstelle einen Funktionshandle aus dem Dateinamen und Verzeichnis
    functionHandle = str2func(scriptName);
    % Wechsle in das Verzeichnis des Skripts
    originalDir = cd(scriptDir);
    % Rufe die Funktion auf
    feval(functionHandle, referenceFolder);
    % Wechsle zurück in das ursprüngliche Verzeichnis
    cd(originalDir);
end
function openReferenceManagement(fig, methods)
    % Diese Funktion öffnet die Referenzverwaltung und wartet, bis das Fenster geschlossen wird
    try
        assignin('base', 'fig', fig);
        refFig = Referenzverwaltung(methods);  % Öffnet die Referenzverwaltung
        waitfor(refFig);  % Wartet, bis das Referenzverwaltungsfenster geschlossen wird
    catch ME
        uialert(fig, ME.message, 'Fehler beim Öffnen der Referenzverwaltung')
        disp(ME.message)
    end
    Auswahl(fig);  % Aktualisiert das Auswahlfenster mit dem bestehenden Fenster-Handle
end
function refDir = loadReferencePath()
    % Diese Funktion lädt den Referenzordnerpfad aus der .mat-Datei
    try
        refDir = [];
        matFilePath = fullfile(fileparts(mfilename('fullpath')), 'Referenzen', 'currentReference.mat');
        if isfile(matFilePath)
            data = load(matFilePath);
            if isfield(data, 'refDir')
                refDir = data.refDir;
                if isfolder(refDir)
                    setappdata(0, 'currentReference', refDir);
                    % Standarddateipfad für Dateiauswahl
                    configData = jsondecode(fileread(fullfile(refDir, 'config.json')));
                    config = configData.Auswahl;
                    assignin('base', 'standardPath', config.StandardPfad);
                else
                    refDir = [];
                end
            end
        end
    catch ME
        uialert(fig, ME.message, 'Fehler beim Laden des Referenzordnerpfads')
        disp(ME.message)
    end
end
function displayInfo(fig, margin, labelHeight)
    % Diese Funktion zeigt ein Infofeld an, wenn kein gültiger Referenzordner vorhanden ist.
    % Berechnung der Fenstergröße
    windowWidth = fig.Position(3);
    windowHeight = fig.Position(4);
    % Berechnung der neuen Positionen und Größen
    newMargin = margin * (windowWidth / 900);
    newLabelHeight = labelHeight * (windowHeight / 625);
    uilabel(fig, 'Position', [newMargin, windowHeight - newMargin - newLabelHeight, windowWidth - 2 * newMargin, newLabelHeight], ...
        'Text', 'Bitte wählen Sie einen gültigen Referenzordner aus.', 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Tag', 'noRef');
end