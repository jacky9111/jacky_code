function Plot_TopK_GEO(stats, K)

geoNames = keys(stats.GEO);
geoCounts = zeros(length(geoNames),1);

for i = 1:length(geoNames)
    geoCounts(i) = stats.GEO(geoNames{i});
end

[geoCounts, idx] = sort(geoCounts, 'descend');
geoNames = geoNames(idx);

K = min(K, length(geoNames));

figure;
bar(geoCounts(1:K));
set(gca, 'XTick', 1:K, ...
         'XTickLabel', geoNames(1:K), ...
         'XTickLabelRotation', 30);

ylabel('Violation Count');
xlabel('GEO Satellite');
title(sprintf('Top-%d GEO Satellites with Highest Violations', K));
grid on;

end
