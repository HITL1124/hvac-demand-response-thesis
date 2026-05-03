# Writing Workflow

## Core Flow

1. Web ChatGPT is used to discuss ideas, review drafts, test argument clarity, and surface revision suggestions.
2. The author confirms decisions on scope, structure, claims, and wording direction.
3. Codex applies the confirmed repository changes and updates the tracked Markdown sources or notes.
4. GitHub stores version history and supports branch-based review of meaningful changes.

## Source and Export Rules

- Markdown is the source of truth for thesis writing and project records.
- Word and PDF files are export artifacts for review, formatting checks, and submission packaging.
- Export files should not become the only location of updated content.

## Review Feedback Loop

- Review comments from Web ChatGPT or human reviewers must flow back into the Markdown source or project notes.
- If a review leads to a confirmed change in direction, record the decision in `notes/writing_decisions.md`.
- If a review materially changes the repository state or workflow, update `notes/change_log.md`.

## Operational Principle

- Discussion can happen anywhere.
- Confirmed decisions should be captured in the repository.
- Substantive writing should remain traceable through version control.
