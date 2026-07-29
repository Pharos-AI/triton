# AGENTS.md

Guidance for AI coding agents (Cursor, Codex, Claude Code, Copilot, Windsurf, and others) working in this repository.

## Triton instrumentation skills

This repo ships an **agent-agnostic** set of instrumentation skills under [`agent-skills/`](agent-skills/README.md). They add production-grade Triton 2.0 logging to a Salesforce codebase — one file, a feature, or a whole org — always with a human-in-the-loop diff review before writing.

**When a user asks to "add Triton logging", "instrument" Apex/LWC/Flows, "audit logging coverage", "migrate to Triton 2.0", or "instrument the whole org", follow the matching skill file in [`agent-skills/`](agent-skills/) exactly.**

| Skill | File | Use when |
|-------|------|----------|
| instrument-apex | [`agent-skills/instrument-apex.md`](agent-skills/instrument-apex.md) | One Apex class/trigger. |
| instrument-lwc | [`agent-skills/instrument-lwc.md`](agent-skills/instrument-lwc.md) | One Lightning Web Component. |
| instrument-flows | [`agent-skills/instrument-flows.md`](agent-skills/instrument-flows.md) | One Flow's metadata XML. |
| instrument-org | [`agent-skills/instrument-org.md`](agent-skills/instrument-org.md) | A whole project / "instrument everything". |
| audit-logging | [`agent-skills/audit-logging.md`](agent-skills/audit-logging.md) | Read-only coverage & gap report. |
| migrate-to-2.0 | [`agent-skills/migrate-to-2.0.md`](agent-skills/migrate-to-2.0.md) | Convert 1.x `Triton.instance` code. |
| setup-standards | [`agent-skills/setup-standards.md`](agent-skills/setup-standards.md) | Wire CI guardrails + log-level config. |
| **the agent** | [`agent-skills/instrumentation-agent.md`](agent-skills/instrumentation-agent.md) | Run the full audit → migrate → instrument → guard sequence. |

Claude Code users get these as `/pharos:*` slash commands (see `.claude/commands/pharos/`), which forward to the same canonical files.

## Ground rules for these skills

- **Never write a file without showing the diff and getting a `yes` first.** `yes` / `modify` / `skip` on every change.
- Follow the Triton **2.0 static API** (`Triton.log` / `Triton.logNow`, builders from `Triton.t` / `Triton.makeBuilder()`); `Triton.instance` is the removed 1.x singleton.
- **Area is the primary grouping key** — reuse the Area already used by related code so a feature's logs group together. `.area(...)` accepts any String; enum values are examples.
- Do not change program behavior — only add logging (the one sanctioned exception is an optional `transactionId` param on an entry point, which must be flagged).
- Never instrument `@isTest` classes or managed-package code. Never log PII.
- On a large rollout, keep the human in the loop at batch boundaries and **defer** risky, low-comfort code rather than rewriting it.

See [`agent-skills/README.md`](agent-skills/README.md) for the full contract and how to invoke skills in each agent.
