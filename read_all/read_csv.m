%% Setup- und Initialisierungsfunktionen

function [dataArrays, headerRows] = read_csv(filePaths, dataLines, selectedColumns)
    % Hauptfunktion zum Lesen von CSV-Dateien

    if nargin < 1 || isempty(filePaths)
        filePaths = selectFiles();
    end

    if isempty(filePaths)
        dataArrays = {};
        headerRows = [];
        return;
    end

    if nargin < 2 || isempty(dataLines)
        dataLines = [1, Inf]; % Standardmäßig alle Zeilen einlesen
    elseif ischar(dataLines) && strcmp(dataLines, 'last')
        dataLines = 'last'; % Spezieller Fall für die letzte Zeile
    elseif length(dataLines) == 1 && ~strcmp(dataLines, 'last')
        dataLines = [dataLines, dataLines];
    end

    if nargin < 3 || isempty(selectedColumns)
        selectedColumns = []; % Standardmäßig alle Spalten einlesen
    end

    [dataArrays, headerRows] = readDataFromFiles(filePaths, dataLines, selectedColumns);
end

%% Event-Handler und Callback-Funktionen

function filePaths = selectFiles()
    % Öffnet eine Dialogbox zur Auswahl von CSV-Dateien
    [filenames, pathname] = uigetfile('*.csv', 'Select the CSV file(s)', 'MultiSelect', 'on');

    if isequal(filenames, 0)
        disp('File selection canceled');
        filePaths = {};
        return;
    end

    if ischar(filenames)
        filenames = {filenames};
    end

    filePaths = fullfile(pathname, filenames);
end

%% Datenverarbeitungsfunktionen

function [dataArrays, headerRows] = readDataFromFiles(filePaths, dataLines, selectedColumns)
    % Liest Daten aus allen angegebenen Dateien
    dataArrays = cell(1, numel(filePaths));
    headerRows = zeros(1, numel(filePaths));

    for i = 1:numel(filePaths)
        fullpath = filePaths{i};
        disp(['Reading file: ', fullpath]);
        [dataArrays{i}, headerRows(i)] = readDataFromFile(fullpath, dataLines, selectedColumns);

        if isempty(dataArrays{i})
            disp(['No data found in file: ', fullpath]);
        else
            disp(['Data successfully read from file: ', fullpath]);
        end
        
        disp(['Header row in file: ', num2str(headerRows(i))]);
    end
end

function [data, headerRow] = readDataFromFile(filepath, dataLines, selectedColumns)
    % Liest die Daten aus einer CSV-Datei
    fig = evalin('base', 'fig');
    d = uiprogressdlg(fig,'Title','Bitte Warten',...
        'Message','Datei wird ausgelesen');
    try
        checkLast = 0;
        d.Value = 0.1;
        % Einlesen der gesamten Datei 
        opts = detectImportOptions(filepath, 'Delimiter', ',');
        d.Value = 0.2;

        if ischar(dataLines) && strcmp(dataLines, 'last')
            dataLines = [1, inf];
            checkLast = 1;
        end

        d.Value = 0.3;

        opts.DataLines = dataLines;
        opts.VariableNamingRule = 'preserve';
        d.Value = 0.4;

        if ~isempty(selectedColumns)
            opts.SelectedVariableNames = opts.VariableNames(selectedColumns);
        end
        d.Value = 0.5;

        d.Value = 0.6;
        dataTable = readtable(filepath, opts);
        d.Value = 0.7;

        % Konvertieren der Tabelle in ein Zell-Array
        data = table2cell(dataTable);
        d.Value = 0.8;

        % Suchen nach der header Zeile
        try
            headerRow = find(cellfun(@(x) isnan(x), data(:, 1)), 1, 'last');
        catch
            headerRow = find(cellfun(@(x) isnat(x), data(:, 1)), 1, 'last');
        end
        if isempty(headerRow)
            error('Header not found in file.');
        end

        d.Value = 0.9;

        if checkLast
            data = data(end, :);
        end
    catch ME
        disp(['Error reading file: ', filepath]);
        disp(ME.message);
        data = {};
        headerRow = NaN;
        if ~exist("fig") %#ok<EXIST> 
            fig = uifigure();
        end
        uialert(fig, ME.message, 'Fehler beim Lesen einer Datei.')
    end
    d.Value = 1;
    % Close dialog box
    close(d)
end

%% Helfer- und Dienstprogramme

%% Eingabe-/Ausgabefunktionen