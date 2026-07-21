%% Setup- und Initialisierungsfunktionen

function dataArray = read_eis_csv(filePaths, configFile)
    % Hauptfunktion zum Lesen von CSV-Dateien

    % Abruf der config.json und vervollständigen des Pfades zum Referenzordner
    configFile = fullfile(configFile, 'config.json');
    fid = fopen(configFile, 'r');
    jsonData = fscanf(fid, '%c');
    fclose(fid);
    configData = jsondecode(jsonData);
    csv_config = configData.read_eis_csv;
    assignin("base", "config_csv", csv_config)
    
    % Überprüft die Eingabe und fordert bei Bedarf die Dateiauswahl an
    if nargin < 1 || isempty(filePaths)
        filePaths = selectFiles();
    end

    if isempty(filePaths)
        dataArray = {};
        return;
    end

    % Lese die Daten aus den angegebenen Dateien
    dataArray = readDataFromFiles(filePaths);
    evalin("base", 'clear config_csv')
end

%% Event-Handler und Callback-Funktionen

function filePaths = selectFiles()
    % Öffnet eine Dialogbox zur Auswahl von CSV-Dateien
    
    [filenames, pathname] = uigetfile('*.csv', 'Select the CSV file(s)', 'MultiSelect', 'on');
    
    if isequal(filenames, 0)
        % Falls die Dateiauswahl abgebrochen wurde, gebe eine Meldung aus und ein leeres Array zurück
        disp('File selection canceled');
        filePaths = {};
        return;
    end

    % Sicherstellen, dass filenames eine Zelle ist
    if ischar(filenames)
        filenames = {filenames};
    end

    % Fügen Sie den vollständigen Pfad zu den Dateinamen hinzu
    filePaths = fullfile(pathname, filenames);
end

%% Datenverarbeitungsfunktionen

function dataArray = readDataFromFiles(filePaths)
    % Liest Daten aus allen angegebenen Dateien
    
    % Initialisiere ein Zellenarray mit je einer Zelle pro Dateipfad
    dataArray = cell(1, numel(filePaths));

    % Speichert die Daten der gewählten Dateien in ihrer jeweiligen Zelle im dataArray
    for i = 1:numel(filePaths)
        fullpath = filePaths{i};
        disp(['Reading file: ', fullpath]); % Debugging-Ausgabe
        dataArray{i} = readDataFromFile(fullpath); % Liest die Daten in der Datei aus
        
        if isempty(dataArray{i})
            disp(['No data found in file: ', fullpath]); % Debugging-Ausgabe
        else
            disp(['Data successfully read from file: ', fullpath]); % Debugging-Ausgabe
        end
    end
end

function data = readDataFromFile(filepath)
    % Liest Daten aus einer CSV-Datei
    fig = evalin('base', 'fig');
    d = uiprogressdlg(fig,'Title','Bitte Warten',...
        'Message','Datei wird ausgelesen');

    % config laden
    config_csv = evalin("base", 'config_csv');
    header = config_csv.HeaderDerNurInZeileVorMessdatenIst;
    
    d.Value = 0.1;

    % Datei öffnen
    fid = fopen(filepath, 'r');

    if fid == -1
        % Falls die Datei nicht geöffnet werden kann, gebe eine Meldung aus und ein leeres Array zurück
        disp(['Error opening file: ', filepath]); % Debugging-Ausgabe
        data = [];
        return;
    end

    d.Value = 0.2;

    % Zeilenweise lesen, bis die Zeile mit den Datenüberschriften gefunden wird
    headerFound = false;
    while ~feof(fid)
        currentLine = fgetl(fid);
        disp(['Reading line: ', currentLine]); % Debugging-Ausgabe
        if contains(currentLine, header)
            disp('Data header found'); % Debugging-Ausgabe
            headerFound = true;
            break;
        end
    end

    d.Value = 0.5;

    if ~headerFound
        % Falls keine Datenüberschrift gefunden wurde, gebe eine Meldung aus und schließe die Datei
        disp('Data header not found'); % Debugging-Ausgabe
        fclose(fid);
        data = [];
        return;
    end

    d.Value = 0.6;

    % Daten ab der nächsten Zeile lesen
    data = textscan(fid, '%f %f %f %f %f %f %f', 'Delimiter', ',', 'HeaderLines', 1);

    d.Value = 0.9;

    % Datei schließen
    fclose(fid);

    d.Value = 1;

    % Überprüfen, ob Daten erfolgreich gelesen wurden
    if isempty(data{1})
        % Falls keine Daten gelesen wurden, gebe eine Meldung aus und ein leeres Array zurück
        disp('No data read from file'); % Debugging-Ausgabe
        data = [];
    else
        % Daten in ein Array umwandeln und Phase von Rad zu Grad umrechnen
        data = [(1:length(data{1}))', data{1}, data{2}, rad2deg(data{3})];
        disp(['Data read: ', num2str(size(data, 1)), ' rows']); % Debugging-Ausgabe
    end
    close(d)
end

%% Helfer- und Dienstprogramme

%% Eingabe-/Ausgabefunktionen