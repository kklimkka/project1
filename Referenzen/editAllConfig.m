function editAllConfig(method, referenceFolder)
    try
        % Diese Funktion ermöglicht das Bearbeiten der config.json
        % Beim Öffnen wir die Funktion für die übergebene Methode aufgerufen und das entsprechende Fenster geöffnet
        % Bei manchen Eingaben wird die Eingabe direkt mit anderen Eingaben kombiniert oder richtig formatiert und im "base"-Workspace abgespeichert
        % Der "config.json"-Button öffnet jeweils die json-Datei 
        % Der "Speichern"-Button öffnet entweder direkt die Funktion "saveConfig" oder eine Methodenspezifische Funktion 
        % Die Methodenspezifischen Funktionen speichern alle Eingaben in Tabellen im "base"-Workspace ab und öffnen dann die Funktion "saveConfig"
        % Die Funktion "saveConfig" speichert wenn vorhanden alle Daten aus dem "bsae"-Workspace in die Config, dann wird
        % jeder von der Funktion übergebene Tag durchgegangen und die Eingabe jewils auch in der COnfig abgespeichert

        configPath = fullfile(referenceFolder, 'config.json');
    
        % Laden der aktuellen Konfiguration
        configData = loadConfigData(configPath);
        assignin("base", 'config', configData)
        assignin("base", 'configPath', configPath)
    
        switch lower(method)
            case('dcr')
                dcr()
            case('h2_crossover')
                h2_crossover()
            case('leckage')
                leckage()
            case('pk')
                pk()
            case('ocv_falloff')
                ocv_falloff()
            case('load__points')
                load__points()
            case('cv_ecsa')
                cv_ecsa()
            case('eis')
                eis()
            case('s_plus__plus_')
                s_plus__plus_()
        end
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler beim initialisieren der config.')
        disp(ME.message)
    end
end

function dcr()
    try
        config = evalin("base", 'config').DCR;
    
        tags = {'config.Titel1', 'config.Titel2', 'config.Nachkommastellen', 'config.Linienbreite', 'config.xyUntenStart', 'config.xyUntenEnde', ...
            'config.xyObenStart', 'config.xyObenEnde', 'config.obererGrenzwert', 'config.untererGrenzwert', 'config.xAchsenLimits(1)', ...
            'config.xAchsenLimits(2)', 'config.yAchsenLimits(1)', 'config.yAchsenLimits(2)', 'config.Spalten(1)', 'config.Spalten(2)', 'config.checkRef', ...
            'config.checkDUT', 'config.xlabel', 'config.ylabel', 'config.legendFontSize', 'config.xTickSize', 'config.yTickSize'};
    
        editFig = uifigure('Name', 'DCR Einstellungen', 'Position', [300, 242.5, 680, 320]);
    
        uibutton(editFig, 'Text', 'config.json öffnen', 'Position', [536, 50, 124, 30], ...
            'ButtonPushedFcn', @(btn, event) editConfigJson(editFig));
        
        uibutton(editFig, 'Text', 'Speichern', 'Position', [536, 10, 124, 30], ...
            'ButtonPushedFcn', @(btn, event) saveConfig(editFig, tags, 'DCR'));

        uilabel(editFig, "Text", 'X-Label des Plots:', 'Position', [20 293 640 22]);
        uitextarea(editFig, 'Position', [130 295 330 20], 'Value', config.xlabel, ...
            'Tag', 'config.xlabel');
        
        uilabel(editFig, "Text", 'Größe der x-Ticks:', 'Position', [480 293 310 22]);
        uispinner(editFig, 'Position', [590 295 70 20], 'Value', config.xTickSize, 'Tag', 'config.xTickSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Y-Label des Plots:', 'Position', [20 268 640 22]);
        uitextarea(editFig, 'Position', [130 270 330 20], 'Value', config.ylabel, ...
            'Tag', 'config.ylabel');
        
        uilabel(editFig, "Text", 'Größe der y-Ticks:', 'Position', [480 268 310 22]);
        uispinner(editFig, 'Position', [590 270 70 20], 'Value', config.yTickSize, 'Tag', 'config.yTickSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Titel Zeile 1:', 'Position', [20 240 640 22]);
        uitextarea(editFig, 'Position', [20 220 640 22], 'Value', config.Titel1, ...
            'Tag', 'config.Titel1');
        
        uilabel(editFig, "Text", 'Schriftgröße der Legende:', 'Position', [430 243 310 22]);
        uispinner(editFig, 'Position', [590 245 70 20], 'Value', config.legendFontSize, 'Tag', 'config.legendFontSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Titel Zeile 2:', 'Position', [20 195 640 22]);
        uitextarea(editFig, 'Position', [20 158 640 40], 'Value', config.Titel2, ...
            'Tag', 'config.Titel2');
        
        uilabel(editFig, "Text", 'Nachkommastellen für DCR-Ausgabe:', 'Position', [20 133 310 22]);
        uispinner(editFig, 'Position', [260 135 70 20], 'Value', config.Nachkommastellen, 'Tag', 'config.Nachkommastellen', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on');
        
        uilabel(editFig, "Text", 'Linienbreite für die Plotlinien:', 'Position', [350 133 640 22]);
        uispinner(editFig, 'Position', [590 135 70 20], 'Value', config.Linienbreite, 'Tag', 'config.Linienbreite', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off');
        
        uilabel(editFig, 'Position', [20 108 79 22], 'Text', 'xyUnten Start:', 'Tag', 'xyUntenStartLabel');
        uispinner(editFig, 'Position', [110 110 70 20], 'Value', config.xyUntenStart, 'Tag', 'config.xyUntenStart', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, 'Position', [232.5 108 79 22], 'Text', 'xyUnten Ende:', 'Tag', 'xyUntenEndLabel');
        uispinner(editFig, 'Position', [322.5 110 70 20], 'Value', config.xyUntenEnde, 'Tag', 'config.xyUntenEnde', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, 'Position', [445 108 132 22], 'Text', 'Unterer Stromgrenzwert:', 'Tag', 'untererGrenzwertLabel');
        uispinner(editFig, 'Position', [590 110 70 20], 'Value', config.untererGrenzwert, 'Tag', 'config.untererGrenzwert', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.01);
        
        uilabel(editFig, 'Position', [20 83 79 22], 'Text', 'xyOben Start:', 'Tag', 'xyObenStartLabel');
        uispinner(editFig, 'Position', [110 85 70 20], 'Value', config.xyObenStart, 'Tag', 'config.xyObenStart', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, 'Position', [232.5 83 79 22], 'Text', 'xyOben Ende:', 'Tag', 'xyObenEndLabel');
        uispinner(editFig, 'Position', [322.5 85 70 20], 'Value', config.xyObenEnde, 'Tag', 'config.xyObenEnde', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, 'Position', [445 83 132 22], 'Text', 'Oberer Stromgrenzwert:', 'Tag', 'obererGrenzwertLabel');
        uispinner(editFig, 'Position', [590 85 70 20], 'Value', config.obererGrenzwert, 'Tag', 'config.obererGrenzwert', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.01);
        
        uilabel(editFig, "Text", 'x-Achsenlimits:', 'Position', [20 58 82 22]);
        uispinner(editFig, 'Position', [110 60 70 20], 'Value', config.xAchsenLimits(1), 'Tag', 'config.xAchsenLimits(1)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'bis', 'Position', [183 58 25 22]);
        uispinner(editFig, 'Position', [205 60 70 20], 'Value', config.xAchsenLimits(2), 'Tag', 'config.xAchsenLimits(2)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'y-Achsenlimits:', 'Position', [20 33 90 22]);
        uispinner(editFig, 'Position', [110 35 70 20], 'Value', config.yAchsenLimits(1), 'Tag', 'config.yAchsenLimits(1)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'bis', 'Position', [183 33 25 22]);
        uispinner(editFig, 'Position', [205 35 70 20], 'Value', config.yAchsenLimits(2), 'Tag', 'config.yAchsenLimits(2)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Spalte der U-Werte:', 'Position', [300 58 110 22]);
        uispinner(editFig, 'Position', [415 60 70 20], 'Value', config.Spalten(1), 'Tag', 'config.Spalten(1)', ...
            "Limits", [1, inf], 'RoundFractionalValues', 'on', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Spalte der I-Werte:', 'Position', [300 33 110 22]);
        uispinner(editFig, 'Position', [415 35 70 20], 'Value', config.Spalten(2), 'Tag', 'config.Spalten(2)', ...
            "Limits", [1, inf], 'RoundFractionalValues', 'on', 'UpperLimitInclusive', 'off');
        
        uicheckbox(editFig, "Text", 'Referenzdaten anzeigen', 'Position', [20 10 150 22], 'Value', config.checkRef, ...
            'Tag', 'config.checkRef');
        
        uicheckbox(editFig, "Text", 'DUT anzeigen', 'Position', [200 10 150 22], 'Value', config.checkDUT, ...
            'Tag', 'config.checkDUT');
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler in der config')
        disp(ME.message)
    end
end

function leckage()
    try
        config = evalin("base", 'config').Leckage;
    
        tags = {'config.Spalten', 'config.Zeilen', 'config.NachkommastellenPlot', 'config.NachkommastellenTabelle', 'config.Grenzwert', ...
                'config.yAchsenLimits(1)','config.yAchsenLimits(2)', 'config.checkRef', 'config.checkDUT', 'config.xlabel', 'config.ylabel', ...
                'config.legendFontSize','config.xTickSize', 'config.yTickSize', 'config.titleFontSize'};
    
        editFig = uifigure('Name', 'Leckage Einstellungen', 'Position', [300, 261, 680, 283]);
    
        uibutton(editFig, 'Text', 'config.json öffnen', 'Position', [536, 50, 124, 30], ...
            'ButtonPushedFcn', @(btn, event) editConfigJson(editFig));
        
        uibutton(editFig, 'Text', 'Speichern', 'Position', [536, 10, 124, 30], ...
            'ButtonPushedFcn', @(btn, event) saveConfig(editFig, tags, 'Leckage'));

        uilabel(editFig, "Text", 'X-Label des Plots:', 'Position', [20 257 640 22]);
        uitextarea(editFig, 'Position', [130 259 330 20], 'Value', config.xlabel, ...
            'Tag', 'config.xlabel');
        
        uilabel(editFig, "Text", 'Größe der x-Ticks:', 'Position', [480 257 310 22]);
        uispinner(editFig, 'Position', [590 259 70 20], 'Value', config.xTickSize, 'Tag', 'config.xTickSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Y-Label des Plots:', 'Position', [20 232 640 22]);
        uitextarea(editFig, 'Position', [130 234 330 20], 'Value', config.ylabel, ...
            'Tag', 'config.ylabel');
        
        uilabel(editFig, "Text", 'Größe der y-Ticks:', 'Position', [480 232 310 22]);
        uispinner(editFig, 'Position', [590 234 70 20], 'Value', config.yTickSize, 'Tag', 'config.yTickSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Schriftgröße des Titels:', 'Position', [20 207 125 22]);
        uispinner(editFig, 'Position', [147 209 70 20], 'Value', config.titleFontSize, 'Tag', 'config.titleFontSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Schriftgröße der Legende:', 'Position', [230 207 140 22]);
        uispinner(editFig, 'Position', [375 209 70 20], 'Value', config.legendFontSize, 'Tag', 'config.legendFontSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Grenzwert [mbar/min]:', 'Position', [460 207 125 22]);
        uispinner(editFig, 'Position', [590 209 70 20], 'Value', config.Grenzwert, 'Tag', 'config.Grenzwert', 'Step', 1, ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        try
            spaltenArray = strsplit(config.Spalten{1}, ',');
        catch
            spaltenArray = strsplit(config.Spalten, ',');
        end
        uilabel(editFig, "Text", 'Spalten der CSV:', 'Position', [20 182 640 22]);
        uitextarea(editFig, 'Value', config.Spalten, 'Editable', 'off', 'Position', [160 184 170 20], 'Tag', 'config.Spalten');
        
        uilabel(editFig, "Text", 'y-Achsenlimits:', 'Position', [350 182 90 22]);
        uispinner(editFig, 'Position', [465 184 70 20], 'Value', config.yAchsenLimits(1), 'Tag', 'config.yAchsenLimits(1)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'bis', 'Position', [553 182 25 22]);
        uispinner(editFig, 'Position', [590 184 70 20], 'Value', config.yAchsenLimits(2), 'Tag', 'config.yAchsenLimits(2)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        SpaltenTags =  {'spaltenArray{1}', 'spaltenArray{2}', 'spaltenArray{3}', 'spaltenArray{4}',  ...
                         'spaltenArray{5}','spaltenArray{6}', 'spaltenArray{7}', 'spaltenArray{8}'};
    
        uitextarea(editFig, 'Value', 'Leak check extern:', 'Position', [17 137 646 41], 'BackgroundColor', editFig.Color);
        uilabel(editFig, "Text", 'Anode pressure start:', 'Position', [20 140 640 22]);
        uieditfield(editFig, 'text', 'Position', [140 140 30 22], 'Value', spaltenArray{1}, 'Tag', 'spaltenArray{1}', ...
            'ValueChangedFcn', @(src, event) buildLeakageColumnString(editFig, SpaltenTags));
        uilabel(editFig, "Text", 'Cathode pressure start:', 'Position', [175 140 640 22]);
        uieditfield(editFig, 'text', 'Position', [310 140 30 22], 'Value', spaltenArray{2}, 'Tag', 'spaltenArray{2}', ...
            'ValueChangedFcn', @(src, event) buildLeakageColumnString(editFig, SpaltenTags));
        uilabel(editFig, "Text", 'Anode pressure end:', 'Position', [350 140 640 22]);
        uieditfield(editFig, 'text', 'Position', [470 140 30 22], 'Value', spaltenArray{3}, 'Tag', 'spaltenArray{3}', ...
            'ValueChangedFcn', @(src, event) buildLeakageColumnString(editFig, SpaltenTags));
        uilabel(editFig, "Text", 'Cathode pressure end:', 'Position', [505 140 640 22]);
        uieditfield(editFig, 'text', 'Position', [630 140 30 22], 'Value', spaltenArray{4}, 'Tag', 'spaltenArray{4}', ...
            'ValueChangedFcn', @(src, event) buildLeakageColumnString(editFig, SpaltenTags));
    
        uitextarea(editFig, 'Value', 'Leak check intern:', 'Position', [17 87 646 41], 'BackgroundColor', editFig.Color);
        uilabel(editFig, "Text", 'Anode pressure start:', 'Position', [20 90 640 22]);
        uieditfield(editFig, 'text', 'Position', [140 90 30 22], 'Value', spaltenArray{5}, 'Tag', 'spaltenArray{5}', ...
            'ValueChangedFcn', @(src, event) buildLeakageColumnString(editFig, SpaltenTags));
        uilabel(editFig, "Text", 'Cathode pressure start:', 'Position', [175 90 640 22]);
        uieditfield(editFig, 'text', 'Position', [310 90 30 22], 'Value', spaltenArray{6}, 'Tag', 'spaltenArray{6}', ...
            'ValueChangedFcn', @(src, event) buildLeakageColumnString(editFig, SpaltenTags));
        uilabel(editFig, "Text", 'Anode pressure end:', 'Position', [350 90 640 22]);
        uieditfield(editFig, 'text', 'Position', [470 90 30 22], 'Value', spaltenArray{7}, 'Tag', 'spaltenArray{7}', ...
            'ValueChangedFcn', @(src, event) buildLeakageColumnString(editFig, SpaltenTags));
        uilabel(editFig, "Text", 'Cathode pressure end:', 'Position', [505 90 640 22]);
        uieditfield(editFig, 'text', 'Position', [630 90 30 22], 'Value', spaltenArray{8}, 'Tag', 'spaltenArray{8}', ...
            'ValueChangedFcn', @(src, event) buildLeakageColumnString(editFig, SpaltenTags));
        
        uilabel(editFig, "Text", 'Zeilen der CSV:', 'Position', [20 58 150 22]);
        uitextarea(editFig, 'Position', [120 58 396 22], 'Value', config.Zeilen, ...
            'Tag', 'config.Zeilen');
        
        uilabel(editFig, "Text", 'Nachkommastellen für Werte im Plot:', 'Position', [20 33 310 22]);
        uispinner(editFig, 'Position', [260 35 70 20], 'Value', config.NachkommastellenPlot, 'Tag', 'config.NachkommastellenPlot', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on');
        
        uilabel(editFig, "Text", 'Nachkommastellen für Werte in der Tabelle:', 'Position', [20 8 310 22]);
        uispinner(editFig, 'Position', [260 10 70 20], 'Value', config.NachkommastellenTabelle, 'Tag', 'config.NachkommastellenTabelle', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on');
        
        uicheckbox(editFig, "Text", 'Referenzdaten anzeigen', 'Position', [340 35 150 22], 'Value', config.checkRef, ...
            'Tag', 'config.checkRef');
        
        uicheckbox(editFig, "Text", 'DUT anzeigen', 'Position', [340 10 150 22], 'Value', config.checkDUT, ...
            'Tag', 'config.checkDUT');
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler in der config')
        disp(ME.message)
    end
end

function buildLeakageColumnString(editFig, tags)
    try
        spaltenStringObj = findobj(editFig, 'Tag', 'config.Spalten');
        spaltenString = findobj(editFig, 'Tag', tags{1}).Value;
        for i = 2:length(tags)
            spaltenString = [spaltenString, ',', findobj(editFig, 'Tag', tags{i}).Value]; %#ok<AGROW> 
        end
        spaltenStringObj.Value = upper(spaltenString);
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler beim ändern der Spalten')
        disp(ME.message)
    end
end

function ocv_falloff()
    try
        config = evalin("base", 'config').OCV_FallOff;
    
        tags = {'config.Titel1', 'config.Titel2', 'config.yAchsenLimits(1)', 'config.yAchsenLimits(2)', 'config.lineWidth', 'config.Grenzwert', ...
            'config.ZeilenVorGrenzwert', 'config.StartManuell', 'config.Darstellungslaenge', 'config.xMin', 'config.xMax', ...
            'config.Spalten', 'config.H2N2Grenzen(1)', 'config.H2N2Grenzen(2)', 'config.OCVGrenzen(1)', 'config.OCVGrenzen(2)', ...
	        'config.FallOffGrenzen(1)', 'config.FallOffGrenzen(2)', 'config.checkRef', 'config.checkDUT', 'config.checkStartManuell', ...
            'config.xlabel', 'config.ylabel', 'config.legendFontSize', 'config.yTickSize', 'config.H2N2TextSize', 'config.OCVTextSize', ...
            'config.FallOffTextSize'};
    
        editFig = uifigure('Name', 'OCV-FallOff Einstellungen', 'Position', [300, 80, 680, 645]);

        % Creating the column table        
        uilabel(editFig, 'text', 'Parameter für Referenzdateien (bitte gleich viele Zeilen wie Ref-Dateien angeben):', 'Position', [20 615 510 15]);
        columnNames = {'U-Grenzenwerte', 'manuelle Startzeile', 'Startzeile nutzen'};
        ct = uitable(editFig, 'Data', [config.RefGrenzenwerte(:), config.RefStartzeile(:), config.RefStartzeileNutzen(:)], ...
            'ColumnName', columnNames, 'ColumnEditable', [true, true, true], 'Position', [20, 434, 640, 175], ...
            'ColumnWidth', {'40x', '40x','20x'}, 'FontSize', 11, 'ColumnFormat', {'numeric', 'numeric', 'logical'});

        % Button to add a new row
        uibutton(editFig, 'Text', 'Neue Zeile hinzufügen', 'Position', [20, 395, 310, 30], ...
            'ButtonPushedFcn', @(btn, event) addRow(ct));
    
        % Button to remove selected row
        uibutton(editFig, 'Text', 'Zeile entfernen', 'Position', [350, 395, 310, 30], ...
            'ButtonPushedFcn', @(btn, event) removeRow(ct));
    
        uibutton(editFig, 'Text', 'config.json öffnen', 'Position', [536, 50, 124, 30], ...
            'ButtonPushedFcn', @(btn, event) editConfigJson(editFig));
        
        uibutton(editFig, 'Text', 'Speichern', 'Position', [536, 10, 124, 30], ...
            'ButtonPushedFcn', @(btn, event) saveOCV(editFig, ct, tags));
        
        uilabel(editFig, "Text", 'X-Label des Plots:', 'Position', [20 365 640 22]);
        uitextarea(editFig, 'Position', [130 367 290 20], 'Value', config.xlabel, ...
            'Tag', 'config.xlabel');
        
        uilabel(editFig, "Text", 'Schriftgröße der Legende:', 'Position', [430 365 310 22]);
        uispinner(editFig, 'Position', [590 367 70 20], 'Value', config.legendFontSize, 'Tag', 'config.legendFontSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Y-Label des Plots:', 'Position', [20 340 640 22]);
        uitextarea(editFig, 'Position', [130 342 290 20], 'Value', config.ylabel, ...
            'Tag', 'config.ylabel');
        
        uilabel(editFig, "Text", 'Größe der y-Ticks:', 'Position', [430 340 310 22]);
        uispinner(editFig, 'Position', [590 342 70 20], 'Value', config.yTickSize, 'Tag', 'config.yTickSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, 'Position', [20 315 260 22], 'Text', 'Schriftgrößen der Texte:                         H2N2:');
        uispinner(editFig, 'Position', [275 317 70 20], 'Value', config.H2N2TextSize,'Tag', 'config.H2N2TextSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, 'Position', [385 315 150 22], 'Text', 'OCV:');
        uispinner(editFig, 'Position', [425 317 70 20], 'Value', config.OCVTextSize, 'Tag', 'config.OCVTextSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, 'Position', [540 315 150 22], 'Text', 'FallOff:');
        uispinner(editFig, 'Position', [590 317 70 20], 'Value', config.FallOffTextSize, 'Tag', 'config.FallOffTextSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Titel Zeile 1:', 'Position', [20 300 640 15]);
        uitextarea(editFig, 'Position', [20 275 640 22], 'Value', config.Titel1, ...
            'Tag', 'config.Titel1');
        
        uilabel(editFig, "Text", 'Titel Zeile 2:', 'Position', [20 250 640 22]);
        uitextarea(editFig, 'Position', [20 213 640 40], 'Value', config.Titel2, ...
            'Tag', 'config.Titel2');
        
        uilabel(editFig, "Text", 'y-Achsenlimits:', 'Position', [20 185 90 22]);
        uilabel(editFig, "Text", 'von', 'Position', [134 185 25 22]);
        uispinner(editFig, 'Position', [161 187 70 20], 'Value', config.yAchsenLimits(1), 'Tag', 'config.yAchsenLimits(1)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'bis', 'Position', [238 185 25 22]);
        uispinner(editFig, 'Position', [260 187 70 20], 'Value', config.yAchsenLimits(2), 'Tag', 'config.yAchsenLimits(2)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Linienbreite für die Plotlinien:', 'Position', [350 185 640 22]);
        uispinner(editFig, 'Position', [590 187 70 20], 'Value', config.lineWidth, 'Tag', 'config.lineWidth', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, 'Position', [20 160 200 22], 'Text', 'Grenzwert für Startsuche [V]:');
        uispinner(editFig, 'Position', [260 162 70 20], 'Value', config.Grenzwert, 'Tag', 'config.Grenzwert', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.1);
        
        uilabel(editFig, 'Position', [350 160 200 22], 'Text', 'Zeilen vor Grenzwert:');
        uispinner(editFig, 'Position', [590 162 70 20], 'Value', config.ZeilenVorGrenzwert, 'Tag', 'config.ZeilenVorGrenzwert', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'on');
        
        uilabel(editFig, 'Position', [20 135 200 22], 'Text', 'Manueller Startpunkt:');
        uispinner(editFig, 'Position', [260 137 70 20], 'Value', config.StartManuell, 'Tag', 'config.StartManuell', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on');
        
        uilabel(editFig, 'Position', [350 135 200 22], 'Text', 'Standarddarstellungslänge des Plots:');
        uispinner(editFig, 'Position', [590 137 70 20], 'Value', config.Darstellungslaenge, 'Tag', 'config.Darstellungslaenge', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, 'Position', [20 110 200 22], 'Text', 'Standardwert für xMin:');
        uitextarea(editFig, 'Position', [260 110 70 22], 'Value', config.xMin, 'Tag', 'config.xMin');
        
        uilabel(editFig, 'Position', [350 110 200 22], 'Text', 'Standardwert für xMax:');
        uitextarea(editFig, 'Position', [590 110 70 22], 'Value', config.xMax, 'Tag', 'config.xMax');
    
        assignin("base", 'Zeilen', config.Zeilen)
        lineTags = {'config.Zeilen{1}', 'config.Zeilen{2}'};
        uilabel(editFig, "Text", 'Relevante Zeilen der CSV:', 'Position', [20 85 200 22]);
        uilabel(editFig, "Text", 'von', 'Position', [165 85 25 22]);
        uilabel(editFig, "Text", 'bis', 'Position', [265 85 25 22]);
        try
            uispinner(editFig, 'Position', [190 87 70 20], 'Value', config.Zeilen{1}, 'Tag', 'config.Zeilen{1}', ...
                "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
            try
                uispinner(editFig, 'Position', [287 87 70 20], 'Value', str2double(config.Zeilen{2}), 'Tag', 'config.Zeilen{2}', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
            catch
                uispinner(editFig, 'Position', [287 87 70 20], 'Value', config.Zeilen{2}, 'Tag', 'config.Zeilen{2}', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
            end
        catch
            uispinner(editFig, 'Position', [190 87 70 20], 'Value', config.Zeilen(1), 'Tag', 'config.Zeilen{1}', ...
                "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
            try
                uispinner(editFig, 'Position', [287 87 70 20], 'Value', str2double(config.Zeilen(2)), 'Tag', 'config.Zeilen{2}', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
            catch
                uispinner(editFig, 'Position', [287 87 70 20], 'Value', config.Zeilen(2), 'Tag', 'config.Zeilen{2}', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
            end
        end

        
        uilabel(editFig, "Text", 'Spalte der U-Werte in der CSV:', 'Position', [366 85 200 22]);
        uispinner(editFig, 'Position', [590 87 70 20], 'Value', config.Spalten, 'Tag', 'config.Spalten', ...
            "Limits", [1, inf], 'RoundFractionalValues', 'on', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Grenzen der H₂N₂-Box:', 'Position', [20 60 200 22]);
        uilabel(editFig, "Text", 'von', 'Position', [165 60 25 22]);
        uispinner(editFig, 'Position', [190 62 70 20], 'Value', config.H2N2Grenzen(1), 'Tag', 'config.H2N2Grenzen(1)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off');
        
        uilabel(editFig, "Text", 'bis', 'Position', [265 60 25 22]);
        uispinner(editFig, 'Position', [287 62 70 20], 'Value', config.H2N2Grenzen(2), 'Tag', 'config.H2N2Grenzen(2)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off');
        
        uilabel(editFig, "Text", 'Grenzen der OCV-Box:', 'Position', [20 35 200 22]);
        uilabel(editFig, "Text", 'von', 'Position', [165 35 25 22]);
        uispinner(editFig, 'Position', [190 37 70 20], 'Value', config.OCVGrenzen(1), 'Tag', 'config.OCVGrenzen(1)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off');
        
        uilabel(editFig, "Text", 'bis', 'Position', [265 35 25 22]);
        uispinner(editFig, 'Position', [287 37 70 20], 'Value', config.OCVGrenzen(2), 'Tag', 'config.OCVGrenzen(2)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off');
        
        uilabel(editFig, "Text", 'Grenzen der FallOff-Box:', 'Position', [20 10 200 22]);
        uilabel(editFig, "Text", 'von', 'Position', [165 10 25 22]);
        uispinner(editFig, 'Position', [190 12 70 20], 'Value', config.FallOffGrenzen(1), 'Tag', 'config.FallOffGrenzen(1)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off');
        
        uilabel(editFig, "Text", 'bis', 'Position', [265 10 25 22]);
        uispinner(editFig, 'Position', [287 12 70 20], 'Value', config.FallOffGrenzen(2), 'Tag', 'config.FallOffGrenzen(2)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off');
        
        uicheckbox(editFig, "Text", 'Referenzdaten anzeigen', 'Position', [366 60 150 22], 'Value', config.checkRef, ...
            'Tag', 'config.checkRef');
        
        uicheckbox(editFig, "Text", 'DUT anzeigen', 'Position', [366 35 100 22], 'Value', config.checkDUT, ...
            'Tag', 'config.checkDUT');
        
        uicheckbox(editFig, "Text", 'Startwert manuell festlegen', 'Position', [366 10 170 22], 'Value', config.checkStartManuell, ...
            'Tag', 'config.checkStartManuell');
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler in der config')
        disp(ME.message)
    end
end

function saveOCV(editFig, columnTableHandle, tags)
    try
        % Get the data from the tables
        columnData = columnTableHandle.Data;
        assignin("base", "columnTableData", columnData)
    
        % Call the existing saveConfig function
        saveConfig(editFig, tags, 'OCV_FallOff');
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler beim speichern der OCV-config')
        disp(ME.message)
    end
end

function buildOCVLineString(editFig, tags)
    try
        zeilenString = cell(1, length(tags));
        zeilenString{1} = processInf(findobj(editFig, 'Tag', tags{1}).Value);
        for i = 2:length(tags)
    %         zeilenString = [zeilenString, ',', processInf(findobj(editFig, 'Tag', tags{i}).Value)]; %#ok<AGROW> 
            zeilenString{i} = processInf(findobj(editFig, 'Tag', tags{i}).Value);
        end
        
        assignin("base", 'Zeilen', zeilenString);
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler beim Anpassen der Zeilen')
        disp(ME.message)
    end
end

function data = processInf(data)
    try
        if ischar(data) && strcmpi(data, 'inf')
            data = "Inf";
        elseif isnumeric(data) && isinf(data)
            data = "Inf";
        end
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler beim prüfen ob die Eingabe Inf ist')
        disp(ME.message)
    end
end

function cv_ecsa()
    try
        config = evalin("base", 'config').CV_ECSA;
    
        tags = {'config.Titel1', 'config.Titel2', 'config.xAchsenLimits(1)', 'config.xAchsenLimits(2)', 'config.yAchsenLimits(1)', ...
            'config.yAchsenLimits(2)', 'config.SpannungsbereichFuerDLSuche(1)', 'config.SpannungsbereichFuerDLSuche(2)', 'config.Spalten(1)', ...
            'config.Spalten(2)', 'config.Nachkommastellen', 'config.lineWidth', 'config.StartIntAn', 'config.StartIntCath', 'config.Flaeche', ...
            'config.PtLoading', 'config.checkRef', 'config.checkDUT', 'config.checkSlow', 'config.checkFast', 'config.xlabel','config.ylabel', ...
            'config.legendFontSize', 'config.xTickSize', 'config.yTickSize', 'config.checkECSA', 'config.ECSALabelFontSize'};
    
        editFig = uifigure('Name', 'CV-ECSA Einstellungen', 'Position', [300, 90, 680, 622]);

        % Creating the column table        
        uilabel(editFig, 'text', 'Parameter für Referenzdateien (bitte gleich viele Zeilen wie Ref-Dateien angeben):', 'Position', [20 592 510 15]);
        columnNames = {'Fast Slew Rate', 'Pt loading', 'Active Area'};
        ct = uitable(editFig, 'Data', [config.refFastSlewRate(:), config.refPtLoading(:), config.refActiveArea(:)], ...
            'ColumnName', columnNames, 'ColumnEditable', [true, true, true], 'Position', [20, 411, 640, 175], ...
            'ColumnWidth', {'40x', '40x', '40x'}, 'FontSize', 11, 'ColumnFormat', {'numeric', 'numeric', 'numeric'});

        % Button to add a new row
        uibutton(editFig, 'Text', 'Neue Zeile hinzufügen', 'Position', [20, 372, 310, 30], ...
            'ButtonPushedFcn', @(btn, event) addRow(ct));
    
        % Button to remove selected row
        uibutton(editFig, 'Text', 'Zeile entfernen', 'Position', [350, 372, 310, 30], ...
            'ButtonPushedFcn', @(btn, event) removeRow(ct));
    
        uibutton(editFig, 'Text', 'config.json öffnen', 'Position', [536, 50, 124, 30], ...
            'ButtonPushedFcn', @(btn, event) editConfigJson(editFig));
        
        uibutton(editFig, 'Text', 'Speichern', 'Position', [536, 10, 124, 30], ...
            'ButtonPushedFcn', @(btn, event) saveCV(editFig, ct, tags));

        uilabel(editFig, "Text", 'X-Label des Plots:', 'Position', [20 340 640 22]);
        uitextarea(editFig, 'Position', [130 342 280 20], 'Value', config.xlabel, ...
            'Tag', 'config.xlabel');
        
        uilabel(editFig, "Text", 'Größe der x-Ticks:', 'Position', [430 340 310 22]);
        uispinner(editFig, 'Position', [590 342 70 20], 'Value', config.xTickSize, 'Tag', 'config.xTickSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Y-Label des Plots:', 'Position', [20 315 640 22]);
        uitextarea(editFig, 'Position', [130 317 280 20], 'Value', config.ylabel, ...
            'Tag', 'config.ylabel');
        
        uilabel(editFig, "Text", 'Größe der y-Ticks:', 'Position', [430 315 310 22]);
        uispinner(editFig, 'Position', [590 317 70 20], 'Value', config.yTickSize, 'Tag', 'config.yTickSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Titel Zeile 1:', 'Position', [20 295 300 15]);
        uitextarea(editFig, 'Position', [20 270 640 22], 'Value', config.Titel1, ...
            'Tag', 'config.Titel1');
        
        uilabel(editFig, "Text", 'Titel Zeile 2:', 'Position', [20 247 640 22]);
        uitextarea(editFig, 'Position', [20 212 640 38], 'Value', config.Titel2, ...
            'Tag', 'config.Titel2');
        
        uilabel(editFig, "Text", 'x-Achsenlimits:', 'Position', [20 185 90 22]);
        uilabel(editFig, "Text", 'von', 'Position', [134 185 25 22]);
        uispinner(editFig, 'Position', [161 187 70 20], 'Value', config.xAchsenLimits(1), 'Tag', 'config.xAchsenLimits(1)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'bis', 'Position', [238 185 25 22]);
        uispinner(editFig, 'Position', [260 187 70 20], 'Value', config.xAchsenLimits(2), 'Tag', 'config.xAchsenLimits(2)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'y-Achsenlimits:', 'Position', [350 185 90 22]);
        uilabel(editFig, "Text", 'von', 'Position', [473 185 25 22]);
        uispinner(editFig, 'Position', [498 187 70 20], 'Value', config.yAchsenLimits(1), 'Tag', 'config.yAchsenLimits(1)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'bis', 'Position', [573 185 25 22]);
        uispinner(editFig, 'Position', [590 187 70 20], 'Value', config.yAchsenLimits(2), 'Tag', 'config.yAchsenLimits(2)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Spalten in der txt-Datei:', 'Position', [20 160 150 22]);
        uilabel(editFig, "Text", 'U:', 'Position', [153 160 25 22]);
        uispinner(editFig, 'Position', [168 162 70 20], 'Value', config.Spalten(1), 'Tag', 'config.Spalten(1)', ...
            "Limits", [1, inf], 'RoundFractionalValues', 'on', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'I:', 'Position', [248 160 25 22]);
        uispinner(editFig, 'Position', [260 162 70 20], 'Value', config.Spalten(2), 'Tag', 'config.Spalten(2)', ...
            "Limits", [1, inf], 'RoundFractionalValues', 'on', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Schriftgröße der Legende:', 'Position', [350 160 150 22]);
        uispinner(editFig, 'Position', [590 162 70 20], 'Value', config.legendFontSize, 'Tag', 'config.legendFontSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, 'Position', [20 135 250 22], 'Text', 'Nachkommastellen für ECSA-Ausgabe:');
        uispinner(editFig, 'Position', [260 137 70 20], 'Value', config.Nachkommastellen, 'Tag', 'config.Nachkommastellen', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on');
    
        uilabel(editFig, "Text", 'Linienbreite für die Plotlinien:', 'Position', [350 135 640 22]);
        uispinner(editFig, 'Position', [590 137 70 20], 'Value', config.lineWidth, 'Tag', 'config.lineWidth', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, 'Position', [20 110 200 22], 'Text', 'Start der anodischen Integration:');
        uispinner(editFig, 'Position', [260 112 70 20], 'Value', config.StartIntAn, 'Tag', 'config.StartIntAn', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'Step', 0.01);
        
        uilabel(editFig, 'Position', [350 110 200 22], 'Text', 'Start der kathodischen Integration:');
        uispinner(editFig, 'Position', [590 112 70 20], 'Value', config.StartIntCath, 'Tag', 'config.StartIntCath', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'Step', 0.01);
        
        uilabel(editFig, 'Position', [20 85 200 22], 'Text', 'Active Area:');
        uispinner(editFig, 'Position', [260 87 70 20], 'Value', config.Flaeche, 'Tag', 'config.Flaeche', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'ValueDisplayFormat', '%11.7g', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, 'Position', [350 85 200 22], 'Text', 'PtLoading:');
        uispinner(editFig, 'Position', [590 87 70 20], 'Value', config.PtLoading, 'Tag', 'config.PtLoading', 'ValueDisplayFormat', '%11.5g', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
    
        uilabel(editFig, "Text", 'Spannungsbereich fuer DL-Suche:', 'Position', [20 60 200 22]);
        uilabel(editFig, "Text", 'von', 'Position', [238 60 25 22]);
        uispinner(editFig, 'Position', [260 62 70 20], 'Value', config.SpannungsbereichFuerDLSuche(1), 'Tag', 'config.SpannungsbereichFuerDLSuche(1)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001);
        
        uilabel(editFig, "Text", 'bis', 'Position', [350 60 25 22]);
        uispinner(editFig, 'Position', [370 62 70 20], 'Value', config.SpannungsbereichFuerDLSuche(2), 'Tag', 'config.SpannungsbereichFuerDLSuche(2)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001);
        
        uicheckbox(editFig, "Text", 'Referenzdaten anzeigen', 'Position', [20 35 150 22], 'Value', config.checkRef, ...
            'Tag', 'config.checkRef');
        
        uicheckbox(editFig, "Text", 'DUT anzeigen', 'Position', [180 35 100 22], 'Value', config.checkDUT, ...
            'Tag', 'config.checkDUT');
        
        uicheckbox(editFig, "Text", 'Schnelle Daten anzeigen', 'Position', [20 10 155 22], 'Value', config.checkSlow, ...
            'Tag', 'config.checkSlow');
    
        uicheckbox(editFig, "Text", 'Langsame Daten anzeigen', 'Position', [180 10 165 22], 'Value', config.checkFast, ...
            'Tag', 'config.checkFast');
        
        uicheckbox(editFig, "Text", 'ECSA-Ø anzeigen', 'Position', [350 35 120 22], 'Value', config.checkECSA, ...
            'Tag', 'config.checkECSA');
        
        uilabel(editFig, "Text", 'Schriftgröße von ECSA:', 'Position', [350 10 165 22]);
        uispinner(editFig, 'Position', [480 12 50 20], 'Value', config.ECSALabelFontSize, 'Tag', 'config.ECSALabelFontSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
    
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler in der config')
        disp(ME.message)
    end
end

function saveCV(editFig, columnTableHandle, tags)
    try
        % Get the data from the tables
        columnData = columnTableHandle.Data;
        assignin("base", "columnTableData", columnData)
    
        % Call the existing saveConfig function
        saveConfig(editFig, tags, 'CV_ECSA');
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler beim speichern der OCV-config')
        disp(ME.message)
    end
end

function h2_crossover()
    try
        config = evalin("base", 'config').H2_Crossover;
    
        tags = {'config.Titel1', 'config.Titel2', 'config.Nachkommastellen_I', 'config.lineWidth', 'config.Flaeche', 'config.xAchsenLimitsGesamt(1)', ...
            'config.xAchsenLimitsGesamt(2)', 'config.yAchsenLimitsGesamt(1)', 'config.yAchsenLimitsGesamt(2)', 'config.xAchsenLimitsFit(1)', ...
            'config.xAchsenLimitsFit(2)', 'config.yAchsenLimitsFit(1)', 'config.yAchsenLimitsFit(2)', 'config.UMin', 'config.UMax', ...
            'config.Spalten(1)', 'config.Spalten(2)', 'config.xlabel', 'config.ylabel', 'config.legendFontSize',  'config.xTickSize', ...
            'config.yTickSize', 'config.IH2_CrossoverSize', 'config.fitTextSize', 'config.Nachkommastellen_y'};
    
        editFig = uifigure('Name', 'H2-Crossover Einstellungen', 'Position', [300, 225, 680, 355]);
    
        uibutton(editFig, 'Text', 'config.json öffnen', 'Position', [536, 50, 124, 30], ...
            'ButtonPushedFcn', @(btn, event) editConfigJson(editFig));
        
        uibutton(editFig, 'Text', 'Speichern', 'Position', [536, 10, 124, 30], ...
            'ButtonPushedFcn', @(btn, event) saveConfig(editFig, tags, 'H2_Crossover'));

        uilabel(editFig, "Text", 'X-Label des Plots:', 'Position', [20 310 640 22]);
        uitextarea(editFig, 'Position', [130 312 330 20], 'Value', config.xlabel, ...
            'Tag', 'config.xlabel');
        
        uilabel(editFig, "Text", 'Größe der x-Ticks:', 'Position', [480 310 310 22]);
        uispinner(editFig, 'Position', [590 312 70 20], 'Value', config.xTickSize, 'Tag', 'config.xTickSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Y-Label des Plots:', 'Position', [20 285 640 22]);
        uitextarea(editFig, 'Position', [130 287 330 20], 'Value', config.ylabel, ...
            'Tag', 'config.ylabel');
        
        uilabel(editFig, "Text", 'Größe der y-Ticks:', 'Position', [480 285 310 22]);
        uispinner(editFig, 'Position', [590 287 70 20], 'Value', config.yTickSize, 'Tag', 'config.yTickSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, 'Position', [20 260 150 22], 'Text', 'Schriftgröße der Legende:');
        uispinner(editFig, 'Position', [180 262 70 20], 'Value', config.legendFontSize,'Tag', 'config.legendFontSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, 'Position', [290 260 150 22], 'Text', 'des Stromlabels:');
        uispinner(editFig, 'Position', [390 262 70 20], 'Value', config.IH2_CrossoverSize, 'Tag', 'config.IH2_CrossoverSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, 'Position', [500 260 150 22], 'Text', 'der Fit-Labels:');
        uispinner(editFig, 'Position', [590 262 70 20], 'Value', config.fitTextSize, 'Tag', 'config.fitTextSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Titel Zeile 1:', 'Position', [20 245 640 15]);
        uitextarea(editFig, 'Position', [20 220 640 22], 'Value', config.Titel1, ...
            'Tag', 'config.Titel1');
        
        uilabel(editFig, "Text", 'Titel Zeile 2:', 'Position', [20 195 640 22]);
        uitextarea(editFig, 'Position', [20 160 640 38], 'Value', config.Titel2, ...
            'Tag', 'config.Titel2');
        
        uilabel(editFig, 'Position', [20 60 250 22], 'Text', 'Nachkommastellen für I-Ausgabe:');
        uispinner(editFig, 'Position', [260 62 70 20], 'Value', config.Nachkommastellen_I, 'Tag', 'config.Nachkommastellen_I', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on');
        
        uilabel(editFig, 'Position', [20 35 250 22], 'Text', 'Nachkommastellen für Fit-Ausgabe:');
        uispinner(editFig, 'Position', [260 37 70 20], 'Value', config.Nachkommastellen_y, 'Tag', 'config.Nachkommastellen_y', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on');
    
        uilabel(editFig, "Text", 'Linienbreite für die Plotlinien:', 'Position', [20 10 200 22]);
        uispinner(editFig, 'Position', [260 12 70 20], 'Value', config.lineWidth, 'Tag', 'config.lineWidth', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, 'Position', [350 60 200 22], 'Text', 'Active Area:');
        uispinner(editFig, 'Position', [452 62 70 20], 'Value', config.Flaeche, 'Tag', 'config.Flaeche', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'ValueDisplayFormat', '%11.5g', 'LowerLimitInclusive', 'off', ...
            'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'x-Achsenlimits Gesamtplot:', 'Position', [20 135 150 22]);
        uispinner(editFig, 'Position', [168 137 70 20], 'Value', config.xAchsenLimitsGesamt(1), 'Tag', 'config.xAchsenLimitsGesamt(1)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'bis', 'Position', [241 135 25 22]);
        uispinner(editFig, 'Position', [260 137 70 20], 'Value', config.xAchsenLimitsGesamt(2), 'Tag', 'config.xAchsenLimitsGesamt(2)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'y-Achsenlimits Gesamtplot:', 'Position', [350 135 150 22]);
        uispinner(editFig, 'Position', [498 137 70 20], 'Value', config.yAchsenLimitsGesamt(1), 'Tag', 'config.yAchsenLimitsGesamt(1)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'bis', 'Position', [573 135 25 22]);
        uispinner(editFig, 'Position', [590 137 70 20], 'Value', config.yAchsenLimitsGesamt(2), 'Tag', 'config.yAchsenLimitsGesamt(2)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'x-Achsenlimits Fit:', 'Position', [20 110 150 22]);
        uilabel(editFig, "Text", 'von', 'Position', [143 110 25 22]);
        uispinner(editFig, 'Position', [168 112 70 20], 'Value', config.xAchsenLimitsFit(1), 'Tag', 'config.xAchsenLimitsFit(1)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'bis', 'Position', [241 110 25 22]);
        uispinner(editFig, 'Position', [260 112 70 20], 'Value', config.xAchsenLimitsFit(2), 'Tag', 'config.xAchsenLimitsFit(2)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'y-Achsenlimits Fit:', 'Position', [350 110 150 22]);
        uilabel(editFig, "Text", 'von', 'Position', [473 110 25 22]);
        uispinner(editFig, 'Position', [498 112 70 20], 'Value', config.yAchsenLimitsFit(1), 'Tag', 'config.yAchsenLimitsFit(1)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'bis', 'Position', [573 110 25 22]);
        uispinner(editFig, 'Position', [590 112 70 20], 'Value', config.yAchsenLimitsFit(2), 'Tag', 'config.yAchsenLimitsFit(2)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Integrationsbereich [V]:', 'Position', [20 85 200 22]);
        uispinner(editFig, 'Position', [168 87 70 20], 'Value', config.UMin, 'Tag', 'config.UMin', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001);
        
        uilabel(editFig, "Text", 'bis', 'Position', [241 85 25 22]);
        uispinner(editFig, 'Position', [260 87 70 20], 'Value', config.UMax, 'Tag', 'config.UMax', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001);
        
        uilabel(editFig, "Text", 'Spalten in der txt-Datei:', 'Position', [350 85 150 22]);
        uilabel(editFig, "Text", 'U:', 'Position', [483 85 25 22]);
        uispinner(editFig, 'Position', [498 87 70 20], 'Value', config.Spalten(1), 'Tag', 'config.Spalten(1)', ...
            "Limits", [1, inf], 'RoundFractionalValues', 'on', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'I:', 'Position', [578 85 25 22]);
        uispinner(editFig, 'Position', [590 87 70 20], 'Value', config.Spalten(2), 'Tag', 'config.Spalten(2)', ...
            "Limits", [1, inf], 'RoundFractionalValues', 'on', 'UpperLimitInclusive', 'off');

    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler in der config')
        disp(ME.message)
    end
end

function pk()
    try
        config = evalin("base", 'config').PK;
    
        tags = {'config.checkExport', 'config.MWAbSekundenVor', 'config.MesswerteProSekunde', 'config.lineWidth', 'config.Titel1', ...
            'config.Titel2_PK1', 'config.Titel2_PK2',  'config.Titel2_PK3', 'config.checkRef', 'config.checkDUT', 'config.xAchsenLimits(1)', ...
            'config.xAchsenLimits(2)', 'config.yAchsenLimits(1)', 'config.yAchsenLimits(2)', 'config.checkWerteInPlot', 'config.xlabel', ...
            'config.ylabel', 'config.legendFontSize', 'config.xTickSize', 'config.yTickSize', 'config.LabelFontSize', 'config.StromSetIndex', ...
            'config.SpannungsIndex', 'config.StromdichteIndex', 'config.TempIndex', 'config.tempPK1', 'config.tempPK2', 'config.tempPK3'};
    
        editFig = uifigure('Name', 'PK Einstellungen', 'Position', [300, 37.5, 680, 735]);

        uilabel(editFig, 'text', 'Indize der nötigen Parameter (Zahl links):', 'Position', [110 706 310 22]);

        uilabel(editFig, "Text", 'Strom Set:', 'Position', [345 706 640 22]);
        uispinner(editFig, 'Position', [430 708 70 20], 'Value', config.StromSetIndex, 'Tag', 'config.StromSetIndex', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');

        uilabel(editFig, "Text", 'Stromdichte:', 'Position', [515 706 640 22]);
        uispinner(editFig, 'Position', [590 708 70 20], 'Value', config.StromdichteIndex, 'Tag', 'config.StromdichteIndex', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');

        uilabel(editFig, "Text", 'Coolant in Set:', 'Position', [345 681 640 22]);
        uispinner(editFig, 'Position', [430 683 70 20], 'Value', config.TempIndex, 'Tag', 'config.TempIndex', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');

        uilabel(editFig, "Text", 'Spannung:', 'Position', [515 681 640 22]);
        uispinner(editFig, 'Position', [590 683 70 20], 'Value', config.SpannungsIndex, 'Tag', 'config.SpannungsIndex', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
    
        % Creating the column table
        headerColumn = config.Header(:);
        spaltenColumn = num2cell(config.Spalten(:)); % Convert to cell array for mixed data types
        data = [headerColumn, spaltenColumn];
        
        uilabel(editFig, 'text', 'Ausgewertete Parameter der CSV-Datei:', 'Position', [20 681 310 15]);
        columnNames = {'Header', 'Spalten'};
        ct = uitable(editFig, 'Data', data, 'ColumnName', columnNames, ...
            'ColumnEditable', [true, true], 'CellEditCallback', @validateTable, ...
            'Position', [20, 480, 640, 200], 'ColumnWidth', {'40x', '12x'}, ...
            'FontSize', 11, 'ColumnFormat', {'char', 'numeric'});
    
        % Button to add a new row
        uibutton(editFig, 'Text', 'Neue Zeile hinzufügen', 'Position', [20, 449, 310, 30], ...
            'ButtonPushedFcn', @(btn, event) addRow(ct));
    
        % Button to remove selected row
        uibutton(editFig, 'Text', 'Zeile entfernen', 'Position', [350, 449, 310, 30], ...
            'ButtonPushedFcn', @(btn, event) removeRow(ct));
    
        % 'Öffnen' Button
        uibutton(editFig, 'Text', 'config.json öffnen', 'Position', [536, 45, 124, 30], ...
            'ButtonPushedFcn', @(btn, event) editConfigJson(editFig));
    
        % 'Speichern' Button
        uibutton(editFig, 'Text', 'Speichern', 'Position', [536, 10, 124, 30], ...
            'ButtonPushedFcn', @(btn, event) savePK(editFig, ct, tags));
        
        uilabel(editFig, "Text", 'X-Label des Plots:', 'Position', [20 419 640 22]);
        uitextarea(editFig, 'Position', [130 419 330 22], 'Value', config.xlabel, ...
            'Tag', 'config.xlabel');
        
        uilabel(editFig, "Text", 'Größe der x-Ticks:', 'Position', [480 419 310 22]);
        uispinner(editFig, 'Position', [590 421 70 20], 'Value', config.xTickSize, 'Tag', 'config.xTickSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Y-Label des Plots:', 'Position', [20 394 640 22]);
        uitextarea(editFig, 'Position', [130 394 330 22], 'Value', config.ylabel, ...
            'Tag', 'config.ylabel');
        
        uilabel(editFig, "Text", 'Größe der y-Ticks:', 'Position', [480 394 310 22]);
        uispinner(editFig, 'Position', [590 396 70 20], 'Value', config.yTickSize, 'Tag', 'config.yTickSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Schriftgröße der Legende:', 'Position', [20 369 310 22]);
        uispinner(editFig, 'Position', [260 371 70 20], 'Value', config.legendFontSize, 'Tag', 'config.legendFontSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Schriftgröße der Werte im Plot:', 'Position', [350 369 640 22]);
        uispinner(editFig, 'Position', [590 371 70 20], 'Value', config.LabelFontSize, 'Tag', 'config.LabelFontSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
    
        uilabel(editFig, "Text", 'Titel Zeile 1:', 'Position', [20 349 640 15]);
        uitextarea(editFig, 'Position', [20 324 640 22], 'Value', config.Titel1, ...
            'Tag', 'config.Titel1');
        
        uilabel(editFig, "Text", 'PK 1 Titel Zeile 2:', 'Position', [20 299 640 22]);
        uitextarea(editFig, 'Position', [20 264 640 37], 'Value', config.Titel2_PK1, ...
            'Tag', 'config.Titel2_PK1');

        uilabel(editFig, "Text", 'Temperatur bei PK 1:', 'Position', [470 300.5 640 22]);
        uispinner(editFig, 'Position', [590 302.5 70 20], 'Value', config.tempPK1, 'Tag', 'config.tempPK1', 'Step', 0.1, ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');
    
        uilabel(editFig, "Text", 'PK 2 Titel Zeile 2:', 'Position', [20 236 640 22]);
        uitextarea(editFig, 'Position', [20 201 640 37], 'Value', config.Titel2_PK2, ...
             'Tag', 'config.Titel2_PK2');

        uilabel(editFig, "Text", 'Temperatur bei PK 2:', 'Position', [470 237.5 640 22]);
        uispinner(editFig, 'Position', [590 239.5 70 20], 'Value', config.tempPK2, 'Tag', 'config.tempPK2', 'Step', 0.1, ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');
    
        uilabel(editFig, "Text", 'PK 3 Titel Zeile 2:', 'Position', [20 173 640 22]);
        uitextarea(editFig, 'Position', [20 138 640 37], 'Value', config.Titel2_PK3, ...
             'Tag', 'config.Titel2_PK3');

        uilabel(editFig, "Text", 'Temperatur bei PK 3:', 'Position', [470 174.5 640 22]);
        uispinner(editFig, 'Position', [590 176.5 70 20], 'Value', config.tempPK3, 'Tag', 'config.tempPK3', 'Step', 0.1, ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');
    
        uilabel(editFig, "Text", 'Durchschnitt für ... Sekunden vor Stromabfall:', 'Position', [20 85 640 22]);
        uispinner(editFig, 'Position', [292 87 70 20], 'Value', config.MWAbSekundenVor, 'Tag', 'config.MWAbSekundenVor', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off');
    
        uilabel(editFig, "Text", 'Messwerte pro Sekunde:', 'Position', [20 110 640 22]);
        uispinner(editFig, 'Position', [292 112 70 20], 'Value', config.MesswerteProSekunde, 'Tag', 'config.MesswerteProSekunde', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off');
    
        uilabel(editFig, "Text", 'Linienbreite für die Plotlinien:', 'Position', [370 110 250 22]);
        uispinner(editFig, 'Position', [590 112 70 20], 'Value', config.lineWidth, 'Tag', 'config.lineWidth', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
    
        assignin("base", 'Zeilen', config.Zeilen)
        lineTags = {'config.Zeilen{1}', 'config.Zeilen{2}'};
        uilabel(editFig, "Text", 'Relevante Zeilen der CSV:', 'Position', [20 10 200 22]);
        uilabel(editFig, "Text", 'von', 'Position', [170 10 25 22]);
        try
            uispinner(editFig, 'Position', [195 12 70 20], 'Value', config.Zeilen{1}, 'Tag', 'config.Zeilen{1}', ...
                "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
            
            uilabel(editFig, "Text", 'bis', 'Position', [270 10 25 22]);
            uispinner(editFig, 'Position', [292 12 70 20], 'Value', str2double(config.Zeilen{2}), 'Tag', 'config.Zeilen{2}', ...
                "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
        catch
            uispinner(editFig, 'Position', [195 12 70 20], 'Value', config.Zeilen(1), 'Tag', 'config.Zeilen{1}', ...
                "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
            
            uilabel(editFig, "Text", 'bis', 'Position', [270 10 25 22]);
            uispinner(editFig, 'Position', [292 12 70 20], 'Value', config.Zeilen(2), 'Tag', 'config.Zeilen{2}', ...
                "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
        end
        
        uilabel(editFig, "Text", 'x-Achsenlimits:', 'Position', [20 60 90 22]);
        uilabel(editFig, "Text", 'von', 'Position', [170 60 25 22]);
        uispinner(editFig, 'Position', [195 62 70 20], 'Value', config.xAchsenLimits(1), 'Tag', 'config.xAchsenLimits(1)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'bis', 'Position', [270 60 25 22]);
        uispinner(editFig, 'Position', [292 62 70 20], 'Value', config.xAchsenLimits(2), 'Tag', 'config.xAchsenLimits(2)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'y-Achsenlimits:', 'Position', [20 35 90 22]);
        uilabel(editFig, "Text", 'von', 'Position', [170 35 25 22]);
        uispinner(editFig, 'Position', [195 37 70 20], 'Value', config.yAchsenLimits(1), 'Tag', 'config.yAchsenLimits(1)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'bis', 'Position', [270 35 25 22]);
        uispinner(editFig, 'Position', [292 37 70 20], 'Value', config.yAchsenLimits(2), 'Tag', 'config.yAchsenLimits(2)', ...
            "Limits", [-inf, inf], 'RoundFractionalValues', 'off', 'Step', 0.001, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uicheckbox(editFig, "Text", 'Daten in Excel exportieren', 'Position', [370 85 160 22], 'Value', config.checkExport, ...
            'Tag', 'config.checkExport');
        
        uicheckbox(editFig, "Text", 'Referenzdaten anzeigen', 'Position', [370 60 160 22], 'Value', config.checkRef, ...
            'Tag', 'config.checkRef');
        
        uicheckbox(editFig, "Text", 'DUT anzeigen', 'Position', [370 35 160 22], 'Value', config.checkDUT, ...
            'Tag', 'config.checkDUT');
        
        uicheckbox(editFig, "Text", 'Werte in Plot anzeigen', 'Position', [370 10 160 22], 'Value', config.checkWerteInPlot, ...
            'Tag', 'config.checkWerteInPlot');
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler in der config')
        disp(ME.message)
    end
end

function savePK(editFig, columnTableHandle, tags)
    try
        % Get the data from the tables
        columnData = columnTableHandle.Data;
        assignin("base", "columnTableData", columnData)
    
        % Call the existing saveConfig function
        saveConfig(editFig, tags, 'PK');
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler beim speichern der PK-config')
        disp(ME.message)
    end
end

function load__points()
    try
        config = evalin("base", 'config').Load__Points;
    
        tags = {'config.checkExport', 'config.MWAbSekundenVor', 'config.MesswerteProSekunde', 'config.lineWidth', 'config.NachkommastellenStrom', ...
            'config.NachkommastellenSpannung', 'config.Titel', 'config.xlabel', 'config.ylabelSize', 'config.legendFontSize', 'config.xTickSize', ...
            'config.yTickSize', 'config.ZeitIndex', 'config.SpannungsIndex', 'config.StromIndex'};
    
        editFig = uifigure('Name', 'Load Points Einstellungen', 'Position', [300, 164.5, 680, 476]);

        uilabel(editFig, 'text', 'Indize der nötigen Parameter (Zahl links):', 'Position', [20 441 310 22]);

        uilabel(editFig, "Text", 'Zeit:', 'Position', [255 441 640 22]);
        uispinner(editFig, 'Position', [280 443 70 20], 'Value', config.ZeitIndex, 'Tag', 'config.ZeitIndex', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');

        uilabel(editFig, "Text", 'Parameter 1:', 'Position', [360 441 640 22]);
        uispinner(editFig, 'Position', [432 443 70 20], 'Value', config.StromIndex, 'Tag', 'config.StromIndex', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');

        uilabel(editFig, "Text", 'Parameter 2:', 'Position', [515 441 640 22]);
        uispinner(editFig, 'Position', [590 443 70 20], 'Value', config.SpannungsIndex, 'Tag', 'config.SpannungsIndex', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
    
        % Creating the trigger table
        triggerNames = config.TriggerNames(:);
        trigger = num2cell(config.Trigger(:)); % Convert to cell array for mixed data types
        data = [triggerNames, trigger];
    
        uilabel(editFig, 'text', 'Gesuchte Trigger in der CSV-Datei:', 'Position', [20 426 310 15]);
        columnNames = {'Namen', 'Trigger'};
        tt = uitable(editFig, 'Data', data, 'ColumnName', columnNames, ...
            'ColumnEditable', [true, true], 'CellEditCallback', @validateTable, ...
            'Position', [20, 225, 220, 200], 'ColumnWidth', {'40x', '20x'}, ...
            'FontSize', 11, 'ColumnFormat', {'char', 'numeric'});
    
        % Button to add a new row
        uibutton(editFig, 'Text', 'Neue Zeile', 'Position', [20, 190, 105, 30], ...
            'ButtonPushedFcn', @(btn, event) addRow(tt));
    
        % Button to remove selected row
        uibutton(editFig, 'Text', 'Zeile entfernen', 'Position', [135, 190, 105, 30], ...
            'ButtonPushedFcn', @(btn, event) removeRow(tt));
    
        % Creating the column table
        headerColumn = config.Header(:);
        spaltenColumn = num2cell(config.Spalten(:)); % Convert to cell array for mixed data types
        colorColumn = config.Colors(:);
        limitColumn = config.Limits(:);
        data = [headerColumn, spaltenColumn, colorColumn, limitColumn];
        
        uilabel(editFig, 'text', 'Ausgewertete Parameter der CSV-Datei:', 'Position', [260 426 310 15]);
        columnNames = {'Header', 'Spalten', 'Hex-Farben ', 'Achsenlimits'};
        ct = uitable(editFig, 'Data', data, 'ColumnName', columnNames, ...
            'ColumnEditable', [true, true, true, true], 'CellEditCallback', @validateTable, ...
            'Position', [260, 225, 400, 200], 'ColumnWidth', {'22x', '12x', '17x', '19x'}, ...
            'FontSize', 11, 'ColumnFormat', {'char', 'numeric', 'char', 'char'});
    
        % Button to add a new row
        uibutton(editFig, 'Text', 'Neue Zeile hinzufügen', 'Position', [260, 190, 195, 30], ...
            'ButtonPushedFcn', @(btn, event) addRow(ct));
    
        % Button to remove selected row
        uibutton(editFig, 'Text', 'Zeile entfernen', 'Position', [465, 190, 195, 30], ...
            'ButtonPushedFcn', @(btn, event) removeRow(ct));
    
        % 'Öffnen' Button
        uibutton(editFig, 'Text', 'config.json öffnen', 'Position', [536, 45, 124, 30], ...
            'ButtonPushedFcn', @(btn, event) editConfigJson(editFig));
    
        % 'Speichern' Button
        uibutton(editFig, 'Text', 'Speichern', 'Position', [536, 10, 124, 30], ...
            'ButtonPushedFcn', @(btn, event) saveLoad__Points(editFig, ct, tt, tags));
        
        uilabel(editFig, "Text", 'Titel des Plots:', 'Position', [20 160 250 22]);
        uitextarea(editFig, 'Position', [190 160 470 22], 'Value', config.Titel, ...
            'Tag', 'config.Titel');
        
        uilabel(editFig, "Text", 'X-Label des Plots:', 'Position', [20 135 250 22]);
        uitextarea(editFig, 'Position', [190 135 470 22], 'Value', config.xlabel, ...
            'Tag', 'config.xlabel');

        uilabel(editFig, "Text", 'Größe der Y-Labels:', 'Position', [20 110 640 22]);
        uispinner(editFig, 'Position', [190 112 70 20], 'Value', config.ylabelSize, 'Tag', 'config.ylabelSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');

        uilabel(editFig, "Text", 'Größe der x-Ticks:', 'Position', [275 110 640 22]);
        uispinner(editFig, 'Position', [392.5 112 70 20], 'Value', config.xTickSize, 'Tag', 'config.xTickSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');

        uilabel(editFig, "Text", 'Größe der y-Ticks:', 'Position', [472.5 110 640 22]);
        uispinner(editFig, 'Position', [590 112 70 20], 'Value', config.yTickSize, 'Tag', 'config.yTickSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');

        uilabel(editFig, "Text", 'Schriftgröße der Legende:', 'Position', [20 85 640 22]);
        uispinner(editFig, 'Position', [190 87 70 20], 'Value', config.legendFontSize, 'Tag', 'config.legendFontSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
    
        uilabel(editFig, "Text", 'Sekunden vor Triggerende die ausgewertet werden sollen:', 'Position', [275 85 640 22]);
        uispinner(editFig, 'Position', [590 87 70 20], 'Value', config.MWAbSekundenVor, 'Tag', 'config.MWAbSekundenVor', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');

        uilabel(editFig, "Text", 'Messwerte pro Sekunde:', 'Position', [20 60 200 22]);
        uispinner(editFig, 'Position', [190 62 70 20], 'Value', config.MesswerteProSekunde, 'Tag', 'config.MesswerteProSekunde', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');

        uilabel(editFig, "Text", 'Linienbreite für die Plotlinien:', 'Position', [275 60 200 22]);
        uispinner(editFig, 'Position', [460 62 70 20], 'Value', config.lineWidth, 'Tag', 'config.lineWidth', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
    
        uilabel(editFig, 'Position', [20 35 250 22], 'Text', 'Nachkommastellen für I:');
        uispinner(editFig, 'Position', [190 37 70 20], 'Value', config.NachkommastellenStrom, 'Tag', 'config.NachkommastellenStrom', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on');
    
        uilabel(editFig, 'Position', [275 35 250 22], 'Text', 'Nachkommastellen für U:');
        uispinner(editFig, 'Position', [460 37 70 20], 'Value', config.NachkommastellenSpannung, 'Tag', 'config.NachkommastellenSpannung', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'on');
    
        assignin("base", 'Zeilen', config.Zeilen)
        lineTags = {'config.Zeilen{1}', 'config.Zeilen{2}'};
        uilabel(editFig, "Text", 'Relevante Zeilen der CSV:', 'Position', [20 10 200 22]);
        uilabel(editFig, "Text", 'von', 'Position', [167 10 25 22]);
        uilabel(editFig, "Text", 'bis', 'Position', [267 10 25 22]);
        try
            uispinner(editFig, 'Position', [190 12 70 20], 'Value', config.Zeilen{1}, 'Tag', 'config.Zeilen{1}', ...
                "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
            try
                uispinner(editFig, 'Position', [290 12 70 20], 'Value', str2double(config.Zeilen{2}), 'Tag', 'config.Zeilen{2}', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
            catch
                uispinner(editFig, 'Position', [290 12 70 20], 'Value', config.Zeilen{2}, 'Tag', 'config.Zeilen{2}', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
            end
        catch
            uispinner(editFig, 'Position', [190 12 70 20], 'Value', config.Zeilen(1), 'Tag', 'config.Zeilen{1}', ...
                "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
            try
                uispinner(editFig, 'Position', [290 12 70 20], 'Value', str2double(config.Zeilen(2)), 'Tag', 'config.Zeilen{2}', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
            catch
                uispinner(editFig, 'Position', [290 12 70 20], 'Value', config.Zeilen(2), 'Tag', 'config.Zeilen{2}', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
            end
        end
    
        uicheckbox(editFig, "Text", 'Daten in Excel exportieren', 'Position', [370 10 160 22], 'Value', config.checkExport, ...
            'Tag', 'config.checkExport');
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler in der config')
        disp(ME.message)
    end
end

function addRow(tableHandle)
    try
        num = length(tableHandle.ColumnEditable);
        newRow = repmat({}, 1, num);
        for i=1:num
            switch tableHandle.ColumnFormat{i}
                case 'numeric'
                newRow(i) = {0};
                case 'char'
                newRow(i) = {' '};
                case 'logical'
                newRow(i) = {0};
            end
        end
        try %#ok<TRYNC> 
            newRow = cell2mat(newRow);
        end
        tableHandle.Data(end+1,:) = newRow;
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler beim hinzufügen einer Zeile')
        disp(ME.message)
    end
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

function validateTable(src, ~)
    try
        % Validate the table data and highlight duplicates or empty fields
        data = src.Data;
        % Definiere die Anzahl der Spalten
        numCols = length(src.ColumnEditable);
        
        % Initialisiere eine leere Zell-Array für die Daten
        columns = cell(1, numCols);
        
        % Weise die Daten den entsprechenden Spalten zu
        for i = 1:numCols
            columns{i} = data(:, i);
        end
        
        % Check for empty fields in all specified columns
        emptyFields = any(cellfun(@isempty, horzcat(columns{:})), 2);
        
        % Check for duplicates
        headers = columns{1};
        [~, uniqueIdx] = unique(headers);
        duplicateIdx = setdiff(1:numel(headers), uniqueIdx);
        
        % Mark duplicates and empty fields
        for i = 1:size(data, 1)
            if emptyFields(i)
                src.BackgroundColor(i, :) = [1, 0, 0]; % Red for empty fields
            elseif ismember(i, duplicateIdx)
                src.BackgroundColor(i, :) = [1, 1, 0]; % Yellow for duplicates
            else
                src.BackgroundColor(i, :) = [1, 1, 1]; % Default white
            end
        end
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler beim Vaidieren der Tabelle')
        disp(ME.message)
    end
end

function saveLoad__Points(editFig, columnTableHandle, triggerTableHandle, tags)
    try
        % Get the data from the tables
        columnData = columnTableHandle.Data;
        assignin("base", "columnTableData", columnData)
        triggerData = triggerTableHandle.Data;
        assignin("base", "triggerTableData", triggerData)
    
        % Call the existing saveConfig function
        saveConfig(editFig, tags, 'Load__Points');
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler beim Speichern der Load__Points-config')
        disp(ME.message)
    end
end

function eis()
    try
        config = evalin("base", 'config').EIS;
    
        tags = {'config.lineWidth', 'config.Flaeche', 'config.sigmaAnzeigen', 'config.Titel', 'config.SplatenInPlotlegende', 'config.legendFontSize', ...
            'config.nyquistXlabel', 'config.nyquistYlabel', 'config.bodeXlabel', 'config.bodeYlabelLeft', 'config.bodeYlabelRight', 'config.xTickSize', 'config.yTickSize'};
    
        editFig = uifigure('Name', 'EIS Einstellungen', 'Position', [300, 295, 680, 250]);
    
        uibutton(editFig, 'Text', 'config.json öffnen', 'Position', [536, 49, 124, 34], ...
            'ButtonPushedFcn', @(btn, event) editConfigJson(editFig));
        
        uibutton(editFig, 'Text', 'Speichern', 'Position', [536, 10, 124, 34], ...
            'ButtonPushedFcn', @(btn, event) saveConfig(editFig, tags, 'EIS'));
        
        uilabel(editFig, "Text", 'X-Label des Nyquist-Plots:', 'Position', [20 212 640 22]);
        uitextarea(editFig, 'Position', [220 212 440 22], 'Value', config.nyquistXlabel, ...
            'Tag', 'config.nyquistXlabel');
        
        uilabel(editFig, "Text", 'Y-Label des Nyquist-Plots:', 'Position', [20 187 640 22]);
        uitextarea(editFig, 'Position', [220 187 440 22], 'Value', config.nyquistYlabel, ...
            'Tag', 'config.nyquistYlabel');
        
        uilabel(editFig, "Text", 'X-Label des Bode-Plots:', 'Position', [20 162 640 22]);
        uitextarea(editFig, 'Position', [220 162 440 22], 'Value', config.bodeXlabel, ...
            'Tag', 'config.bodeXlabel');
        
        uilabel(editFig, "Text", 'Linkes Y-Label des Bode-Plots:', 'Position', [20 137 640 22]);
        uitextarea(editFig, 'Position', [220 137 440 22], 'Value', config.bodeYlabelLeft, ...
            'Tag', 'config.bodeYlabelLeft');
        
        uilabel(editFig, "Text", 'Rechtes Y-Label des Bode-Plots:', 'Position', [20 112 640 22]);
        uitextarea(editFig, 'Position', [220 112 440 22], 'Value', config.bodeYlabelRight, ...
            'Tag', 'config.bodeYlabelRight');
        
        uicheckbox(editFig, "Text", 'sigma anzeigen', 'Position', [20 87 105 22], 'Value', config.sigmaAnzeigen, ...
            'Tag', 'config.sigmaAnzeigen');
        
        uilabel(editFig, "Text", 'Titel:', 'Position', [170 87 250 22]);
        uitextarea(editFig, 'Position', [220 87 440 22], 'Value', config.Titel, ...
            'Tag', 'config.Titel');
        
        uilabel(editFig, 'Position', [310 60 200 22], 'Text', 'Schriftgröße der Legende:');
        uispinner(editFig, 'Position', [460 62 70 20], 'Value', config.legendFontSize, 'Tag', 'config.legendFontSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'Step', 0.5, 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
    
        uilabel(editFig, "Text", 'Spalten in Plotlegende:', 'Position', [20 60 200 22]);
        uispinner(editFig, 'Position', [220 62 70 20], 'Value', config.SplatenInPlotlegende, 'Tag', 'config.SplatenInPlotlegende', ...
            "Limits", [1, inf], 'RoundFractionalValues', 'on');
    
        uilabel(editFig, "Text", 'Linienbreite für die Plotlinien:', 'Position', [20 35 200 22]);
        uispinner(editFig, 'Position', [220 37 70 20], 'Value', config.lineWidth, 'Tag', 'config.lineWidth', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Größe der x-Ticks:', 'Position', [310 35 200 22]);
        uispinner(editFig, 'Position', [460 37 70 20], 'Value', config.xTickSize, 'Tag', 'config.xTickSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, 'Position', [20 10 200 22], 'Text', 'Active Area:');
        uispinner(editFig, 'Position', [220 12 70 20], 'Value', config.Flaeche, 'Tag', 'config.Flaeche', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'ValueDisplayFormat', '%11.7g', 'LowerLimitInclusive', 'off', ...
            'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Größe der y-Ticks:', 'Position', [310 10 200 22]);
        uispinner(editFig, 'Position', [460 12 70 20], 'Value', config.yTickSize, 'Tag', 'config.yTickSize', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler in der config')
        disp(ME.message)
    end
end

function s_plus__plus_()
    try
        config = evalin("base", 'config').S_plus__plus_;
        
        tags = {'config.deviationBalancedArea', 'config.cdLinesToDelete', 'config.cdRowsToDelete', 'config.tdLinesToDelete', 'config.showPlotWindow', ...
            'config.tdRowsToDelete', 'config.segmentArea', 'config.framerate', 'config.frequency', 'config.singleFrame', 'config.cdGridCheck', ...
            'config.tdGridCheck', 'config.cdColorCheck', 'config.tdColorCheck', 'config.Spalten(1)', 'config.Spalten(2)', 'config.Spalten(3)', ...
            'config.Spalten(4)', 'config.Spalten(5)', 'config.Spalten(6)', 'config.Spalten(7)', 'config.Spalten(8)', 'config.Spalten(9)', 'config.Spalten(10)', ...
            'config.Spalten(11)', 'config.Spalten(12)', 'config.Spalten(13)',  'config.Spalten(14)', 'config.Spalten(15)', 'config.Spalten(16)', 'config.Spalten(17)', ...
            'config.Spalten(18)', 'config.anodeIn', 'config.anodeOut', 'config.cathodeIn', 'config.cathodeOut', 'config.Farbe_I', 'config.Farbe_U'};
        
        editFig = uifigure('Name', 'S++ Einstellungen', 'Position', [300, 230, 680, 395]);

        uibutton(editFig, 'Text', 'config.json öffnen', 'Position', [536, 49, 124, 34], ...
            'ButtonPushedFcn', @(btn, event) editConfigJson(editFig));
        
        uibutton(editFig, 'Text', 'Speichern', 'Position', [536, 10, 124, 34], ...
            'ButtonPushedFcn', @(btn, event) saveConfig(editFig, tags, 'S_plus__plus_'));
        
        uitextarea(editFig, 'Position', [18 264 643 126], 'BackgroundColor', editFig.Color);
        uilabel(editFig, "Text", 'Spalten der CSV-Dateien:', 'Position', [20 365 200 22]);
        uilabel(editFig, "Text", 'Timestamps:', 'Position', [350-10/3 365 92+20/3 22]);
        uispinner(editFig, 'Position', [442+10/3 367 53 20], 'Value', config.Spalten(1), 'Tag', 'config.Spalten(1)', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');
        uilabel(editFig, "Text", 'Current Density:', 'Position', [515-20/3 365 92+20/3 22]);
        uispinner(editFig, 'Position', [607 367 53 20], 'Value', config.Spalten(2), 'Tag', 'config.Spalten(2)', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Voltage:', 'Position', [20 340 92+20/3 22]);
        uispinner(editFig, 'Position', [112+20/3 342 53 20], 'Value', config.Spalten(3), 'Tag', 'config.Spalten(3)', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');
        uilabel(editFig, "Text", 'stoic A:', 'Position', [185-10/3 340 92+20/3 22]);
        uispinner(editFig, 'Position', [277+10/3 342 53 20], 'Value', config.Spalten(4), 'Tag', 'config.Spalten(4)', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');
        uilabel(editFig, "Text", 'stoic C:', 'Position', [350-10/3 340 92+20/3 22]);
        uispinner(editFig, 'Position', [442+10/3 342 53 20], 'Value', config.Spalten(5), 'Tag', 'config.Spalten(5)', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');
        uilabel(editFig, "Text", 'mflow An:', 'Position', [515-20/3 340 92+20/3 22]);
        uispinner(editFig, 'Position', [607 342 53 20], 'Value', config.Spalten(6), 'Tag', 'config.Spalten(6)', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');

        uilabel(editFig, "Text", 'mflow Ca:', 'Position', [20 315 92+20/3 22]);
        uispinner(editFig, 'Position', [112+20/3 317 53 20], 'Value', config.Spalten(7), 'Tag', 'config.Spalten(7)', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');
        uilabel(editFig, "Text", 'Coolant Temp in:', 'Position', [185-10/3 315 92+20/3 22]);
        uispinner(editFig, 'Position', [277+10/3 317 53 20], 'Value', config.Spalten(8), 'Tag', 'config.Spalten(8)', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');
        uilabel(editFig, "Text", 'Coolant Temp out:', 'Position', [350-10/3 315 92+20/3 22]);
        uispinner(editFig, 'Position', [442+10/3 317 53 20], 'Value', config.Spalten(9), 'Tag', 'config.Spalten(9)', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');
        uilabel(editFig, "Text", 'DP A:', 'Position', [515-20/3 315 92+20/3 22]);
        uispinner(editFig, 'Position', [607 317 53 20], 'Value', config.Spalten(10), 'Tag', 'config.Spalten(10)', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');

        uilabel(editFig, "Text", 'DP C:', 'Position', [20 290 92+20/3 22]);
        uispinner(editFig, 'Position', [112+20/3 292 53 20], 'Value', config.Spalten(11), 'Tag', 'config.Spalten(11)', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');
        uilabel(editFig, "Text", 'P An In:', 'Position', [185-10/3 290 92+20/3 22]);
        uispinner(editFig, 'Position', [277+10/3 292 53 20], 'Value', config.Spalten(12), 'Tag', 'config.Spalten(12)', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');
        uilabel(editFig, "Text", 'P An Out:', 'Position', [350-10/3 290 92+20/3 22]);
        uispinner(editFig, 'Position', [442+10/3 292 53 20], 'Value', config.Spalten(13), 'Tag', 'config.Spalten(13)', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');
        uilabel(editFig, "Text", 'P Cath In:', 'Position', [515-20/3 290 92+20/3 22]);
        uispinner(editFig, 'Position', [607 292 53 20], 'Value', config.Spalten(14), 'Tag', 'config.Spalten(14)', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');

        uilabel(editFig, "Text", 'P Cath Out:', 'Position', [20 265 92+20/3 22]);
        uispinner(editFig, 'Position', [112+20/3 267 53 20], 'Value', config.Spalten(15), 'Tag', 'config.Spalten(15)', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');
        uilabel(editFig, "Text", 'Temp An:', 'Position', [185-10/3 265 92+20/3 22]);
        uispinner(editFig, 'Position', [277+10/3 267 53 20], 'Value', config.Spalten(16), 'Tag', 'config.Spalten(16)', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');
        uilabel(editFig, "Text", 'Temp Ca:', 'Position', [350-10/3 265 92+20/3 22]);
        uispinner(editFig, 'Position', [442+10/3 267 53 20], 'Value', config.Spalten(17), 'Tag', 'config.Spalten(17)', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');
        uilabel(editFig, "Text", 'Current:', 'Position', [515-20/3 265 92+20/3 22]);
        uispinner(editFig, 'Position', [607 267 53 20], 'Value', config.Spalten(18), 'Tag', 'config.Spalten(18)', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'LowerLimitInclusive', 'on', 'UpperLimitInclusive', 'off');

        assignin("base", 'Zeilen', config.Zeilen)
        lineTags = {'config.Zeilen{1}', 'config.Zeilen{2}'};
        uitextarea(editFig, 'Position', [18 238 314+10/3 24], 'BackgroundColor', editFig.Color);
        uilabel(editFig, "Text", 'Zeilen der CSV:', 'Position', [20 238 200 22]);
        uilabel(editFig, "Text", 'von', 'Position', [120 238 25 22]);
        uilabel(editFig, "Text", 'bis', 'Position', [230 238 25 22]);
        try
            uispinner(editFig, 'Position', [150 240 70 20], 'Value', config.Zeilen{1}, 'Tag', 'config.Zeilen{1}', ...
                "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
            try
                uispinner(editFig, 'Position', [260+10/3 240 70 20], 'Value', str2double(config.Zeilen{2}), 'Tag', 'config.Zeilen{2}', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
            catch
                uispinner(editFig, 'Position', [260+10/3 240 70 20], 'Value', config.Zeilen{2}, 'Tag', 'config.Zeilen{2}', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
            end
        catch
            uispinner(editFig, 'Position', [150 240 70 20], 'Value', config.Zeilen(1), 'Tag', 'config.Zeilen{1}', ...
                "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
            try
                uispinner(editFig, 'Position', [260+10/3 240 70 20], 'Value', str2double(config.Zeilen(2)), 'Tag', 'config.Zeilen{2}', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
            catch
                uispinner(editFig, 'Position', [260+10/3 240 70 20], 'Value', config.Zeilen(2), 'Tag', 'config.Zeilen{2}', ...
                    "Limits", [1, inf], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) buildOCVLineString(editFig, lineTags));
            end
        end
        
        uilabel(editFig, "Text", 'Anode In:', 'Position', [350-10/3, 238, 80, 22]);
        uidropdown(editFig, "Items", {'X=Y=1', 'X>Y=1', 'Y>X=1', 'X>1<Y'}, "Position", [425, 238, 70, 22], ...
            "Value", config.anodeIn, 'Tag', 'config.anodeIn')
        uilabel(editFig, "Text", 'Anode Out:', 'Position', [515-20/3, 238, 90, 22]);
        uidropdown(editFig, "Items", {'X=Y=1', 'X>Y=1', 'Y>X=1', 'X>1<Y'}, "Position", [590, 238, 70, 22], ...
            "Value", config.anodeOut, 'Tag', 'config.anodeOut')
        uilabel(editFig, "Text", 'Cathode In:', 'Position', [350-10/3, 212, 90, 22]);
        uidropdown(editFig, "Items", {'X=Y=1', 'X>Y=1', 'Y>X=1', 'X>1<Y'}, "Position", [425, 212, 70, 22], ...
            "Value", config.cathodeIn, 'Tag', 'config.cathodeIn')
        uilabel(editFig, "Text", 'Cathode Out:', 'Position', [515-20/3, 212, 90, 22]);
        uidropdown(editFig, "Items", {'X=Y=1', 'X>Y=1', 'Y>X=1', 'X>1<Y'}, "Position", [590, 212, 70, 22], ...
            "Value", config.cathodeOut, 'Tag', 'config.cathodeOut')

        uilabel(editFig, "Text", 'Farben in I-/U-Plot:', 'Position', [20, 212, 105, 22]);
        uilabel(editFig, "Text", 'I:', 'Position', [135, 212, 10, 22]);
        uieditfield(editFig, 'text', 'Value', config.Farbe_I, 'Position', [150.5, 212, 68, 22], 'Tag', 'config.Farbe_I');
        uilabel(editFig, "Text", 'U:', 'Position', [248, 212, 15, 22]);
        uieditfield(editFig, 'text', 'Value', config.Farbe_U, 'Position', [263.5, 212, 68, 22], 'Tag', 'config.Farbe_U');
        
        uilabel(editFig, 'Position', [20 185 240 22], 'Text', 'Erlaubte Abweichung vom Durchschnitt:');
        uispinner(editFig, 'Position', [260+10/3 187 70 20], 'Value', config.deviationBalancedArea, 'Tag', 'config.deviationBalancedArea', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'ValueDisplayFormat', '%11.7g', 'LowerLimitInclusive', 'off', ...
            'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Fläche der Segmente [cm²]:', 'Position', [350-10/3 185 240 22]);
        uispinner(editFig, 'Position', [590 187 70 20], 'Value', config.segmentArea, 'Tag', 'config.segmentArea', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, 'Position', [20 160 240 22], 'Text', 'Videogeschwindigkeit [Bilder pro Sekunde]:');
        uispinner(editFig, 'Position', [260+10/3 162 70 20], 'Value', config.framerate, 'Tag', 'config.framerate', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'ValueDisplayFormat', '%11.7g', 'LowerLimitInclusive', 'off', ...
            'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Messpunkt der im Testplot gezeigt wird:', 'Position', [350-10/3 160 240 22]);
        uispinner(editFig, 'Position', [590 162 70 20], 'Value', config.singleFrame, 'Tag', 'config.singleFrame', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');
        
        uilabel(editFig, "Text", 'Jeder wie vielte Messpunkt soll angezeigt werden?', 'Position', [20 135 280 22]);
        uispinner(editFig, 'Position', [350-10/3 137 70 20], 'Value', config.frequency, 'Tag', 'config.frequency', ...
            "Limits", [0, inf], 'RoundFractionalValues', 'off', 'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off');

        uilabel(editFig, "Text", 'Feste Farbskala:', 'Position', [435, 135, 140, 22]);
        uicheckbox(editFig, "Value", config.cdColorCheck, 'Text', 'CD', 'Position', [585, 135, 35, 22], 'Tag', 'config.cdColorCheck');
        uicheckbox(editFig, "Value", config.tdColorCheck, 'Text', 'TD', 'Position', [625, 135, 35, 22], 'Tag', 'config.tdColorCheck');

        uilabel(editFig, "Text", 'Plot mit Raster anzeigen:', 'Position', [435, 110, 140, 22]);
        uicheckbox(editFig, "Value", config.cdGridCheck, 'Text', 'CD', 'Position', [585, 110, 35, 22], 'Tag', 'config.cdGridCheck');
        uicheckbox(editFig, "Value", config.tdGridCheck, 'Text', 'TD', 'Position', [625, 110, 35, 22], 'Tag', 'config.tdGridCheck');

        uicheckbox(editFig, "Text", " Plotbild anzeigen?", "Position", [536, 85, 124, 22], "Value", config.showPlotWindow, 'Tag', 'config.showPlotWindow');

        uilabel(editFig, "Text", 'Fehlerhafte Segmente:', 'Position', [20, 110, 125, 22]);
        uilabel(editFig, "Text", 'TD Zeilen (Y):', 'Position', [20, 85, 90, 22]);
        uieditfield(editFig, 'text', 'Value', config.tdLinesToDelete, 'Position', [115, 85, 410, 22], 'Tag', 'config.tdLinesToDelete');
        uilabel(editFig, "Text", 'TD Spalten (X):', 'Position', [20, 60, 90, 22]);
        uieditfield(editFig, 'text', 'Value', config.tdRowsToDelete, 'Position', [115, 60, 410, 22], 'Tag', 'config.tdRowsToDelete');
        uilabel(editFig, "Text", 'CD Zeilen (Y):', 'Position', [20, 35, 90, 22]);
        uieditfield(editFig, 'text', 'Value', config.cdLinesToDelete, 'Position', [115, 35, 410, 22], 'Tag', 'config.cdLinesToDelete');
        uilabel(editFig, "Text", 'CD Spalten (X):', 'Position', [20, 10, 90, 22]);
        uieditfield(editFig, 'text', 'Value', config.cdRowsToDelete, 'Position', [115, 10, 410, 22], 'Tag', 'config.cdRowsToDelete');

    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler in der config')
        disp(ME.message)
    end
end

function configData = loadConfigData(configPath)
    try
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
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler Laden der config')
        disp(ME.message)
    end
end

function saveConfig(editFig, tags, method)
    try
        % Laden der aktuellen Konfiguration
        configPath = evalin("base", 'configPath');
        configData = loadConfigData(configPath);
        
        isValid = true;  % Variable zur Überprüfung der Validität
        
        if isequal(method, 'CV_ECSA')
            columnTableData = evalin("base", 'columnTableData');
            refFastSlewRate = columnTableData(:,1);
            configData.(method) = setNestedField(configData.(method), {'refFastSlewRate'}, refFastSlewRate);
            refPtLoading = columnTableData(:,2);
            configData.(method) = setNestedField(configData.(method), {'refPtLoading'}, refPtLoading);
            refActiveArea = columnTableData(:,3);
            configData.(method) = setNestedField(configData.(method), {'refActiveArea'}, refActiveArea);
        end

        if isequal(method, 'OCV_FallOff') || isequal(method, 'Load__Points') || isequal(method, 'PK') || isequal(method, 'S_plus__plus_')
            zeilen = evalin("base", 'Zeilen');
            configData.(method) = setNestedField(configData.(method), {'Zeilen'}, zeilen);
            if isequal(method, 'OCV_FallOff')
                columnTableData = evalin("base", 'columnTableData');
                RefGrenzenwerte = columnTableData(:,1);
                configData.(method) = setNestedField(configData.(method), {'RefGrenzenwerte'}, RefGrenzenwerte);
                RefStartzeile = columnTableData(:,2);
                configData.(method) = setNestedField(configData.(method), {'RefStartzeile'}, RefStartzeile);
                RefStartzeileNutzen = columnTableData(:,3);
                configData.(method) = setNestedField(configData.(method), {'RefStartzeileNutzen'}, RefStartzeileNutzen);
            end
            if isequal(method, 'Load__Points') || isequal(method, 'PK')
                columnTableData = evalin("base", 'columnTableData');
                for i = 1:length(columnTableData(:, 2))
                    element = columnTableData(i, 1);
                    if ~ischar(element{1})
                        columnTableData(i, 1) = {char(element{1})};
                    end
                    element = columnTableData(i, 2);
                    if ~isnumeric(element{1})
                        columnTableData(i, 2) = {str2double(element{1})};
                    end
                end
                header = columnTableData(:, 1);
                spalten = cell2mat(columnTableData(:, 2));
                configData.(method) = setNestedField(configData.(method), {'Header'}, header);
                configData.(method) = setNestedField(configData.(method), {'Spalten'}, spalten);
                
                if isequal(method, 'Load__Points') 
                    colors = columnTableData(:, 3);
                    limits = columnTableData(:, 4);
                    configData.(method) = setNestedField(configData.(method), {'Colors'}, colors);
                    configData.(method) = setNestedField(configData.(method), {'Limits'}, limits);

                    triggerTableData = evalin("base", 'triggerTableData');
                    for i = 1:length((triggerTableData(:, 2)))
                        element = triggerTableData(i, 1);
                        if ~ischar(element{1})
                            triggerTableData(i, 1) = {char(element{1})};
                        end
                        element = triggerTableData(i, 2);
                        if ~isnumeric(element{1})
                            triggerTableData(i, 2) = {str2double(element{1})};
                        end
                    end
                    triggerNames = triggerTableData(:, 1);
                    trigger = cell2mat(triggerTableData(:, 2));
                    configData.(method) = setNestedField(configData.(method), {'TriggerNames'}, triggerNames);
                    configData.(method) = setNestedField(configData.(method), {'Trigger'}, trigger);
                end
            end
        end
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
                configData.(method) = setNestedField(configData.(method), tagParts(2:end), value); % Entferne method aus den Tag-Teilen
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
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler beim speichern der Methoden-config')
        disp(ME.message)
    end
end

function data = setNestedField(data, fieldPath, value)
    try
        if length(fieldPath) == 1
            % Überprüfen, ob der Feldname einen numerischen Index enthält
            if contains(fieldPath{1}, '(')
                [baseField, idx] = parseIndexedField(fieldPath{1});
                data.(baseField)(str2double(idx)) = value;
            else
                data.(fieldPath{1}) = value;
            end
        else
            if contains(fieldPath{1}, '(')
                [baseField, idx] = parseIndexedField(fieldPath{1});
                if ~isfield(data, baseField)
                    data.(baseField) = [];
                end
                data.(baseField)(str2double(idx)) = setNestedField(data.(baseField)(str2double(idx)), fieldPath(2:end), value);
            else
                if ~isfield(data, fieldPath{1})
                    data.(fieldPath{1}) = struct();
                end
                data.(fieldPath{1}) = setNestedField(data.(fieldPath{1}), fieldPath(2:end), value);
            end
        end
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, ['Fehler beim Schreiben eines Feldes', fieldPath{1}])
        disp(ME.message)
    end
end

function [baseField, idx] = parseIndexedField(field)
    try
        % Extrahiert den Basisfeldnamen und den Index aus einem Feldnamen wie 'xAchsenLimits(1)'
        parts = regexp(field, '(.*)\((\d+)\)', 'tokens');
        baseField = parts{1}{1};
        idx = parts{1}{2};
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler beim Extrahieren des Basisfeldnamen und des Index')
        disp(ME.message)
    end
        
end

function editConfigJson(parentFig)
    try
        % Diese Funktion ermöglicht das Bearbeiten der config.json.
        configPath = evalin("base", 'configPath');
    
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
        uibutton(editFig, 'Text', 'Speichern', 'Position', [150, 10, 100, 30], ...
            'ButtonPushedFcn', @(btn, event) saveFullConfig(configPath, textArea.Value, editFig, parentFig));
    catch ME
        if ~exist("editFig") %#ok<EXIST> 
            editFig = uifigure();
        end
        uialert(editFig, ME.message, 'Fehler beim öffnen des config.json Fensters')
        disp(ME.message)
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
        delete(parentFig);
    catch
        uialert(editFig, 'Ungültiges JSON-Format. Bitte korrigieren und erneut versuchen.', 'Fehler');
    end
    clear;
    clc;
end

function onTextChange(src)
    % Funktion, um sicherzustellen, dass die JSON-Daten als Zeichenkette vorliegen
    if iscell(src.Value)
        src.Value = strjoin(src.Value, '\n'); % Verbinde die Zellen zu einer einzigen Zeichenkette
    end
end