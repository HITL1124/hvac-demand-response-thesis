from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parent

RUN = ROOT / "run"
EXPORT = ROOT / "export"
PLOT = ROOT / "plot"
SRC = ROOT / "src"

DATA = ROOT / "data"
RAW = DATA / "raw"
RAW_DYMOLA = RAW / "dymola"
PROCESSED = DATA / "processed"
STAGE1 = DATA / "stage1"
GAUSSIAN = STAGE1 / "gaussian"
REGD = DATA / "regd"
BASELINE = DATA / "baseline"
RESERVE = DATA / "reserve"
POSTPROCESS = DATA / "postprocess"
POSTPROCESS_MARKET = POSTPROCESS / "market"
POSTPROCESS_COST = POSTPROCESS / "cost"
EXPORTS = DATA / "exports"
FIGURES = DATA / "figures"

SUPPLEMENT_ROOT = ROOT.with_name(f"{ROOT.name}_supplement")
ARCHIVE_ROOT = ROOT.with_name(f"{ROOT.name}_archive")
SUPPLEMENT_STAGE1_TEST_DAYS = SUPPLEMENT_ROOT / "data" / "stage1" / "test_days"
SUPPLEMENT_MULTIDAY_BETA90_NSCAN20 = SUPPLEMENT_ROOT / "data" / "multiday_beta90_nscan20"
SUPPLEMENT_EXPORTS_MULTIDAY = SUPPLEMENT_ROOT / "data" / "exports" / "07_multiday_robustness_beta90_nscan20"


def data_file(area: str, *parts: str) -> Path:
    key = area.replace("-", "_").lower()
    areas = {
        "raw": RAW,
        "raw_dymola": RAW_DYMOLA,
        "dymola": RAW_DYMOLA,
        "processed": PROCESSED,
        "processeddata": PROCESSED,
        "stage1": STAGE1,
        "stage1data": STAGE1,
        "gaussian": GAUSSIAN,
        "rousseaugaussian": GAUSSIAN,
        "regd": REGD,
        "baseline": BASELINE,
        "baseline_fixedts": BASELINE,
        "reserve": RESERVE,
        "reservecostcurve_hourly": RESERVE,
        "postprocess_market": POSTPROCESS_MARKET,
        "market": POSTPROCESS_MARKET,
        "marketview": POSTPROCESS_MARKET,
        "postprocess_cost": POSTPROCESS_COST,
        "cost": POSTPROCESS_COST,
        "costview": POSTPROCESS_COST,
        "exports": EXPORTS,
        "export": EXPORTS,
        "figures": FIGURES,
    }
    try:
        base = areas[key]
    except KeyError as exc:
        raise KeyError(f"Unknown data area: {area}") from exc
    return base.joinpath(*parts)
