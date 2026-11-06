---
description: Scaffold CI guardrails, a PR review checklist, and Log_Level__mdt defaults for Triton logging. Usage: /pharos:setup-standards [--ci github|gitlab|bitbucket|generic] [--pmd] [--checklist] [--log-levels]
argument-hint: [--ci github|gitlab|bitbucket|generic] [--pmd] [--checklist] [--log-levels]
---

Read the canonical skill definition at `agent-skills/setup-standards.md` (relative to the repo root) and follow it **exactly**, start to finish.

Treat the following as the skill's arguments (flags): $ARGUMENTS

The canonical file is the single source of truth. This skill writes **CI/config/metadata only** — never application logging code. Only automate checks with crisp true/false answers (`System.debug`, `Triton.instance`); leave judgment calls to the review checklist. Show all files before writing (yes / modify / skip).
