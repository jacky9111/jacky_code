function out = TestCoverageAtEpoch(root, satName, gsName, tStr, opts)
% TestCoverageAtEpoch
% Quick diagnostic for one satellite + one GS at one epoch.
%
% It checks:
% 1) Large rectangular beam (default 24.5 x 24.5 deg) coverage
% 2) 16-beam MATLAB model coverage (north->south strip)
% 3) Optional STK Access status for */Satellite/<sat>/Sensor/RectBeam -> */Facility/<gs>
%
% Inputs:
%   root   : STK root
%   satName: e.g. 'P01_S64'
%   gsName : facility name only, e.g. 'GSO_GS_geo_16_4'
%   tStr   : 'dd mmm yyyy HH:MM:SS'
%   opts (optional struct):
%       .largeHalfEW_deg (default 24.5)
%       .largeHalfNS_deg (default 24.5)
%       .smallHalfEW_deg (default 24.5)
%       .smallHalfNS_deg (default 25/16)
%       .nBeam           (default 16)
%
% Output fields:
%   out.large.inBeam
%   out.small.inBeam(1x16), out.small.bestBeam
%   out.stkRectBeam.accessAtEpoch (if available)

if nargin < 5 || isempty(opts), opts = struct(); end
if ~isfield(opts, 'largeHalfEW_deg'), opts.largeHalfEW_deg = 24.5; end
if ~isfield(opts, 'largeHalfNS_deg'), opts.largeHalfNS_deg = 24.5; end
if ~isfield(opts, 'smallHalfEW_deg'), opts.smallHalfEW_deg = 24.5; end
if ~isfield(opts, 'smallHalfNS_deg'), opts.smallHalfNS_deg = 25/16; end
if ~isfield(opts, 'nBeam'), opts.nBeam = 16; end

satPath = ['*/Satellite/' char(satName)];
gsPath  = ['*/Facility/' char(gsName)];

rSat_km = getXYZFixed(root, satPath, tStr, 'Cartesian Position');
vSat_kmps = getXYZFixed(root, satPath, tStr, 'Cartesian Velocity');
rGs_km = getXYZFixedNoTime(root, gsPath, 'Cartesian Position');

rSat_m = rSat_km * 1000;
vSat_mps = vSat_kmps * 1000;
vSG_m = (rGs_km - rSat_km) * 1000; % sat -> GS
dHat = vSG_m / max(norm(vSG_m), eps);

[b0, cAxis, tAxis] = buildFrame(rSat_m, vSat_mps);

% --- Large beam check ---
thH_large = atan2d(dot(dHat, cAxis), dot(dHat, b0));
thV_large = atan2d(dot(dHat, tAxis), dot(dHat, b0));
inLarge = (abs(thH_large) <= opts.largeHalfEW_deg) && (abs(thV_large) <= opts.largeHalfNS_deg);

% --- 16-beam check (north->south centers) ---
nBeam = opts.nBeam;
pitchOffsets_deg = ((nBeam/2 + 0.5) - (1:nBeam)) * (2 * opts.smallHalfNS_deg);
inSmall = false(1, nBeam);
thH_small = nan(1, nBeam);
thV_small = nan(1, nBeam);

for b = 1:nBeam
    bHat = rodrigues(b0, cAxis, deg2rad(pitchOffsets_deg(b)));
    tHat = cross(cAxis, bHat);
    tHat = tHat / max(norm(tHat), eps);

    thH_small(b) = atan2d(dot(dHat, cAxis), dot(dHat, bHat));
    thV_small(b) = atan2d(dot(dHat, tHat), dot(dHat, bHat));
    inSmall(b) = (abs(thH_small(b)) <= opts.smallHalfEW_deg) && ...
                 (abs(thV_small(b)) <= opts.smallHalfNS_deg);
end

[~, bestBeam] = min(abs(thV_small));

out = struct();
out.input = struct('satName', string(satName), 'gsName', string(gsName), 'tStr', string(tStr));
out.large = struct('halfEW_deg', opts.largeHalfEW_deg, ...
                   'halfNS_deg', opts.largeHalfNS_deg, ...
                   'thH_deg', thH_large, ...
                   'thV_deg', thV_large, ...
                   'inBeam', inLarge);
out.small = struct('halfEW_deg', opts.smallHalfEW_deg, ...
                   'halfNS_deg', opts.smallHalfNS_deg, ...
                   'inBeam', inSmall, ...
                   'thH_deg', thH_small, ...
                   'thV_deg', thV_small, ...
                   'bestBeam', bestBeam);

fprintf('\n=== Coverage Diagnostic @ %s ===\n', tStr);
fprintf('Satellite: %s | GS: %s\n', satName, gsName);
fprintf('Large beam  H=%.2f V=%.2f  => thH=%.3f thV=%.3f  inBeam=%d\n', ...
    opts.largeHalfEW_deg, opts.largeHalfNS_deg, thH_large, thV_large, inLarge);
fprintf('16-beam small V=%.4f deg: beams covering GS = %s\n', ...
    opts.smallHalfNS_deg, mat2str(find(inSmall)));
fprintf('Closest beam by |thV| = %d (thV=%.3f deg)\n', bestBeam, thV_small(bestBeam));

% --- Optional STK access check for RectBeam ---
out.stkRectBeam = struct('checked', false, 'accessAtEpoch', NaN, 'message', "");
try
    sensorPath = ['*/Satellite/' char(satName) '/Sensor/RectBeam'];
    sObj = root.GetObjectFromPath(sensorPath);
    gObj = root.GetObjectFromPath(gsPath);
    acc = sObj.GetAccessToObject(gObj);
    acc.ComputeAccess;

    tf = false;
    try
        iv = acc.ComputedAccessIntervalTimes;
        n = iv.Count;
        tNow = datenum(tStr);
        for k = 1:n
            try
                it = iv.Item(k-1);
            catch
                it = iv.Item(k);
            end
            ts = datenum(char(it.Start));
            te = datenum(char(it.Stop));
            if tNow >= ts && tNow <= te
                tf = true;
                break;
            end
        end
        out.stkRectBeam.checked = true;
        out.stkRectBeam.accessAtEpoch = tf;
        out.stkRectBeam.message = "OK";
        fprintf('STK RectBeam Access at epoch = %d\n', tf);
    catch
        out.stkRectBeam.checked = true;
        out.stkRectBeam.accessAtEpoch = NaN;
        out.stkRectBeam.message = "Computed access, but failed to parse intervals.";
        fprintf('STK RectBeam Access parsed failed (interval API mismatch).\n');
    end
catch ME
    out.stkRectBeam.checked = false;
    out.stkRectBeam.accessAtEpoch = NaN;
    out.stkRectBeam.message = string(ME.message);
    fprintf('STK RectBeam Access check skipped: %s\n', ME.message);
end
end

function [b0, cAxis, tAxis] = buildFrame(rSat_m, vSat_mps)
nHat = rSat_m / max(norm(rSat_m), eps);
vPerp = vSat_mps - dot(vSat_mps, nHat) * nHat;
tAxis = vPerp / max(norm(vPerp), eps);      % along-track
cAxis = cross(nHat, tAxis);                 % cross-track
cAxis = cAxis / max(norm(cAxis), eps);
b0 = -nHat;                                 % nadir
end

function v = rodrigues(u, k, ang)
v = u*cos(ang) + cross(k,u)*sin(ang) + k*dot(k,u)*(1-cos(ang));
v = v / max(norm(v), eps);
end

function xyz = getXYZFixed(root, objPath, tStr, providerName)
obj = root.GetObjectFromPath(objPath);
dp = obj.DataProviders.Item(providerName).Group.Item('Fixed');
res = dp.ExecSingle(tStr);
xyz = parseXYZ(res.DataSets.ToArray);
end

function xyz = getXYZFixedNoTime(root, objPath, providerName)
obj = root.GetObjectFromPath(objPath);
res = obj.DataProviders.Item(providerName).Exec;
xyz = parseXYZ(res.DataSets.ToArray);
end

function xyz = parseXYZ(arr)
if isnumeric(arr)
    v = arr(:);
    xyz = double(v(1:3));
    return;
end
vals = [];
for k = 1:numel(arr)
    a = arr{k};
    if isnumeric(a) && isscalar(a)
        vals(end+1,1) = double(a); %#ok<AGROW>
    elseif ischar(a) || isstring(a)
        n = str2double(a);
        if ~isnan(n), vals(end+1,1) = n; end %#ok<AGROW>
    end
end
if numel(vals) < 3
    error('parseXYZ failed');
end
xyz = vals(1:3);
end
