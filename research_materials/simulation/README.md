# 小论文仿真代码清洁室

这个目录是小论文仿真代码的整理版。原始 `Code/`、`Tex/`、`00 Figures/` 没有被修改。

## 目录结构

- `run/`: 所有主运行入口，包括 MATLAB `run_*.m`、`Stage1Code_CQR.m`、`stage1_cqr.py`、`stage1_cqr_plot.py`。
- `export/`: 所有 `export_*.m`，默认把 xlsx 写到 `data/exports/` 下按图号分组的子文件夹。
- `plot/`: 辅助检查绘图脚本，默认把图片写到 `data/figures/`。
- `src/`: 非入口函数和分析辅助函数。
- `data/exports/`: 已按 Fig3/Fig4、Fig5、Fig6/Fig7、Fig9/Fig14、Fig10/Fig11、Fig12/Fig13 分组。
- `docs/`: 中文命名的清单、图表对应关系和仿真流程说明。

补充实验和历史归档不在主线目录内：

- `../99-paper-sim-cleanroom_supplement/`: 多测试日稳健性补充实验。
- `../99-paper-sim-cleanroom_archive/`: 历史分支、旧图、旧表和归档副本。

## MATLAB 使用

在 MATLAB 中把当前目录切到本目录，`startup.m` 会加入 `run/export/plot/src` 路径。脚本默认路径统一走：

- `project_paths.m`
- `project_data_file.m`

如果从其他目录启动 MATLAB，先执行：

```matlab
cd('C:\Users\UserX\Desktop\课题\研0\Coordinating Water and Air Loops\99-paper-sim-cleanroom')
startup
```

## 先看这些

- `docs/00_先看这里.md`: 给新读者的第一入口，说明阅读顺序和哪些目录先不要看。
- `data/exports/导出Excel索引.md`: 按论文图号找对应 Excel。
- `data/README.md`: 说明 `data/` 哪些是主线数据，哪些是扩展验证。
- `docs/01_仿真主线流程.md`: 从 Stage1 到 Origin 导图的主仿真流程。
- `docs/02_论文图表数据对应关系.md`: 论文图、xlsx、export 脚本、上游 run 脚本对应关系。
- `docs/03_导出Excel使用指南.md`: 解释 `data/exports` 每个分组目录什么时候用。
- `docs/04_导出脚本说明.md`: 每个 export 脚本读取什么、导出什么、处理什么数据。
- `docs/90_验证报告.md`: 静态检查、路径检查和未运行项记录。
- `docs/92_数据清单.csv`: 活跃数据和归档引用文件清单。
- `docs/93_导出Excel表头摘要.csv`: 已有 xlsx 的 sheet 和表头摘要。
