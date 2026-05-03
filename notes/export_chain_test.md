# 导出链路测试记录

## 测试目标

验证仓库是否具备从 Markdown 源文件导出 Word/PDF 测试文件的最小链路。

## 测试文件

源文件：

- `thesis_source/export_test.md`

输出文件：

- `exports/latest/test_export.docx`
- `exports/latest/test_export.pdf`

## 尝试命令

```powershell
pandoc thesis_source/export_test.md -o exports/latest/test_export.docx
pandoc thesis_source/export_test.md -o exports/latest/test_export.pdf
```

由于 `pandoc` 不可用，随后使用了本地备用链路：

```powershell
python <本地备用脚本>
```

## 生成结果

`thesis_source/export_test.md` 已成功导出为测试用 `docx` 和 `pdf` 文件。

## DOCX 是否成功

成功。

## PDF 是否成功

成功。

## 当前状态

`partially working`

原因：

- `pandoc` 未安装，直接的 Pandoc 导出命令无法运行。
- 本地备用链路可用，已经成功生成测试用 `docx` 和 `pdf`。
- `XeLaTeX` 和 `latexmk` 可用，PDF 端依赖的 LaTeX 引擎已经具备。

## 后续建议

- 后续如需统一导出流程，建议在本地补装 `pandoc`，再复测同一 Markdown 源文件。
- 可在 CI 中加入 Markdown -> Word/PDF 的自动化检查，避免导出链路回退。
- 如果希望统一脚本化流程，可以把当前备用链路整理成仓库内的轻量导出脚本。
