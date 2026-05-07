function P = project_paths(rootDir)
%PROJECT_PATHS Central path registry for the paper simulation cleanroom.
%
%   P = project_paths() returns absolute paths rooted at this cleanroom.
%   P = project_paths(rootDir) uses the supplied root instead.

if nargin < 1 || isempty(rootDir)
    rootDir = fileparts(mfilename('fullpath'));
end

P = struct();
P.root = rootDir;

P.run = fullfile(rootDir, 'run');
P.export = fullfile(rootDir, 'export');
P.plot = fullfile(rootDir, 'plot');
P.src = fullfile(rootDir, 'src');

P.data = fullfile(rootDir, 'data');
P.raw = fullfile(P.data, 'raw');
P.raw_dymola = fullfile(P.raw, 'dymola');
P.processed = fullfile(P.data, 'processed');
P.stage1 = fullfile(P.data, 'stage1');
P.gaussian = fullfile(P.stage1, 'gaussian');
P.regd = fullfile(P.data, 'regd');
P.baseline = fullfile(P.data, 'baseline');
P.reserve = fullfile(P.data, 'reserve');
P.postprocess = fullfile(P.data, 'postprocess');
P.postprocess_market = fullfile(P.postprocess, 'market');
P.postprocess_cost = fullfile(P.postprocess, 'cost');
P.exports = fullfile(P.data, 'exports');
P.figures = fullfile(P.data, 'figures');

P.docs = fullfile(rootDir, 'docs');
P.paper = fullfile(rootDir, 'paper');
P.origin = fullfile(rootDir, 'origin');

P.supplement_root = fullfile(fileparts(rootDir), [get_last_path_part(rootDir) '_supplement']);
P.archive_root = fullfile(fileparts(rootDir), [get_last_path_part(rootDir) '_archive']);
P.supplement_stage1_test_days = fullfile(P.supplement_root, 'data', 'stage1', 'test_days');
P.supplement_multiday_beta90_nscan20 = fullfile(P.supplement_root, 'data', 'multiday_beta90_nscan20');
P.supplement_exports_multiday = fullfile(P.supplement_root, 'data', 'exports', '07_multiday_robustness_beta90_nscan20');
end

function name = get_last_path_part(pathStr)
[~, name] = fileparts(pathStr);
end
