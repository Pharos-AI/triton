# Triton Instrumentation Skills

Agent-agnostic skills that add production-grade [Triton](https://github.com/Pharos-AI/triton) logging to a Salesforce codebase — one file, a whole feature, or an entire org — with a human-in-the-loop diff review and an optional deploy.

These are the **canonical, portable definitions**. They are plain Markdown playbooks with no dependency on any particular coding agent. Each per-technology skill classifies the code, applies the Triton 2.0 static-API conventions, shows you a diff, and only writes on your approval.

> **Companion tooling, not part of the managed package.** These skills ship *alongside* Triton as developer tooling; they are not deployed into an org. They generate code that targets the Triton 2.0 static API.

## The catalog

| Skill | Purpose |
|-------|---------|
| [`instrument-apex`](instrument-apex.md) | Instrument an Apex class or trigger. |
| [`instrument-lwc`](instrument-lwc.md) | Instrument a Lightning Web Component. |
| [`instrument-flows`](instrument-flows.md) | Instrument a Flow's metadata XML. |
| [`instrument-org`](instrument-org.md) | Orchestrate the three across a whole project/org. |
| [`audit-logging`](audit-logging.md) | Read-only coverage & gap report (writes nothing). |
| [`migrate-to-2.0`](migrate-to-2.0.md) | Convert 1.x singleton code to the 2.0 static API. |
| [`setup-standards`](setup-standards.md) | Scaffold CI guardrails and `Log_Level__mdt` config. |
| [`instrumentation-agent`](instrumentation-agent.md) | The persona that runs the whole catalog end to end. |

## Running a skill in your agent

The behavior is identical everywhere; only the invocation differs.

| Agent | How to run |
|-------|-----------|
| **Claude Code** | Slash commands in `.claude/commands/pharos/` forward to these files, e.g. `/pharos:instrument-apex <path>`. |
| **Cursor** | `@`-mention the skill file (or add it as a Command/Rule) and give it the path; the root [`AGENTS.md`](../AGENTS.md) points here. |
| **GitHub Copilot** | Reference the skill file in your prompt, or add it to `.github/copilot-instructions.md`. |
| **Codex CLI / others** | The root [`AGENTS.md`](../AGENTS.md) describes the persona; point the agent at the skill file and the target path. |
| **Any agent** | Paste the skill's contents plus the target file and ask it to apply them. The diff-review step still applies. |

Throughout these files, the `/pharos:instrument-*` form is a concise stand-in for "run this skill." Substitute your agent's own invocation.

## The shared contract

Every per-file skill follows the same loop:

1. **Prerequisites** — Salesforce CLI (`sf`/`sfdx`) installed and a default org connected (the Flow skill also verifies Triton is in the org).
2. **Parse arguments** — target path plus optional flags; ask for anything required and missing.
3. **Analyze** — read and classify the file's structure (the transaction/flush pattern depends on it) and infer the **Area**.
4. **Apply** — generate the instrumented version in memory using the Triton 2.0 static API.
5. **Review** — present a summary and diff; `yes` / `modify` / `skip`.
6. **Write** — on `yes`, write back to the **original** file (no new files).
7. **Deploy (optional)** — with `--deploy` or on confirmation, `sf project deploy start` the touched path.

**Area is the primary grouping key in Pharos.** Every skill reuses the Area already used by *related* code (same-object trigger, paired controller, the LWC/Flow on the other side of a call) so a feature's logs group together. `.area(...)` accepts any String; the `TritonTypes.Area` enum values are examples, not a required mapping.

**Two cross-cutting rules every skill enforces:**

- **Cacheable / `@wire` stitching never uses Platform Cache.** `@AuraEnabled(Cacheable=true)` Apex (what `@wire` calls) is read-only for Platform Cache, so `Triton.withCache()` can't carry a transaction id there — the stitch silently breaks. Those call chains always pass `transactionId` explicitly and `resumeTransaction(...)` on the server. See https://resources.pharos.ai/wire-cache-antipattern
- **Per-log data richness scales inverse to severity.** ERROR/WARNING/INFO carry maximum forensic context — serialized inputs/state (PII-stripped) plus every related id; DEBUG carries named values only; FINE/FINER/FINEST stay terse markers. This is decoupled from event frequency: instrument *more* low-level tracing points (verbosity is runtime-tunable via `Log_Level__mdt`) but keep each such log lean.

See the individual files for the per-technology detail, and [`instrumentation-agent.md`](instrumentation-agent.md) for running the whole thing as one persona.
