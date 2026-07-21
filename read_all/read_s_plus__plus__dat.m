function [data, timestamps] = read_s_plus__plus__dat(seekTimestamps, fullFilePath, text)
    % Hauptfunktion zum Lesen von CSV-Dateien

    tStart = tic; % Timer starten
    if seekTimestamps
        numline = 2;
    else
        numline = 3;
    end
    textCell = text.Value;
    [~, filename, ~] = fileparts(fullFilePath);
    textCell{numline} = ['Reading: ', filename];
    text.Value = textCell;
    drawnow;

    num = 10000;
    if seekTimestamps
        textCell{numline+1} = ['Lines: ', num2str(0), ' - ', num2str(num)];
        text.Value = textCell;
        drawnow;
    end

    data = readtable(fullFilePath, 'Delimiter', '\t');
    
    timestamps = {};
    if seekTimestamps
        fid = fopen(fullFilePath, 'r');
        
        if fid == -1
            error('File could not be opened.');
        end

        timestampCount = 0;
        
        NaNIndex = find(isnan(data{:, end}), 1);
        indice = find(isnan(data{NaNIndex:end, end}));
        indice = diff(indice);
        notNaNIndex = NaNIndex + find(indice > 1, 1);
        lineInterval = notNaNIndex + 1;
    
        % Read the file lines with the specified interval
        while ~feof(fid)
            for i = 1:lineInterval
                line = fgetl(fid);
                if i == 1 % Check every first line in the interval
                    timestampCount = timestampCount + 1;
                    timestamps{end+1} = line; %#ok<*AGROW>
                    if mod(timestampCount, num) == 0
                        textCell{numline+1} = ['Lines: ', num2str(timestampCount), ' - ', num2str(timestampCount+num)];
                        text.Value = textCell;
                        drawnow;
                    end
                end
            end
        end
        
        fclose(fid); % Close the file
        % Display the total number of timestamps found
        fprintf('Total timestamps found: %d\n', timestampCount);
    end
    textCell{numline} = ['Read: ', filename];
    text.Value = textCell;
    toc(tStart)
end