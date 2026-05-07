# data 目录说明

`data/` 只保留论文主线需要的数据和按图号分组的导出 Excel。补充实验和历史归档已移出主线目录。

## 主线数据

| 目录 | 内容 | 谁会读取 |
|---|---|---|
| `raw/` | 原始 Excel、市场价格、Dymola 原始输入/状态 | Stage1、RegD 统计 |
| `processed/` | 处理后的状态和输入 MAT | `run/Stage1Code_CQR.m` |
| `stage1/` | CQR/N4SID/Stage2 接口 MAT | reserve scan、baseline、export |
| `stage1/gaussian/` | Gaussian 风险收缩对比结果 | Fig5 导出 |
| `regd/` | RegD 15min 统计结果 | 可信备用筛选 |
| `reserve/` | 逐小时备用扫描和可信备用筛选结果 | Fig9/Fig10/Fig11/Fig13 导出 |
| `baseline/` | 固定水侧 Ts 基线结果 | Fig6/Fig7 导出 |
| `postprocess/` | 成本/收益后处理 MAT | Fig12/Fig13 导出 |
| `exports/` | 论文图用 Excel，已经按图号分组 | Origin 和论文图 |

## 非主线数据在哪里

| 目录 | 内容 |
|---|---|
| `../99-paper-sim-cleanroom_supplement/` | 多测试日稳健性补充实验 |
| `../99-paper-sim-cleanroom_archive/` | 历史分支、旧图、旧表和归档副本 |

`figures/` 是代码直接生成的检查图，不是 Origin 最终论文图的唯一来源。

## 查 Excel

不要直接在 `exports/` 里凭文件名猜。先看：

```text
data/exports/导出Excel索引.md
```

该索引按 Fig3/Fig4、Fig5、Fig6/Fig7、Fig9/Fig14、Fig10/Fig11、Fig12/Fig13 分组。
