function out_cost = run_postprocess_hourly_credible_cost_view_full(inReserve, inCred, cfg)
% =========================================================================
% 纯成本后处理（最简版）
% -------------------------------------------------------------------------
% 作用：
%   1) 从逐小时热可行结果中读取原始成本曲线；
%   2) 用可信备用上界 R_cred(h) 对每小时曲线做截断；
%   3) 自动补上 [0, min(R_nat, R_cred)] 的天然备用零成本段；
%   4) 输出纯成本结果 out_cost；
%   5) 按需直接调用绘图函数。
%
% 注意：
%   - 不改内层优化；
%   - 不涉及收益项；
%   - 目标就是得到可信域上的 DeltaJ(R)。
% =========================================================================

if nargin < 1 || isempty(inReserve)
    inReserve = project_data_file('reserve','hourly_reserve_costcurve_all_beta.mat');
end
if nargin < 2 || isempty(inCred)
    inCred = project_data_file('reserve','hourly_credible_feasibility_v2_all_beta.mat');
end
if nargin < 3, cfg = struct(); end
cfg = local_fill_defaults(cfg);

if ~exist(cfg.outdir, 'dir')
    mkdir(cfg.outdir);
end

[out_ref, beta_use]     = local_load_reserve_any(inReserve, cfg.beta_select);
[cred_ref, beta_screen] = local_load_cred_any(inCred,   cfg.beta_select);

out_cost = struct();
out_cost.case_label = 'credible_cost_postprocessed_simple';
out_cost.beta_use = beta_use;
out_cost.beta_screen = beta_screen;
out_cost.cfg = cfg;
out_cost.base = out_ref;
out_cost.cred = cred_ref;
out_cost.reserve_source = inReserve;
out_cost.credible_source = inCred;
out_cost.R_nat_hour = out_ref.R_nat_hour(:);
out_cost.R_cred_hour = cred_ref.summary.R_cred_hour(:);

Nh = double(out_ref.mdl.Nh);
out_cost.hours = repmat(struct(), Nh, 1);

for h = 1:Nh
    Hr = out_ref.hours(h);
    Rnat  = out_cost.R_nat_hour(h);
    Rcred = out_cost.R_cred_hour(h);

    R_all  = local_get_field_or(Hr, 'R_grid', []);
    feas   = local_get_field_or(Hr, 'is_feasible', true(size(R_all)));
    R_all  = R_all(:);
    feas   = logical(feas(:));

    J_all  = local_get_num_field(Hr, 'delta_total',  R_all);
    JE_all = local_get_num_field(Hr, 'delta_energy', R_all);
    JT_all = local_get_num_field(Hr, 'delta_temp',   R_all);
    MA_all = local_get_num_field(Hr, 'ma_hour',      R_all);
    PF_all = local_get_num_field(Hr, 'Pfan_hour',    R_all);
    TS_all = local_get_num_field(Hr, 'Ts_hour_C',    R_all);

    % 1) 天然备用零成本段
    R0 = min(max(Rnat, 0), max(Rcred, 0));
    if R0 > cfg.reserve_tol
        R_seg = linspace(0, R0, cfg.nNatSeg).';
    elseif Rcred >= 0
        R_seg = 0;
    else
        R_seg = [];
    end

    J_seg  = zeros(size(R_seg));
    JE_seg = zeros(size(R_seg));
    JT_seg = zeros(size(R_seg));
    MA_seg = out_ref.baseline.ma_hour(h) * ones(size(R_seg));
    PF_seg = out_ref.baseline.Pfan_hour(h) * ones(size(R_seg));
    TS_seg = (out_ref.baseline.Ts_hour(h) - 273.15) * ones(size(R_seg));

    % 2) 原始曲线中可信域内的部分
    keep = feas & isfinite(R_all) & (R_all <= Rcred + cfg.reserve_tol) & (R_all > R0 + cfg.reserve_tol);

    R_keep  = R_all(keep);
    J_keep  = J_all(keep);
    JE_keep = JE_all(keep);
    JT_keep = JT_all(keep);
    MA_keep = MA_all(keep);
    PF_keep = PF_all(keep);
    TS_keep = TS_all(keep);

    % 3) 拼接、去重、排序
    R_plot  = [R_seg;  R_keep];
    J_plot  = [J_seg;  J_keep];
    JE_plot = [JE_seg; JE_keep];
    JT_plot = [JT_seg; JT_keep];
    MA_plot = [MA_seg; MA_keep];
    PF_plot = [PF_seg; PF_keep];
    TS_plot = [TS_seg; TS_keep];

    if ~isempty(R_plot)
        [R_plot, ia] = unique(R_plot, 'stable');
        J_plot  = J_plot(ia);
        JE_plot = JE_plot(ia);
        JT_plot = JT_plot(ia);
        MA_plot = MA_plot(ia);
        PF_plot = PF_plot(ia);
        TS_plot = TS_plot(ia);

        [R_plot, ord] = sort(R_plot);
        J_plot  = J_plot(ord);
        JE_plot = JE_plot(ord);
        JT_plot = JT_plot(ord);
        MA_plot = MA_plot(ord);
        PF_plot = PF_plot(ord);
        TS_plot = TS_plot(ord);
    end

    out_cost.hours(h).hour = h;
    out_cost.hours(h).R_grid_cred = R_plot;
    out_cost.hours(h).delta_total_cred = J_plot;
    out_cost.hours(h).delta_energy_cred = JE_plot;
    out_cost.hours(h).delta_temp_cred = JT_plot;
    out_cost.hours(h).ma_hour_cred = MA_plot;
    out_cost.hours(h).Pfan_hour_cred = PF_plot;
    out_cost.hours(h).Ts_hour_C_cred = TS_plot;
end

outfile = fullfile(cfg.outdir, sprintf('hourly_reserve_credible_cost_full_beta_%02d.mat', round(100*beta_use)));
save(outfile, 'out_cost', '-v7.3');
out_cost.saved_mat = outfile;

if cfg.makePlots
    plot_postprocess_hourly_credible_cost_view_full(out_cost, cfg);
end

fprintf('\n============================================================\n');
fprintf('纯成本后处理完成\n');
fprintf('beta_use / beta_screen = %.4f / %.4f\n', beta_use, beta_screen);
fprintf('MAT 已保存到: %s\n', out_cost.saved_mat);
fprintf('============================================================\n');

end

% =========================================================================
% 默认参数
% =========================================================================
function cfg = local_fill_defaults(cfg)
if ~isfield(cfg,'beta_select') || isempty(cfg.beta_select)
    cfg.beta_select = 0.95;
end
if ~isfield(cfg,'outdir') || isempty(cfg.outdir)
    cfg.outdir = project_data_file('postprocess_cost');
end
if ~isfield(cfg,'reserve_tol') || isempty(cfg.reserve_tol)
    cfg.reserve_tol = 1e-8;
end
if ~isfield(cfg,'nNatSeg') || isempty(cfg.nNatSeg)
    cfg.nNatSeg = 21;
end
if ~isfield(cfg,'makePlots') || isempty(cfg.makePlots)
    cfg.makePlots = true;
end
end

% =========================================================================
% reserve 读取
% =========================================================================
function [out, beta_use] = local_load_reserve_any(inReserve, beta_select)
if ischar(inReserve) || isstring(inReserve)
    S = load(inReserve);
else
    S = inReserve;
end

if isfield(S,'out_i')
    out = S.out_i;
    beta_use = local_get_beta_from_out(out);
    return;
elseif isfield(S,'out')
    out = S.out;
    beta_use = local_get_beta_from_out(out);
    return;
elseif isfield(S,'hours') && isfield(S,'baseline')
    out = S;
    beta_use = local_get_beta_from_out(out);
    return;
elseif isfield(S,'results_all')
    results_all = S.results_all;
else
    error('无法识别 reserve 输入。');
end

n = numel(results_all);
beta_list = nan(n,1);
for i = 1:n
    entry_i = local_pick_entry(results_all, i);
    oi = local_extract_out(entry_i);
    beta_list(i) = local_get_beta_from_out(oi);
end
[~, idx] = min(abs(beta_list - beta_select));
out = local_extract_out(local_pick_entry(results_all, idx));
beta_use = local_get_beta_from_out(out);
end

function out = local_extract_out(entry)
if isstruct(entry) && isfield(entry,'out_i')
    out = entry.out_i;
elseif isstruct(entry) && isfield(entry,'out')
    out = entry.out;
else
    out = entry;
end
end

function entry = local_pick_entry(results_all, idx)
if iscell(results_all)
    entry = results_all{idx};
else
    entry = results_all(idx);
end
end

function beta = local_get_beta_from_out(out)
beta = NaN;
if isfield(out,'beta_use') && ~isempty(out.beta_use)
    beta = double(out.beta_use);
elseif isfield(out,'mdl') && isfield(out.mdl,'beta_use') && ~isempty(out.mdl.beta_use)
    beta = double(out.mdl.beta_use);
elseif isfield(out,'cfg') && isfield(out.cfg,'beta_target') && ~isempty(out.cfg.beta_target)
    beta = double(out.cfg.beta_target);
end
end

% =========================================================================
% cred 读取
% =========================================================================
function [credOne, beta_screen] = local_load_cred_any(inCred, beta_select)
if ischar(inCred) || isstring(inCred)
    S = load(inCred);
else
    S = inCred;
end

if isfield(S,'cred')
    S = S.cred;
end

if isfield(S,'summary')
    credOne = S;
    beta_screen = local_get_beta_from_cred(credOne);
    return;
elseif isfield(S,'results_all')
    results_all = S.results_all;
else
    error('无法识别 cred 输入。');
end

n = numel(results_all);
beta_list = nan(n,1);
for i = 1:n
    entry_i = local_pick_entry(results_all, i);
    ci = local_extract_cred(entry_i);
    beta_list(i) = local_get_beta_from_cred(ci);
end
[~, idx] = min(abs(beta_list - beta_select));
credOne = local_extract_cred(local_pick_entry(results_all, idx));
beta_screen = local_get_beta_from_cred(credOne);
end

function credOne = local_extract_cred(entry)
if isstruct(entry) && isfield(entry,'summary')
    credOne = entry;
elseif isstruct(entry) && isfield(entry,'cred')
    credOne = entry.cred;
else
    credOne = entry;
end
end

function beta = local_get_beta_from_cred(credOne)
beta = NaN;
if isfield(credOne,'cfg') && isfield(credOne.cfg,'beta_screen') && ~isempty(credOne.cfg.beta_screen)
    beta = double(credOne.cfg.beta_screen);
elseif isfield(credOne,'meta') && isfield(credOne.meta,'beta_screen') && ~isempty(credOne.meta.beta_screen)
    beta = double(credOne.meta.beta_screen);
end
end

% =========================================================================
% 小工具
% =========================================================================
function v = local_get_field_or(S, name, v0)
if isfield(S, name) && ~isempty(S.(name))
    v = S.(name);
else
    v = v0;
end
end

function v = local_get_num_field(S, name, ref)
if isfield(S,name) && ~isempty(S.(name))
    v = S.(name)(:);
else
    v = nan(size(ref));
end
end
