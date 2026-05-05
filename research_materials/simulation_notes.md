# 仿真材料说明

本文件用于后续记录仿真环境、运行过程和研究材料整理情况。

当前不填写仿真结果，不编造数据，也不记录未经确认的研究结论。

## 目录定位

`research_materials/simulation/` 用于后续整体放入整理完成的仿真 cleanroom 项目。该项目目前仍在作者本地整理中，本次仓库调整不导入实际代码、数据、图表或导出文件。

`research_materials/dymola/` 用于单独存放 Dymola 平台、模型或原始导出材料。

## cleanroom 仿真流程理解

根据作者本地 `99-paper-sim-cleanroom` 当前结构，仿真项目应作为一个自包含工程整体管理，不再按编程语言拆分。其内部职责大致如下：

- `run/`：主运行入口，包括 MATLAB 主脚本和 Python Stage1/CQR 相关入口。
- `export/`：导出脚本，主要用于把 MAT 或中间结果导出为 xlsx。
- `plot/`：辅助检查绘图脚本，用于复查结果和生成检查图。
- `src/`：非入口函数、后处理函数和分析辅助函数。
- `data/`：原始数据、处理后数据、Stage1 结果、备用扫描结果、后处理结果、导出 xlsx 和检查图等。
- `docs/`：仿真流程说明、数据清单、代码清单、图表数据对应关系和验证报告。
- `paper/`：小论文 TeX/PDF 对照副本，仅用于核对。
- `origin/`：Origin 工程或图源对照材料。
- `archive/`：旧分支、旧数据、临时文件或非主线材料。

## 后续导入原则

- 等作者确认 cleanroom 整理完成后，再整体导入 `research_materials/simulation/`。
- 导入时保持 cleanroom 内部结构，不按编程语言拆分。
- 大型 MAT、xlsx、png、Origin 工程等文件是否纳入 Git，需要在导入前单独确认。
- 与论文图表相关的数据映射，应后续同步整理到 `notes/figure_registry.md`。
