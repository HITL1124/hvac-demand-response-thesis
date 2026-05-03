# Change Log

## Entries

| Date | Branch | Change Summary | Reason | Files Affected | Follow-up Needed |
| --- | --- | --- | --- | --- | --- |
| 2026-05-03 | init/repository-structure | Initialized repository folders, project guidance, workflow notes, and placeholder tracking files. | Establish the base workflow and source organization before thesis drafting begins. | README.md; AGENTS.md; .gitignore; notes/; thesis_source/; references/; figures/; tables/; exports/; scripts/; requirements/; style_samples/; journal_paper/; research_materials/ | Upload school requirements, source paper materials, style samples, and verified research assets. |
| 2026-05-03 | test/export-chain-pandoc | Re-tested the Markdown -> Word/PDF export chain with the installed Pandoc binary. | Verify that Pandoc can be used to generate the test export files. | thesis_source/export_test.md; notes/export_chain_test.md; exports/latest/test_export.docx; exports/latest/test_export.pdf | If PATH is not refreshed in the current shell, use the full Pandoc path or open a new terminal session. PDF export also needs an ASCII temp directory and a Chinese-capable font such as Microsoft YaHei in this environment. |
