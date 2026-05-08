function changeSTKSensorColor(root, satName, rgbColor)
% string → char
    satName = char(satName);

    % STK Color: AABBGGRR
    R = rgbColor(1);
    G = rgbColor(2);
    B = rgbColor(3);
    A = 255;
    colorValue = hex2dec(sprintf('%02X%02X%02X%02X', A, B, G, R));

    % 衛星
    sat = root.GetObjectFromPath(['*/Satellite/' satName]);

    % ===== 一個一個 Sensor 直接抓 =====
    s1  = sat.Children.Item('Beam_01');
    s2  = sat.Children.Item('Beam_02');
    s3  = sat.Children.Item('Beam_03');
    s4  = sat.Children.Item('Beam_04');
    s5  = sat.Children.Item('Beam_05');
    s6  = sat.Children.Item('Beam_06');
    s7  = sat.Children.Item('Beam_07');
    s8  = sat.Children.Item('Beam_08');
    s9  = sat.Children.Item('Beam_09');
    s10 = sat.Children.Item('Beam_10');
    s11 = sat.Children.Item('Beam_11');
    s12 = sat.Children.Item('Beam_12');
    s13 = sat.Children.Item('Beam_13');
    s14 = sat.Children.Item('Beam_14');
    s15 = sat.Children.Item('Beam_15');
    s16 = sat.Children.Item('Beam_16');

    % ===== 一個一個設顏色 =====
    s1.Graphics.Color  = colorValue;
    s2.Graphics.Color  = colorValue;
    s3.Graphics.Color  = colorValue;
    s4.Graphics.Color  = colorValue;
    s5.Graphics.Color  = colorValue;
    s6.Graphics.Color  = colorValue;
    s7.Graphics.Color  = colorValue;
    s8.Graphics.Color  = colorValue;
    s9.Graphics.Color  = colorValue;
    s10.Graphics.Color = colorValue;
    s11.Graphics.Color = colorValue;
    s12.Graphics.Color = colorValue;
    s13.Graphics.Color = colorValue;
    s14.Graphics.Color = colorValue;
    s15.Graphics.Color = colorValue;
    s16.Graphics.Color = colorValue;

    fprintf('Satellite %s: Beam_01 ~ Beam_16 color updated.\n', satName);
end