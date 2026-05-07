function f = project_data_file(area, varargin)
%PROJECT_DATA_FILE Build an absolute cleanroom data path by logical area.
%
% Examples:
%   project_data_file('stage1', 'stage1_cqr_for_stage2.mat')
%   project_data_file('exports', 'export_stage1_cqr_prediction_intervals.xlsx')

P = project_paths();

switch lower(strrep(area, '-', '_'))
    case {'raw'}
        base = P.raw;
    case {'raw_dymola', 'dymola'}
        base = P.raw_dymola;
    case {'processed', 'processeddata'}
        base = P.processed;
    case {'stage1', 'stage1data'}
        base = P.stage1;
    case {'gaussian', 'rousseaugaussian', 'rousseaugaussian_cn'}
        base = P.gaussian;
    case {'regd'}
        base = P.regd;
    case {'baseline', 'baseline_fixedts', 'baseline_fixedts_suite'}
        base = P.baseline;
    case {'reserve', 'reservecostcurve_hourly', 'credible'}
        base = P.reserve;
    case {'postprocess', 'market', 'marketview', 'postprocess_market', 'reservecostcurve_hourly_marketview'}
        base = P.postprocess_market;
    case {'cost', 'costview', 'postprocess_cost', 'reservecostcurve_hourly_costview'}
        base = P.postprocess_cost;
    case {'multiday', 'multiday_beta90_nscan20'}
        base = P.multiday_beta90_nscan20;
    case {'exports', 'export'}
        base = P.exports;
    case {'figures', 'figure'}
        base = P.figures;
    otherwise
        error('project_data_file:UnknownArea', 'Unknown data area: %s', area);
end

f = fullfile(base, varargin{:});
end
