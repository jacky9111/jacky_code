function [Tuser, Tbeam, Tsat, Tglobal] = RunKu16BeamBaselineObservationWithPowerControlLogExcel(root, opts)
% RunKu16BeamBaselineObservationWithPowerControlLogExcel
% Dedicated API: baseline observation + uniform EPFD power control.

if nargin < 2 || isempty(opts), opts = struct(); end
opts.enablePowerControl = true;

if ~isfield(opts,'excelPath') || isempty(opts.excelPath) || strlength(string(opts.excelPath)) == 0
    here = fileparts(mfilename('fullpath'));
    opts.excelPath = fullfile(here, '..', '..', 'Matlab_data', 'LEO16_Ku_Baseline_Observation_PC.xlsx');
end

[Tuser, Tbeam, Tsat, Tglobal] = RunKu16BeamBaselineObservationLogExcel(root, opts);
end
