# 导出 Excel 使用指南

最直接的索引在 `data/exports/导出Excel索引.md`。使用时按论文图号进入对应文件夹：

| 图号 | 文件夹 | 优先使用 |
|---|---|---|
| Fig3/Fig4 | `01_Fig3_Fig4_stage1_inputs_cqr` | Stage1 代表日输入、天气和 CQR 区间 |
| Fig5 | `02_Fig5_cqr_gaussian` | CQR 与 Gaussian 风险边界对比 |
| Fig6/Fig7 | `03_Fig6_Fig7_baseline_control_power` | 控制量、温度、功率分解基线对比 |
| Fig9/Fig14 | `04_Fig9_Fig14_reserve_summary` | 天然备用、最大可行备用、可信备用汇总 |
| Fig10/Fig11 | `05_Fig10_Fig11_workpoint_risk` | R-Ts-ma 工作点和风险传播 |
| Fig12/Fig13 | `06_Fig12_Fig13_cost_curves_surfaces` | 成本曲面、成本曲线、Origin 宽表 |

判断规则：

- `for_origin`：给 Origin 直接作图的宽表。
- `noRevenue`：不含容量收益的成本版本，Fig12 如果强调 holding cost 需要核对它。
- 没有 `export_` 前缀的表多半是旧表或手工参考表，除非图表对应关系明确指定，否则优先级低。

## 补充实验

多测试日稳健性结果不在主线 `data/exports/` 中，已移到：

```text
../99-paper-sim-cleanroom_supplement/data/exports/07_multiday_robustness_beta90_nscan20/
```

它不是当前 Origin 主图默认数据源。
