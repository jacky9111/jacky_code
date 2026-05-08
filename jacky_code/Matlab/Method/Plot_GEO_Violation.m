function Plot_GEO_Violation(stats)

geoNames = keys(stats.GEO);
geoCounts = zeros(length(geoNames),1);

for i = 1:length(geoNames)
    geoCounts(i) = stats.GEO(geoNames{i});
end

% 依 violation 數排序
[geoCounts, idx] = sort(geoCounts, 'descend');
geoNames = geoNames(idx);

figure;
bar(geoCounts);
set(gca, 'XTick', 1:length(geoNames), ...
         'XTickLabel', geoNames, ...
         'XTickLabelRotation', 45);

ylabel('Violation Count');
xlabel('GEO Satellite');
title('GSO Exclusion Angle Violations per GEO Satellite');
grid on;

end
