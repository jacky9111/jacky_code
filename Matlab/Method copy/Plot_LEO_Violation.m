function Plot_LEO_Violation(stats)

leoNames = keys(stats.LEO);
leoCounts = zeros(length(leoNames),1);

for i = 1:length(leoNames)
    leoCounts(i) = stats.LEO(leoNames{i});
end

% 排序
[leoCounts, idx] = sort(leoCounts, 'descend');
leoNames = leoNames(idx);

figure;
bar(leoCounts);
xlabel('LEO Satellite (sorted)');
ylabel('Violation Count');
title('LEO Contribution to GSO Exclusion Violations');
grid on;

end
