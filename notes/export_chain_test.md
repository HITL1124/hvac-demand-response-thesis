# 导出链路测试记录

## 测试目标

验证仓库是否具备从 Markdown 源文件通过 Pandoc 导出 Word/PDF 的最小链路。

## 测试文件

源文件：

- `thesis_source/export_test.md`

输出文件：

- `exports/latest/test_export.docx`
- `exports/latest/test_export.pdf`

## 尝试命令

```powershell
pandoc --version
pandoc thesis_source/export_test.md -o exports/latest/test_export.docx
pandoc thesis_source/export_test.md -o exports/latest/test_export.pdf --pdf-engine=xelatex
```

本机 `pandoc` 未在当前 `PATH` 中直接可用，但已在以下位置找到可执行文件：

`C:\Users\UserX\AppData\Local\Microsoft\WinGet\Packages\JohnMacFarlane.Pandoc_Microsoft.Winget.Source_8wekyb3d8bbwe\pandoc-3.9.0.2\pandoc.exe`

## 生成结果

本次复测已直接使用已安装的 Pandoc 可执行文件重新生成 `docx` 和 `pdf` 测试导出文件。

## DOCX 是否成功

成功。

## PDF 是否成功

成功。

## 当前状态

`partially working`

说明：

- `pandoc` 裸命令在当前会话中仍未进入 `PATH`，但完整路径可正常调用。
- `docx` 复测成功。
- `pdf` 复测成功，但需要把 `TEMP`、`TMP` 和 `TMPDIR` 切到 ASCII 路径，并指定可用的中文字体 `Microsoft YaHei`，避免 XeLaTeX 在中文用户目录和默认字体下失败。

## 后续建议

- 在新终端会话里刷新 `PATH`，或把 Pandoc 安装路径固定进环境变量，避免每次都用完整路径。
- 如果 CI 要复用这个链路，建议把 Pandoc 调用和 PDF 字体参数封装到仓库脚本里。
- 如果后续要稳定输出中文 PDF，建议在导出脚本中固定 `Microsoft YaHei` 或等价字体，并把临时目录指向 ASCII 路径。
