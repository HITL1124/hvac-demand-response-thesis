# 仿真材料说明

本文件用于后续记录仿真环境、运行过程和研究材料整理情况。

当前不填写仿真结果，不编造数据，也不记录未经确认的研究结论。

## 目录定位

`research_materials/simulation/` 用于整体存放整理后的仿真 cleanroom 项目。当前已导入 `99-paper-sim-cleanroom` 的主线版本，保留其内部目录结构和原始文件名。

`research_materials/dymola/` 用于单独存放 Dymola 平台、模型或原始导出材料。

## 当前导入状态

当前 `research_materials/simulation/` 已包含：

- `README.md`：cleanroom 项目入口说明。
- `project_paths.m`、`project_data_file.m`、`project_paths.py`、`startup.m`：路径和启动相关入口文件。
- `run/`、`export/`、`plot/`、`src/`：仿真运行、导出、检查绘图和辅助函数代码。
- `data/`：主线仿真数据、处理结果、导出 Excel 和检查图。
- `docs/`：仿真流程、代码清单、数据清单、图表数据对应关系和验证记录。

本次导入保留 cleanroom 的当前整理形态，不改写仿真代码逻辑，不重命名内部文件，不验证或生成新的仿真结果。

`research_materials/simulation/` 下的 `.mat` 文件由 Git LFS 管理。其他 `.m`、`.py`、`.md`、`.xlsx`、`.csv`、`.png` 等文件按普通 Git 文件管理。

## cleanroom 仿真流程理解

根据作者本地 `99-paper-sim-cleanroom` 当前结构，仿真项目应作为一个自包含工程整体管理，不再按编程语言拆分。其内部职责大致如下：

- `run/`：主运行入口，包括 MATLAB 主脚本和 Python Stage1/CQR 相关入口。
- `export/`：导出脚本，主要用于把 MAT 或中间结果导出为 xlsx。
- `plot/`：辅助检查绘图脚本，用于复查结果和生成检查图。
- `src/`：非入口函数、后处理函数和分析辅助函数。
- `data/`：原始数据、处理后数据、Stage1 结果、备用扫描结果、后处理结果、导出 xlsx 和检查图等。
- `docs/`：仿真流程说明、数据清单、代码清单、图表数据对应关系和验证报告。
- `data/exports/`：按论文图号分组的导出 Excel，供 Origin 和论文图核对使用。

## 后续整理原则

- 后续更新 cleanroom 时保持其内部结构，不按编程语言拆分。
- 与论文图表相关的数据映射，应后续同步整理到 `notes/figure_registry.md`。
- 如需导入补充实验或历史归档，应单独确认范围，不默认导入同级的 supplement 或 archive 目录。
