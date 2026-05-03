# Project Guidance for Codex

## Project Identity

- Project: undergraduate thesis repository
- Thesis topic: Commercial Building HVAC Dynamic Demand Response
- Primary writing language for thesis content: Chinese
- Primary source format: Markdown
- Export formats: Word and PDF for review and submission

## Role Division

- Author:
  - owns all substantive academic decisions
  - confirms scope, claims, structure, and final wording direction
  - uploads source materials and approves important changes
- Web ChatGPT:
  - supports discussion, review, critique, and option generation
  - helps evaluate structure, wording, and argument quality
  - does not replace source control or repository execution
- Codex:
  - applies confirmed repository changes
  - organizes files, rules, notes, and source documents
  - maintains branch discipline and updates tracked project records
- GitHub:
  - stores version history
  - supports branch-based work and pull request review
  - acts as the audit trail for repository evolution

## Non-Fabrication Rules

Codex must not fabricate:

- data
- figures
- references
- experimental results
- simulation outputs
- citations
- academic claims
- literature conclusions

If information is missing, Codex should leave placeholders, templates, or explicit open questions instead of inventing content.

## Writing Boundaries

- Codex must not directly translate the IEEE TSTE paper into Chinese thesis text as a substitute for original thesis writing.
- Codex may help map, compare, summarize, or organize source materials when explicitly requested.
- Substantive thesis writing should happen inside `thesis_source/`.
- Project notes, process records, and writing decisions should live inside `notes/`.
- Notes should support writing, not silently become thesis text.

## Change Tracking Rules

- Important repository changes should update `notes/change_log.md`.
- Confirmed writing or structural decisions should be recorded in `notes/writing_decisions.md` when relevant.
- Review feedback from Web ChatGPT or human reviewers should be recorded in `notes/review_comments.md` when it affects future work.

## Branch and PR Policy

- Do not write directly on `main` for substantive writing or structure changes.
- Use focused branches for meaningful work units.
- Prefer pull requests for substantive writing tasks, large reorganizations, reference changes, figure selection changes, or workflow policy updates.
- Keep commits scoped and descriptive.
- Before merging substantive changes, ensure the Markdown source remains the authoritative content base.
