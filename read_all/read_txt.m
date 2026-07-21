%% Setup- und Initialisierungsfunktionen

function [dataArray, slewRate] = read_txt(filePaths, configFile)
    % Hauptfunktion zum Lesen von txt-Dateien

    %Abruf der config.json und vervollständigen des Pfades zum Referenzordner
    configFile = fullfile(configFile, 'config.json');
    fid = fopen(configFile, 'r');
    jsonData = fscanf(fid, '%c');
    fclose(fid);
    configData = jsondecode(jsonData);
    txt_config = configData.read_txt;
    assignin("base", "config_txt", txt_config)
    
    % Überprüft die Eingabe und fordert bei Bedarf die Dateiauswahl an
    if nargin < 1 || isempty(filePaths)
        filePaths = selectFiles();
    end

    if isempty(filePaths)
        dataArray = {};
        return;
    end

    % Lese die Daten aus den angegebenen Dateien
    slewRate = 0;
    dataArray = readDataFromFiles(filePaths);
    if evalin('base', 'exist(''SlewRate'', ''var'')')
        slewRate = evalin('base', 'SlewRate');
        evalin('base', 'clear SlewRate');
    end
    evalin("base", 'clear config_txt')
end

%% Event-Handler und Callback-Funktionen

function filePaths = selectFiles()
    % Öffnet eine Dialogbox zur Auswahl von txt-Dateien
    
    [filenames, pathname] = uigetfile('*.txt', 'Select the txt file(s)', 'MultiSelect', 'on');
    
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
    % Liest Daten aus einer txt-Datei
    fig = evalin('base', 'fig');
    d = uiprogressdlg(fig,'Title','Bitte Warten',...
        'Message','Datei wird ausgelesen');
    
    % config laden
    config_txt = evalin("base", 'config_txt');
    header = config_txt.HeaderDerNurInZeileVorMessdatenIst;

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
    SlewrateFound = false;
    while ~feof(fid)
        currentLine = fgetl(fid);
        if contains(currentLine, header)      % Daten werden unter der ersten Zeile, die [Header] enthält, ausgelesen. 
            disp('Data header found'); % Debugging-Ausgabe
            headerFound = true;
            break;
        end
        if SlewrateFound == false
            if contains(currentLine, 'Slewrate')
                pattern = '\d+\.?\d*';
                matches = regexp(currentLine, pattern, 'match');
                assignin('base', 'SlewRate', str2double(matches{1}));
                SlewrateFound = true;
            end
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
    data = textscan(fid, '%f %f %f %f', 'Delimiter', ' ', 'MultipleDelimsAsOne', true);

    d.Value = 0.8;

    % Datei schließen
    fclose(fid);

    % Überprüfen, ob Daten erfolgreich gelesen wurden
    if isempty(data{1})
        % Falls keine Daten gelesen wurden, gebe eine Meldung aus und ein leeres Array zurück
        disp('No data read from file'); % Debugging-Ausgabe
        data = [];
        d.Value = 0.9;
    else
        % Daten in ein Array umwandeln
        data = [data{1}, data{2}, data{3}, data{4}];
        disp(['Data read: ', num2str(size(data, 1)), ' rows']); % Debugging-Ausgabe
        d.Value = 0.9;
    end
    d.Value = 1;
    close(d)
end

%% Helfer- und Dienstprogramme

%% Eingabe-/Ausgabefunktionen