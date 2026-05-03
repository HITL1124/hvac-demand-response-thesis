# Markdown 到 Word/PDF 导出链路说明

本文件用于长期记录毕业论文从 Markdown 源文件导出到 Word/PDF 审阅稿或提交稿的工具链说明。当前文件只是模板，不代表已经导出真实论文，也不包含论文正文。

## 1. 目标

- 明确 Markdown 源文件、Word 审阅稿和 PDF 导出稿之间的关系。
- 记录本地或 CI 环境中需要的导出工具。
- 保存已验证的导出命令、失败原因和后续修复建议。
- 避免把导出稿当作长期正文源文件维护。

## 2. 文件角色

```text
thesis_source/   Markdown 源文件，作为正文内容的长期维护位置
exports/review/  阶段性 Word/PDF 审阅稿
exports/submission/  最终提交稿
```

如果 Word/PDF 审阅稿中发现内容问题，应回到 `thesis_source/` 中修改 Markdown 源文件。只有纯格式问题才适合在最终 Word 阶段处理。

## 3. 计划工具链

| 工具 | 用途 | 当前记录 |
| --- | --- | --- |
| Pandoc | 将 Markdown 导出为 docx 或 pdf | 待记录本地版本和验证结果 |
| xelatex | 作为 Pandoc PDF 导出的 LaTeX 引擎 | 待确认是否可用 |
| 学校 Word 模板 | 提供最终排版格式参考 | 待上传到 `requirements/templates/` |
| 导出脚本 | 固化常用导出命令 | 后续可放入 `scripts/export/` |

## 4. 推荐命令模板

以下命令仅作为后续测试和正式导出的模板，不应直接视为已经验证通过的最终命令。

```bash
pandoc thesis_source/<source-file>.md -o exports/review/<review-file>.docx
pandoc thesis_source/<source-file>.md -o exports/review/<review-file>.pdf --pdf-engine=xelatex
```

后续如需使用学校模板，可在命令中增加参考 docx：

```bash
pandoc thesis_source/<source-file>.md --reference-doc=requirements/templates/<template>.docx -o exports/review/<review-file>.docx
```

## 5. 环境验证记录

| 日期 | 环境 | Pandoc 版本 | PDF 引擎 | docx 导出 | pdf 导出 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 待记录 | 待记录 | 待记录 | 待记录 | 待记录 | 待记录 | 待记录 |

## 6. 故障记录模板

| 日期 | 命令 | 现象 | 原因判断 | 处理建议 | 状态 |
| --- | --- | --- | --- | --- | --- |
| 待记录 | 待记录 | 待记录 | 待记录 | 待记录 | 待记录 |

## 7. 后续待确认

- 是否使用 Pandoc 作为长期导出工具。
- 是否需要在本地安装并固定 LaTeX 引擎。
- 是否需要基于学校 Word 模板建立 `reference-doc`。
- 是否需要将常用命令固化为 `scripts/export/` 下的脚本。
- 是否需要在 GitHub Actions 或其他 CI 环境中复现导出链路。
