%% Setup- und Initialisierungsfunktionen

function refFig = Referenzverwaltung(methods)
    % Diese Funktion öffnet das Referenzverwaltungsfenster.
    % methods: Ein Zellen-Array mit den Methoden, die verwaltet werden sollen.

    config = getConfig(); % Lädt die Konfigurationsvariablen zur Erstellung der Fenster

    assignin("base", "exportDir", 'P:\50_ARBEITSGRUPPEN\Analytik_FC\02_Fachbereichssoftware_KlaSu_3.2\15_FC-OPAT\Referenzexport')
    
    % Erstellung des Referenzverwaltungsfensters
    refFig = uifigure('Name', 'Referenzverwaltung', 'Position', ...
        [config.windowX, config.windowY, config.windowWidth, config.windowHeight], ...
        'CloseRequestFcn', @(src, event) delete(src));

    % Erstellung des Anweisungslabels
    uilabel(refFig, 'Position', ...
        [(config.windowWidth - config.labelWidth) / 2, config.windowHeight - config.labelHeight / 4 - config.margin * 2 / 3, ...
        config.labelWidth, config.labelHeight], ...
        'Text', 'Verwalte die Referenzmessungen.');

    % Erstellung der Liste der Referenzmessungen
    refList = uilistbox(refFig, 'Position', ...
        [config.margin, config.windowHeight - config.labelHeight / 4 - config.margin * 2 / 3 - config.listHeight, ...
        config.listWidth, config.listHeight], ...
        'Items', loadReferenceList(), ...
        'Multiselect', 'off'); % Nur Einzel-Auswahl erlauben

    % Hinzufügen des WindowButtonDownFcn-Callbacks
    refFig.WindowButtonDownFcn = @(src, event) onRefListDoubleClick(src, refList, methods);

    % Erstellung der Buttons für Hinzufügen, Bearbeiten, Löschen und Auswählen
    addButton(refFig, 'Neue Referenz', 1.5 * config.margin + config.btnWidth, config.margin / 4, @(btn, event) pickbench(refList, methods));
    addButton(refFig, 'Referenz bearbeiten', config.margin, config.margin * 5 / 3 / 4 + config.btnHeight, @(btn, event) editReference(refList, methods));
    addButton(refFig, 'Referenz löschen', config.margin, config.margin / 4, @(btn, event) deleteReference(refList, refFig));
    addButton(refFig, 'Referenz auswählen', 1.5 * config.margin + config.btnWidth, config.margin * 5 / 3 / 4 + config.btnHeight, @(btn, event) selectReference(refList, refFig));
    addButton(refFig, 'Referenz exportieren', 1.5 * config.margin + config.btnWidth, config.margin * 7 / 3 / 4 + 2 * config.btnHeight, @(btn, event) exportReference(refList, refFig));
    addButton(refFig, 'Referenz importieren', config.margin, config.margin * 7 / 3 / 4 + 2 * config.btnHeight, @(btn, event) importReference(refList, refFig));
    uibutton(refFig, 'push', 'Text', 'Standardconfig anpassen', 'Position', ...
        [config.margin, config.margin * 9 / 3 / 4 + 3 * config.btnHeight, 2 * config.btnWidth + 0.5 * config.margin, config.btnHeight], ...
        'ButtonPushedFcn', @(btn, event) editStandard());
end

function onRefListDoubleClick(src, refList, methods)
    % Diese Funktion wird aufgerufen, wenn auf ein Element der Referenzliste doppelt geklickt wird.
    persistent lastClickTime;
    doubleClickThreshold = 0.3; % Sekundenschwelle für Doppelklick

    % Überprüfen, ob der Klick auf die Referenzliste erfolgte
    clickPos = src.CurrentPoint;
    listPos = refList.Position;

    if clickPos(1) >= listPos(1) && clickPos(1) <= listPos(1) + listPos(3) && ...
       clickPos(2) >= listPos(2) && clickPos(2) <= listPos(2) + listPos(4)
        % Wenn der Klick innerhalb der Liste liegt, überprüfe auf Doppelklick
        if isempty(lastClickTime)
            lastClickTime = 0;
        end

        currentTime = now;
        if (currentTime - lastClickTime) * 24 * 3600 < doubleClickThreshold
            % Wenn ein Doppelklick erkannt wird, rufe editReference auf
            editReference(refList, methods, refList.Value);
        end
        lastClickTime = currentTime;
    end
end

function config = getConfig()
    % Diese Funktion liefert die gemeinsamen Konfigurationseinstellungen.
    config.margin = 20;
    config.labelWidth = 183;
    config.labelHeight = 20;
    config.listHeight = 300;
    config.btnWidth = 125;
    config.btnHeight = 30;
    config.windowWidth = 2.5 * config.margin + 2 * config.btnWidth;
    config.listWidth = config.windowWidth - 2 * config.margin; % Listbox-Breite
    config.windowHeight = 2.3 * config.margin + config.labelHeight + config.listHeight + 3 * config.btnHeight;
    
    % Berechnung der Bildschirmgröße
    screenSize = get(0, 'ScreenSize');
    config.windowX = (screenSize(3) - config.windowWidth) / 2;
    config.windowY = (screenSize(4) - config.windowHeight) / 2;
end

function addButton(parent, text, posX, posY, callback)
    % Diese Funktion erstellt einen Button mit den gegebenen Eigenschaften.
    config = getConfig();
    uibutton(parent, 'push', 'Text', text, ...
        'Position', [posX, posY, config.btnWidth, config.btnHeight], ...
        'ButtonPushedFcn', callback);
end

function manageMethodFiles(methodDir, methodName, refList, methods)
    % Diese Funktion öffnet ein Fenster zur Verwaltung der Dateien in einem Methodenordner.

    config = getConfig(); % Lädt die gemeinsame Konfiguration

    % Erstellung des Verwaltungsfensters
    manageFig = uifigure('Name', [methodName, ' Referenzdateien'], 'Position', ...
        [config.windowX, config.windowY, config.windowWidth, config.windowHeight]);

    % Erstellung der Liste der Dateien
    fileList = uilistbox(manageFig, 'Position', ...
        [config.margin, config.windowHeight - config.margin - config.listHeight - 1.5 * config.btnHeight, ...
        config.listWidth, config.listHeight + 2 * config.btnHeight], ...
        'Items', loadFileList(methodDir));

    % Erstellung der Buttons für Hinzufügen und Löschen von Dateien und für Zurück
    addButton(manageFig, 'Neue Datei', 1.5 * config.margin + config.btnWidth, config.margin / 2, @(btn, event) addFilesToMethodDir(methodDir, methodName, fileList));
    addButton(manageFig, 'Datei Löschen', config.margin, config.margin / 2, @(btn, event) deleteFilesFromMethodDir(methodDir, fileList));
    uibutton(manageFig, 'push', 'Text', 'Zurück zur Methodenauswahl', ...
        'Position', [config.margin, config.btnHeight + config.margin, 2 * config.btnWidth + 0.5 * config.margin, config.btnHeight], ...
        'ButtonPushedFcn', @(btn, event) backToEditReference(manageFig, refList, methods, refList.Value));
end

%% Event-Handler und Callback-Funktionen

function pickbench(refList, methods)
    % Auswahl des Prüfstandes per Listendialog (Auswahlfenster mit Liste)
    methodOptions = [{'G-60'}, {'G-100'}, {'G-400'}];
    [methodIndex, ok] = listdlg('PromptString', 'Wählen Sie einen Prüfstand aus:', ...
        'SelectionMode', 'single', 'ListString', methodOptions, 'ListSize', [160 300]);
    if ok
        addReference(refList, methods, methodOptions(methodIndex))
    end
end

function addReference(refList, methods, bench)
    % Diese Funktion fügt einen neuen Referenzsatz zur Liste hinzu.
    
    % Definition der Felder im Inputdialog
    prompt = 'Geben Sie den Namen für den neuen Referenzsatz ein:';
    dlgtitle = 'Neue Referenz';
    dims = [1 57];
    definput = {''};

    % Erstellung des Inputdialoges (Fenster in dem der Name eingegeben werden kann)
    answer = inputdlg(prompt, dlgtitle, dims, definput);

    if ~isempty(answer)
        % Erstellen des neuen Referenzordners, falls keiner mit dem gleichen Namen existiert
        newRefName = answer{1};
        refDir = fullfile(fileparts(mfilename('fullpath')), newRefName);
        assignin("base", 'currentRef', refDir);
        if ~isfolder(refDir)
            mkdir(refDir);
        end

        % Erstellen der Ordner für jede Auswertungsmethode
        createMethodDirs(refDir, methods);
        
        % Kopieren der Vorlage für die config.json & Export
        templateConfigPath = fullfile(fileparts(mfilename('fullpath')), 'Standardconfig', [bench{1}, '_config.json']);
        if isfile(templateConfigPath)
            copyfile(templateConfigPath, fullfile(refDir, 'config.json'));
        end

        % Aktualisieren der Referenzliste
        refList.Items{end + 1} = newRefName;

        % Öffne das Bearbeitungsfenster, um Dateien hinzuzufügen
        editReference(refList, methods, newRefName);
    end
end

function createMethodDirs(refDir, methods)
    % Erstellt die Ordner für jede Auswertungsmethode
    for i = 1:length(methods)
        methodDir = fullfile(refDir, methods{i});
        if strcmp(methods{i}, 'CV_ECSA')
            % Erstellen der Unterordner für schneller und langsamer Scan
            createSubDirs(methodDir, {'schneller_Scan', 'langsamer_Scan'});
        elseif strcmp(methods{i}, 'PK')
            % Erstellen der Unterordner für PK 1-3
            createSubDirs(methodDir, {'PK1', 'PK2', 'PK3'});
        else
            if ~isfolder(methodDir)
                mkdir(methodDir);
            end
        end
    end
end

function createSubDirs(baseDir, subDirs)
    % Erstellt die angegebenen Unterordner
    for i = 1:length(subDirs)
        subDir = fullfile(baseDir, subDirs{i});
        if ~isfolder(subDir)
            mkdir(subDir);
        end
    end
end

function editReference(refList, methods, refName)
    % Diese Funktion ermöglicht das Bearbeiten einer bestehenden Referenzmessung.
    
    selectReference(refList)
    % Falls kein refName gegeben wurde, wird die Variable erstellt
    if nargin < 3
        refName = refList.Value;
    end

    if ~isempty(refName)
        % Dateipfad zum Referenzordner wird erstellt
        refDir = fullfile(fileparts(mfilename('fullpath')), refName);
        assignin("base", 'currentRef', refDir);
        % Auswahl der Methode per Listendialog (Auswahlfenster mit Liste)
        methodOptions = [{'Referenz umbenennen'}, {'Allgemeine Config'}, methods];
        [methodIndex, ok] = listdlg('PromptString', 'Wählen Sie eine Methode aus:', ...
            'SelectionMode', 'single', 'ListString', methodOptions, 'ListSize', [160 300]);
        
        if ok
            if methodIndex == 1
                % Umbenennen der Referenz
                renameReference(refList, refName, refDir);
            elseif methodIndex == 2
                % Bearbeiten der config.json
                editConfig(refDir);
            else
                % Falls eine Methode gewählt wurde, den Methodenordner öffnen und wenn nötig erstellen
                methodDir = getMethodDir(refDir, methods{methodIndex - 2});
                
                if ~isfolder(methodDir) && ~isempty(methodDir)
                    mkdir(methodDir);
                end
                if isfolder(methodDir)
                    % Öffne das Fenster zur Verwaltung der Dateien in diesem Methodenordner
                    manageMethodFiles(methodDir, methods{methodIndex - 2}, refList, methods);
                end
            end
        end
    end
end

function methodDir = getMethodDir(refDir, method)
    % Gibt den Methodenordner zurück, ggf. mit Unterordnern.
    methodDir = fullfile(refDir, method);

    if strcmp(method, 'CV_ECSA')
        % Auswahl des Scantyps für CV_ECSA
        [scanTypeIndex, ok] = listdlg('PromptString', 'Wählen Sie den Scantyp aus:', ...
            'SelectionMode', 'single', 'ListString', {'schneller_Scan', 'langsamer_Scan'}, 'ListSize', [160 100]);
        if ok
            scanTypes = {'schneller_Scan', 'langsamer_Scan'};
            methodDir = fullfile(methodDir, scanTypes{scanTypeIndex});
        else
            methodDir = '';
        end
    elseif strcmp(method, 'PK')
        % Auswahl der Polarisationskurve für PK
        [pkIndex, ok] = listdlg('PromptString', 'Wählen Sie die Polarisationskurve aus:', ...
            'SelectionMode', 'single', 'ListString', {'Excel für Export', 'PK1', 'PK2', 'PK3'}, 'ListSize', [160 100]);
        if ok
            pks = {'', 'PK1', 'PK2', 'PK3'};
            methodDir = fullfile(methodDir, pks{pkIndex});
        else
            methodDir = '';
        end
    end
end

function renameReference(refList, oldName, oldDir)
    % Diese Funktion ermöglicht das Umbenennen einer Referenzmessung.
    prompt = {'Geben Sie den neuen Namen für die Referenz ein:'};
    dlgtitle = 'Referenz umbenennen';
    dims = [1 50];
    definput = {oldName};
    answer = inputdlg(prompt, dlgtitle, dims, definput);

    if ~isempty(answer)
        newName = answer{1};
        newDir = fullfile(fileparts(mfilename('fullpath')), newName);
        
        if isfolder(newDir)
            msgbox('Eine Referenz mit diesem Namen existiert bereits.', 'Fehler', 'error');
        else
            movefile(oldDir, newDir);
            refList.Items = loadReferenceList();
            msgbox('Referenz erfolgreich umbenannt.', 'Erfolg');
        end
    end
end

function deleteReference(refList, refFig)
    % Diese Funktion löscht die ausgewählte Referenzmessung aus der Liste.
    if ~isempty(refList.Value)
        refDir = fullfile(fileparts(mfilename('fullpath')), refList.Value);
        answer = questdlg(['Soll die Referenz "' refList.Value '" wirklich gelöscht werden?'], 'Referenz löschen', 'Ja', 'Nein', 'Nein');
        if strcmp(answer, 'Ja')
            d = uiprogressdlg(refFig, 'Title', 'Bitte Warten', 'Message', 'Dateien werden gelöscht');
            d.Value = 0.4;
            if isfolder(refDir)
                rmdir(refDir, 's');
            end
            d.Value = 0.9;
            refList.Items(strcmp(refList.Items, refList.Value)) = [];
            d.Value = 1;
            close(d);
        end
    end
end

function exportReference(refList, refFig)
    % Diese Funktion exportiert den ausgewählten Referenzsatz in eine ZIP-Datei.
    if ~isempty(refList.Value)
        refDir = fullfile(fileparts(mfilename('fullpath')), refList.Value);
        try
            exportDir = evalin("base", "exportDir");
            originalDir = cd(exportDir);
            [fileName, filePath] = uiputfile('*.zip', 'Referenz exportieren', ['Referenz_', refList.Value, '.zip']);
            cd(originalDir);
        catch
            [fileName, filePath] = uiputfile('*.zip', 'Referenz exportieren', ['Referenz_', refList.Value, '.zip']);
        end
        d = uiprogressdlg(refFig, 'Title', 'Bitte Warten', 'Message', 'Dateien werden exportiert');
        d.Value = 0.2;
        if fileName
            zipFilePath = fullfile(filePath, fileName);
            d.Value = 0.4;
            zip(zipFilePath, fullfile(refDir, '*'));
            d.Value = 0.9;
            msgbox('Referenz erfolgreich exportiert.', 'Erfolg');
        end
        d.Value = 1;
        close(d);
    else
        msgbox('Bitte wählen Sie eine Referenz aus.', 'Fehler', 'error');
    end
end

function importReference(refList, refFig)
    % Diese Funktion importiert ausgewählte Referenzsätze aus einer ZIP-Datei.
    try
        exportDir = evalin("base", "exportDir");
        originalDir = cd(exportDir);
        [fileNames, filePath] = uigetfile('*.zip', 'Referenz importieren', 'MultiSelect', 'on');
        cd(originalDir);
    catch
        [fileNames, filePath] = uigetfile('*.zip', 'Referenz importieren', 'MultiSelect', 'on');
    end
    d = uiprogressdlg(refFig, 'Title', 'Bitte Warten', 'Message', 'Dateien werden importiert');
    d.Value = 0.2;
    if iscell(fileNames) || ischar(fileNames)
        if ischar(fileNames)
            fileNames = {fileNames};
        end
        d.Value = 0.3;
        factor = 1 / length(fileNames);
        for i = 1:length(fileNames)
            [~, baseName, ~] = fileparts(fileNames{i});
            d.Value = d.Value + 0.1 * factor;

            targetDir = fullfile(fileparts(mfilename('fullpath')), baseName);
            targetDir = strrep(targetDir, 'Referenz_', '');
            d.Value = d.Value + 0.1 * factor;

            counter = 1;
            newTargetDir = targetDir;
            while isfolder(newTargetDir)
                newTargetDir = [targetDir, '_', num2str(counter)];
                counter = counter + 1;
            end
            d.Value = d.Value + 0.1 * factor;

            unzip(fullfile(filePath, fileNames{i}), newTargetDir);
            d.Value = d.Value + 0.3 * factor;
        end

        refList.Items = loadReferenceList();
        msgbox('Referenz(en) erfolgreich importiert.', 'Erfolg');
    else
        msgbox('Bitte wählen Sie eine oder mehrere ZIP-Dateien aus.', 'Fehler', 'error');
    end
    d.Value = 1;
    close(d);
end

function addFilesToMethodDir(methodDir, methodName, fileList)
    % Diese Funktion fügt Dateien zu einem Methodenordner hinzu.

    standardPath = evalin('base', 'standardPath');
    try
        oldFolder = cd(standardPath);
        [fileNames, filePath] = uigetfile({'*.csv;*.txt;*.xlsx;*.xlsm'}, ['Wählen Sie Referenzdateien und Exportvorlagen für ', methodName], 'MultiSelect', 'on');
        cd(oldFolder);
    
    catch ME
        fig = evalin('base', 'fig');
        uialert(fig, [ME.message], 'Standardordner nicht gültig, bitte in der config anpassen.', 'Icon', 'warning');
        [fileNames, filePath] = uigetfile({'*.csv;*.txt;*.xlsx;*.xlsm'}, ['Wählen Sie Referenzdateien und Exportvorlagen für ', methodName], 'MultiSelect', 'on');
    end

    if iscell(fileNames)
        for j = 1:length(fileNames)
            saveDataArray(fullfile(filePath, fileNames{j}), methodName, methodDir);
        end
    elseif ischar(fileNames)
        saveDataArray(fullfile(filePath, fileNames), methodName, methodDir);
    end

    fileList.Items = loadFileList(methodDir);
end

function saveDataArray(filePath, methodName, methodDir)
    % Liest die Datei und speichert die Daten im entsprechenden Methodenordner.
    ext = filePath(end-4: end);
    if isequal(ext, '.xlsx') || isequal(ext, '.xlsm')
        exampleExcel = dir(fullfile(methodDir, '*.xlsx'));
        if ~isempty(exampleExcel)
           delete(fullfile(methodDir, exampleExcel.name));
        end
        copyfile(filePath, methodDir)
    else
        dataArray = readFile(filePath, methodName);
        if ~isempty(dataArray)
            matFiles = dir(fullfile(methodDir, 'Referenz#*.mat'));
            matFileName = sprintf('Referenz#%d_%s.mat', numel(matFiles) + 1, fileNameWithoutExt(filePath));
            save(fullfile(methodDir, matFileName), 'dataArray');
        end
    end
end

function deleteFilesFromMethodDir(methodDir, fileList)
    % Diese Funktion löscht die ausgewählten Dateien aus einem Methodenordner.
    if ~isempty(fileList.Value)
        filesToDelete = ensureCell(fileList.Value);
        for i = 1:length(filesToDelete)
            delete(fullfile(methodDir, filesToDelete{i}));
        end
    end
    fileList.Items = loadFileList(methodDir);
end

function backToEditReference(manageFig, refList, methods, refName)
    % Diese Funktion schließt das aktuelle Fenster und öffnet das Methodenauswahlfenster.
    close(manageFig);
    editReference(refList, methods, refName);
end

function selectReference(refList, refFig)
    % Diese Funktion wählt die aktuelle Referenzmessung aus und speichert sie.
    if ~isempty(refList.Value)
        refDir = fullfile(fileparts(mfilename('fullpath')), refList.Value); % Erstellt Pfad zum Referenzsatz
        setappdata(0, 'currentReference', refDir); % Speichert den Pfad zur weiteren Nutzung

        % Pfad zur .mat-Datei
        matFilePath = fullfile(fileparts(mfilename('fullpath')), 'currentReference.mat');

        % Speichern des Referenzordners in der .mat-Datei
        save(matFilePath, 'refDir');

        % Standarddateipfad für Dateiauswahl
        configData = jsondecode(fileread(fullfile(refDir, 'config.json')));
        config = configData.Auswahl;
        assignin('base', 'standardPath', config.StandardPfad);

        % Schließt das Referenzverwaltungsfenster
        if nargin == 2
            delete(refFig);
        end
    end
end

function editStandard()
    standardDir = fullfile(fileparts(mfilename('fullpath')), 'Standardconfig');
    dirInfo = dir(fullfile(standardDir, '*.json'));
    methodOptions = {dirInfo.name};

    % Auswahl der .json per Listendialog (Auswahlfenster mit Liste)
    [methodIndex, ok] = listdlg('PromptString', 'Wählen Sie einen Prüfstand aus:', ...
        'SelectionMode', 'single', 'ListString', methodOptions, 'ListSize', [160 300]);
    
    if ok
        configPath = fullfile(standardDir, methodOptions{methodIndex});
        editConfigJson(configPath)
    end
end

%% Datenverarbeitungsfunktionen

function editConfig(refDir)
    % Diese Funktion ermöglicht das Bearbeiten der config.json.
    configPath = fullfile(refDir, 'config.json');

    % Laden der aktuellen Konfiguration
    configData = loadConfigData(configPath);
    
    tags = {'Auswahl.StandardPfad', 'read_txt.HeaderDerNurInZeileVorMessdatenIst', 'read_eis_csv.HeaderDerNurInZeileVorMessdatenIst', ...
        'read_csv.leckageRefZeilen', 'read_csv.leckageRefSpalten', 'read_csv.ocvRefZeilen','read_csv.ocvRefSpalten',  'read_csv.pkRefZeilen', ...
        'read_csv.pkRefSpalten'};

    % Erstellen des Bearbeitungsfensters
    editFig = uifigure('Name', 'Allgemeine Config', 'Position', [235.5, 118, 809, 564]);

    uibutton(editFig, 'Text', 'DCR config', 'Position', [20, 50, 124, 30], ...
        'ButtonPushedFcn', @(btn, event) configBtnAction('DCR'));

    uibutton(editFig, 'Text', 'Leckage config', 'Position', [149, 50, 124, 30], ...
        'ButtonPushedFcn', @(btn, event) configBtnAction('Leckage'));

    uibutton(editFig, 'Text', 'OCV-FallOff config', 'Position', [278, 50, 124, 30], ...
        'ButtonPushedFcn', @(btn, event) configBtnAction('OCV_FallOff'));

    uibutton(editFig, 'Text', 'CV-ECSA config', 'Position', [407, 50, 124, 30], ...
        'ButtonPushedFcn', @(btn, event) configBtnAction('CV_ECSA'));
    
    uibutton(editFig, 'Text', 'H2-Crossover config', 'Position', [536, 50, 124, 30], ...
         'ButtonPushedFcn', @(btn, event) configBtnAction('H2_Crossover'));
    
    uibutton(editFig, 'Text', 'PK config', 'Position', [20, 10, 124, 30], ...
         'ButtonPushedFcn', @(btn, event) configBtnAction('PK'));
    
    uibutton(editFig, 'Text', 'Load Points config', 'Position', [149, 10, 124, 30], ...
         'ButtonPushedFcn', @(btn, event) configBtnAction('Load__Points'));
    
    uibutton(editFig, 'Text', 'EIS config', 'Position', [278, 10, 124, 30], ...
         'ButtonPushedFcn', @(btn, event) configBtnAction('EIS'));

    uibutton(editFig, 'Text', 'S++ config', 'Position', [407, 10, 124, 30], ...
        'ButtonPushedFcn', @(btn, event) configBtnAction('s_plus__plus_'));
    
    uibutton(editFig, 'Text', 'config.json öffnen', 'Position', [536, 10, 124, 30], ...
         'ButtonPushedFcn', @(btn, event) editConfigJson(configPath, editFig));

    uibutton(editFig, 'Text', 'Speichern', 'Position', [665, 10, 124, 70], ...
         'ButtonPushedFcn', @(btn, event) saveConfig(configPath, editFig, tags), 'FontSize', 16);

    uilabel(editFig, "Text", 'Standarddateipfad für Dateiauswahl:', 'Position', [20 535 769 22]);
    uitextarea(editFig, 'Position', [20 495 769 40], 'Value', configData.Auswahl.StandardPfad, ...
        'Tag', 'Auswahl.StandardPfad', 'ValueChangedFcn', @(src, event) validateDataPathInput(src), ...
        'UserData', struct('Value', configData.Auswahl.StandardPfad, 'Status', 'valid'));

    uilabel(editFig, "Text", 'Header der nur in der Zeile vor den Messdaten ist (txt-Dateien):', 'Position', [20 467 769 22]);
    uieditfield(editFig, "text", 'Position', [20 445 769 22], 'Value', configData.read_txt.HeaderDerNurInZeileVorMessdatenIst, ...
         'Tag', 'read_txt.HeaderDerNurInZeileVorMessdatenIst');

    uilabel(editFig, "Text", 'Header der nur in der Zeile vor den Messdaten ist (EIS csv-Dateien):', 'Position', [20 417 769 22]);
    uieditfield(editFig, "text", 'Position', [20 395 769 22], 'Value', configData.read_eis_csv.HeaderDerNurInZeileVorMessdatenIst, ...
         'Tag', 'read_eis_csv.HeaderDerNurInZeileVorMessdatenIst');

    % Konvertieren der Zahlenliste in eine durch Kommas getrennte Zeichenkette
    arrayStr = strjoin(string(configData.read_csv.leckageRefZeilen), ', ');
    uilabel(editFig, "Text", 'Zeilen der Leckage-Referenzdateien, die bei Leak-check logger 2 ausgewertet werden sollen:', 'Position', [20 367 769 22]);
    feld = uieditfield(editFig, "text", 'Position', [20 345 769 22], 'Value', arrayStr, ...
         'Tag', 'read_csv.leckageRefZeilen', 'ValueChangedFcn', @(src, event) validateArrayInput(src), ...
         'UserData', struct('Value', configData.read_csv.leckageRefZeilen, 'Status', 'valid'));
    validateArrayInput(feld);

    % Konvertieren der Zahlenliste in eine durch Kommas getrennte Zeichenkette
    arrayStr = strjoin(string(configData.read_csv.leckageRefSpalten), ', ');
    uilabel(editFig, "Text", 'Spalten der Leckage-Referenzdateien, die bei Leak-check logger 2 ausgewertet werden sollen:', 'Position', [20 317 769 22]);
    feld = uieditfield(editFig, "text", 'Position', [20 295 769 22], 'Value', arrayStr, ...
         'Tag', 'read_csv.leckageRefSpalten', 'ValueChangedFcn', @(src, event) validateArrayInput(src), ...
         'UserData', struct('Value', configData.read_csv.leckageRefSpalten, 'Status', 'valid'));
    validateArrayInput(feld);

    % Konvertieren der Zahlenliste in eine durch Kommas getrennte Zeichenkette
    arrayStr = strjoin(string(configData.read_csv.ocvRefZeilen), ', ');
    uilabel(editFig, "Text", 'Zeilen der OCV-FallOff-Referenzdateien, die ausgewertet werden sollen:', 'Position', [20 267 769 22]);
    feld = uieditfield(editFig, "text", 'Position', [20 245 769 22], 'Value', arrayStr, ...
         'Tag', 'read_csv.ocvRefZeilen', 'ValueChangedFcn', @(src, event) validateArrayInput(src), ...
         'UserData', struct('Value', configData.read_csv.ocvRefZeilen, 'Status', 'valid'));
    validateArrayInput(feld);

    % Konvertieren der Zahlenliste in eine durch Kommas getrennte Zeichenkette
    arrayStr = strjoin(string(configData.read_csv.ocvRefSpalten), ', ');
    uilabel(editFig, "Text", 'Spalten der OCV-FallOff-Referenzdateien, die ausgewertet werden sollen:', 'Position', [20 217 769 22]);
    feld = uieditfield(editFig, "text", 'Position', [20 195 769 22], 'Value', arrayStr, ...
         'Tag', 'read_csv.ocvRefSpalten', 'ValueChangedFcn', @(src, event) validateArrayInput(src), ...
         'UserData', struct('Value', configData.read_csv.ocvRefSpalten, 'Status', 'valid'));
    validateArrayInput(feld);

    % Konvertieren der Zahlenliste in eine durch Kommas getrennte Zeichenkette
    arrayStr = strjoin(string(configData.read_csv.pkRefZeilen), ', ');
    uilabel(editFig, "Text", 'Zeilen der PK-Referenzdateien, die ausgewertet werden sollen:', 'Position', [20 167 769 22]);
    feld = uieditfield(editFig, "text", 'Position', [20 145 769 22], 'Value', arrayStr, ...
         'Tag', 'read_csv.pkRefZeilen', 'ValueChangedFcn', @(src, event) validateArrayInput(src), ...
         'UserData', struct('Value', configData.read_csv.pkRefZeilen, 'Status', 'valid'));
    validateArrayInput(feld);

    % Konvertieren der Zahlenliste in eine durch Kommas getrennte Zeichenkette
    arrayStr = strjoin(string(configData.read_csv.pkRefSpalten), ', ');
    uilabel(editFig, "Text", 'Spalten der PK-Referenzdateien, die ausgewertet werden sollen:', 'Position', [20 117 769 22]);
    feld = uieditfield(editFig, "text", 'Position', [20 95 769 22], 'Value', arrayStr, ...
         'Tag', 'read_csv.pkRefSpalten', 'ValueChangedFcn', @(src, event) validateArrayInput(src), ...
         'UserData', struct('Value', configData.read_csv.pkRefSpalten, 'Status', 'valid'));
    validateArrayInput(feld);
end

function configBtnAction(method)
    try
        % Einlesen des aktuellen Referenzordners
        referenceFolder = getappdata(0, 'currentReference');
        runMethodScript(method, referenceFolder);
    catch ME
        %uialert(fig, ME.message, 'Beim Öffnen der Methode ist folgender Fehler aufgetreten')
        disp(ME.message)
    end
end

function runMethodScript(method, referenceFolder)
    % Diese Funktion führt das Auswertungsskript aus.

    % Pfad zum Methodenskript
    scriptDir = fileparts(mfilename('fullpath'));
    scriptPath = fullfile(scriptDir, 'editAllConfig.m');

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
    else
        error('Das Skript %s existiert nicht.', scriptPath);
    end
end

function validateDataPathInput(src)
    % Holen Sie sich den eingegebenen Wert
    inputPath = src.Value{1};
    
    % Überprüfen, ob der eingegebene Wert ein gültiger Ordnerpfad ist
    if isfolder(inputPath)
        % Wenn der Pfad gültig ist, speichern Sie den Wert
        isValid = true;
    else
        % Wenn der Pfad ungültig ist, geben Sie eine Fehlermeldung aus
        isValid = false;
    end
    if isValid
        src.BackgroundColor = 'white';
        src.UserData = struct('Value', {inputPath}, 'Status', 'valid'); % Speichern der gültigen Werte in UserData
    else
        src.BackgroundColor = 'red';
    end
end

function validateArrayInput(src)
    % Validierungsfunktion
    inputStr = src.Value;
    inputCells = strsplit(inputStr, ',');
    isValid = true;
    parsedValues = cell(1, length(inputCells)); % Initialisieren als leeres Array

    for i = 1:length(inputCells)
        value = strtrim(inputCells{i});
        if strcmp(value, 'inf') || strcmp(value, 'last')
            parsedValues{i} = value; % Speichern als Zell-Array
        else
            numValue = str2double(value);
            if isnan(numValue) || ~isfinite(numValue) % Überprüfen, ob es sich um eine gültige Zahl handelt
                isValid = false;
                break;
            else
                 parsedValues{i} = value; % Speichern als Zahl
            end
        end
    end

    if isValid
        src.BackgroundColor = 'white';
        src.UserData = struct('Value', {parsedValues}, 'Status', 'valid'); % Speichern der gültigen Werte in UserData
    else
        src.BackgroundColor = 'red';
    end
end

function saveConfig(configPath, editFig, tags)
    % Laden der aktuellen Konfiguration
    configData = loadConfigData(configPath);
    
    isValid = true;  % Variable zur Überprüfung der Validität

    % Aktualisieren der Konfigurationsdaten basierend auf den Tags
    for i = 1:length(tags)
        obj = findobj(editFig, 'Tag', tags{i});
        if ~isempty(obj)
            % Prüfen auf Validität nur für die validierten Felder
            if isstruct(obj.UserData) && isfield(obj.UserData, 'Status')
                validity = obj.UserData.Status;
                if strcmp(validity, 'invalid')
                    isValid = false;
                    break;
                end
            end

            % Verwenden von obj.UserData.Value, wenn vorhanden, sonst obj.Value
            if isstruct(obj.UserData) && isfield(obj.UserData, 'Value')
                value = obj.UserData.Value;
            else
                value = obj.Value; % Verwenden von obj.Value für nicht validierte Felder
            end

            % Aufteilen des Tags in seine Bestandteile
            tagParts = strsplit(tags{i}, '.');
            % Verschachtelte Struktur aktualisieren
            configData = setNestedField(configData, tagParts, value);
        else
            warning('Object with Tag "%s" does not exist.', tags{i});
        end
    end

    if isValid
        % Öffnen der Datei zum Schreiben
        fid = fopen(configPath, 'w');
        if fid == -1
            error('Could not open file %s for writing.', configPath);
        end

        % Schreiben der aktualisierten Konfigurationsdaten in die Datei
        fwrite(fid, jsonencode(configData, 'PrettyPrint', true), 'char');

        % Schließen der Datei
        fclose(fid);

        % Schließen der Bearbeitungsfigur
        delete(editFig);
    else
        uialert(editFig, 'Nicht alle Eingaben sind valide. Bitte korrigieren Sie die ungültigen Eingaben.', 'Ungültige Eingaben');
    end
end

function data = setNestedField(data, fieldPath, value)
    if length(fieldPath) == 1
        data.(fieldPath{1}) = value;
    else
        if ~isfield(data, fieldPath{1})
            data.(fieldPath{1}) = struct();
        end
        data.(fieldPath{1}) = setNestedField(data.(fieldPath{1}), fieldPath(2:end), value);
    end
end

function editConfigJson(configPath, parentFig)
    % Diese Funktion ermöglicht das Bearbeiten der config.json.
    % Laden der aktuellen Konfiguration
    configData = loadConfigData(configPath);

    % Erstellen des Bearbeitungsfensters
    editFig = uifigure('Name', 'Konfiguration bearbeiten', 'Position', [200, 100, 400, 650]);

    text = jsonencode(configData, 'PrettyPrint', true);
    text = strrep(text, '\\', '\');
    text = strrep(text, '\\\', '\\');

    % Erstellen eines Textfeldes zur Anzeige der JSON-Daten
    textArea = uitextarea(editFig, 'Position', [10, 50, 380, 590], 'Value', text, 'ValueChangedFcn', ...
        @(src, event) onTextChange(src));

    % Speichern-Button
    if nargin > 1
        uibutton(editFig, 'Text', 'Speichern', 'Position', [150, 10, 100, 30], ...
            'ButtonPushedFcn', @(btn, event) saveFullConfig(configPath, textArea.Value, editFig, parentFig));
    else
        uibutton(editFig, 'Text', 'Speichern', 'Position', [150, 10, 100, 30], ...
            'ButtonPushedFcn', @(btn, event) saveFullConfig(configPath, textArea.Value, editFig));
    end
end

function configData = loadConfigData(configPath)
    % Diese Funktion lädt die Konfigurationsdaten aus der config.json.
    if isfile(configPath)
        try
            configData = jsondecode(fileread(configPath));
        catch
            configData = struct(); % Fallback auf leere Struktur
        end
    else
        configData = struct();
    end
end

function onTextChange(src)
    % Funktion, um sicherzustellen, dass die JSON-Daten als Zeichenkette vorliegen
    if iscell(src.Value)
        src.Value = strjoin(src.Value, '\n'); % Verbinde die Zellen zu einer einzigen Zeichenkette
    end
end

function saveFullConfig(configPath, jsonData, editFig, parentFig)
    % Diese Funktion speichert die bearbeitete Konfiguration in die config.json.
    try
        if iscell(jsonData)
            jsonData = strjoin(jsonData, '\n'); % Verbinde die Zellen zu einer einzigen Zeichenkette
        end
        
        jsonData = strrep(jsonData, '\', '\\');

        configData = jsondecode(jsonData);

        fid = fopen(configPath, 'w');
        fwrite(fid, jsonencode(configData, 'PrettyPrint', true));
        fclose(fid);

        delete(editFig);
        if nargin > 3
            delete(parentFig);
        end
    catch
        uialert(editFig, 'Ungültiges JSON-Format. Bitte korrigieren und erneut versuchen.', 'Fehler');
    end
end

function dataArray = readFile(filePath, methodName)
    % Diese Funktion liest die Daten aus einer Datei (csv oder txt) und gibt sie als Array zurück.
    [~, ~, ext] = fileparts(filePath);
    refDir = evalin("base", 'currentRef');

    configFile = fullfile(refDir, 'config.json');
    configData = loadConfigData(configFile);
    csv_config = configData.read_csv;

    switch lower(ext)
        case '.csv'
            [lines, columns] = getCsvConfig(csv_config, methodName);
            dataArray = read_csv({filePath}, lines, columns);
        case '.txt'
            [dataArray, ~] = read_txt({filePath}, refDir); % Implementiere read_txt entsprechend
        otherwise
            error('Unsupported file type: %s', ext);
    end
end

function [lines, columns] = getCsvConfig(csv_config, methodName)
    % Diese Funktion gibt die Zeilen und Spalten für die CSV-Konfiguration zurück.
    switch methodName
        case 'Leckage'
            lines = csv_config.leckageRefZeilen;
            columns = csv_config.leckageRefSpalten;
        case 'OCV_FallOff'
            lines = csv_config.ocvRefZeilen;
            columns = csv_config.ocvRefSpalten;
        case 'PK'
            lines = csv_config.pkRefZeilen;
            columns = csv_config.pkRefSpalten;
        otherwise
            lines = [];
            columns = [];
    end
    lines = processInf(lines);
    columns = processInf(columns);
end

function processedArray = processConfigArray(array)
    array = strsplit(array, ',');
    processedArray = cell(1, length(array));
    for i = 1:length(array)
        element = str2double(array(i));
        if isnan(element)
            element = array{i};
        end
        processedArray{i} = element;
    end
end

%% Helfer- und Dienstprogramme

function data = processInf(data)
    if iscell(data)
        for i = 1:numel(data)
            if ischar(data{i}) && strcmp(data{i}, 'inf')
                data{i} = Inf;
            elseif ischar(data{i})
                data{i} = strrep(data{i}, '"', ''); % Entfernen von Anführungszeichen
                number = str2double(data{i});
                if ~isnan(number)
                    data{i} = number;
                end
            elseif isnumeric(data{i}) && isinf(data{i})
                data{i} = Inf;
            end
        end        
        if ischar(data{i}) && strcmp(data{i}, 'last')
            data = data{1};
        else
            data = reshape(cell2mat(data), 1, numel(data)); % Konvertieren der Zelle in ein numerisches Array, falls möglich
        end
    end
end

function cellArray = ensureCell(data)
    % Diese Funktion stellt sicher, dass die Eingabe ein Zell-Array ist.
    if ischar(data)
        cellArray = {data};
    else
        cellArray = data;
    end
end

function fileName = fileNameWithoutExt(filePath)
    % Diese Funktion gibt den Dateinamen ohne Erweiterung zurück.
    [~, fileName, ~] = fileparts(filePath);
end

%% Eingabe-/Ausgabefunktionen

function refList = loadReferenceList()
    % Diese Funktion lädt die Liste der gespeicherten Referenzsätze.
    refDir = fullfile(fileparts(mfilename('fullpath')));
    if ~isfolder(refDir)
        mkdir(refDir);
    end
    dirInfo = dir(refDir);
    refList = {dirInfo([dirInfo.isdir] & ~ismember({dirInfo.name}, {'.', '..'})).name};
    % Ordner 'Standardconfig' rausfiltern
    isNotStandardConfig = ~ismember(refList, 'Standardconfig');
    refList = refList(isNotStandardConfig);
end

function fileList = loadFileList(methodDir)
    % Diese Funktion lädt die Liste der Dateien in einem Methodenordner.
    dirInfo = dir(methodDir);
    fileList = {dirInfo(~[dirInfo.isdir]).name};
end