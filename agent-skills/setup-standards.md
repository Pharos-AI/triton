---
name: setup-standards
summary: Scaffold CI guardrails (System.debug / Triton.instance checks), a PR review checklist, and Log_Level__mdt defaults so instrumentation doesn't regress. Tailors to the detected CI.
usage: setup-standards [--ci github|gitlab|bitbucket|generic] [--pmd] [--checklist] [--log-levels]
---

# Set Up Standards

Scaffold the guardrails that keep an instrumented codebase instrumented: the two hard CI rules, an optional PR review checklist, and optional `Log_Level__mdt` defaults. This writes **config** (CI files, templates, metadata), never application logging code.

> **Agent-agnostic skill.** Invoke it as your agent invokes skills (`/pharos:setup-standards`, an `@`-mentioned instruction, or a pasted prompt).

## Step 0 — Detect the environment

Detect the CI system from the repo unless `--ci` is given:
- `.github/workflows/` → `github`
- `.gitlab-ci.yml` → `gitlab`
- `bitbucket-pipelines.yml` → `bitbucket`
- otherwise → `generic` (emit a portable shell script the user can wire in)

Detect the Apex source root (default `force-app/main`) from `sfdx-project.json`.

## Step 1 — Parse arguments

- **`--ci`** — override the detected pipeline.
- **`--pmd`** — also emit PMD `RegexRule` entries (not just grep checks).
- **`--checklist`** — write the PR review checklist (e.g. `.github/pull_request_template.md`).
- **`--log-levels`** — scaffold `Log_Level__mdt` records with per-environment defaults.

## Step 2 — The two hard CI rules

Generate a check that fails the build on `System.debug` in application code and on any `Triton.instance` (removed 1.x singleton). As a grep-level check:

```bash
# Fail the build on System.debug in application code (tests excepted)
if grep -rn "System.debug" force-app/main --include=*.cls | grep -v "Test.cls"; then
  echo "❌ System.debug found — use Triton logging instead."
  exit 1
fi

# Fail on any lingering 1.x singleton usage
if grep -rn "Triton\.instance" force-app/main --include=*.cls; then
  echo "❌ Triton.instance is 1.x — migrate to the static API (Triton.log/Triton.t)."
  exit 1
fi
```

Wrap it in the detected CI's native format — e.g. for GitHub Actions, a `triton-standards` job in a workflow file; for GitLab, a job in `.gitlab-ci.yml`; for `generic`, a standalone `scripts/triton-standards.sh`.

With `--pmd`, also emit:

```xml
<rule name="NoSystemDebug" language="apex"
      message="Use Triton logging, not System.debug"
      class="net.sourceforge.pmd.lang.rule.regex.RegexRule" severity="3">
  <properties><property name="regex" value="System\.debug\s*\(" /></properties>
</rule>
<rule name="NoTritonInstance" language="apex"
      message="Triton.instance is the removed 1.x singleton — use the static API"
      class="net.sourceforge.pmd.lang.rule.regex.RegexRule" severity="3">
  <properties><property name="regex" value="Triton\.instance" /></properties>
</rule>
```

## Step 3 — Optional audit gate

Offer to add [`audit-logging`](audit-logging.md) as a gate so cleared areas stay clean:

```bash
# fails when catch-not-logged or System.debug findings are present
<agent> run skill audit-logging --format json --fail-on error,debug
```

Wire it into the same CI job. Explain that this turns standards into a one-way ratchet.

## Step 4 — Optional review checklist

With `--checklist`, write the short, actually-usable checklist as a PR template:

```markdown
### Triton logging review
- [ ] Template set; logs built from `Triton.t` (shared fields not repeated by hand)
- [ ] Category/Type/Area are enum values or intentional String constants — not ad-hoc strings
- [ ] `ERROR` only for genuine failures; loop chatter at `FINE` or below
- [ ] Exceptions logged with `.exception(e)` and published (`logNow` on failure paths), then rethrown
- [ ] Every buffering path flushes (end of handler/execute, or `finally`)
- [ ] Related objects on record logs; durations on trended work; sanitized payloads on callouts
- [ ] Cross-boundary work correlates a transaction; LWC passes the id (or uses cache)
- [ ] No `System.debug`, no `Triton.instance`
```

## Step 5 — Optional Log_Level__mdt defaults

With `--log-levels`, scaffold per-environment log-level custom metadata so verbosity is tuned by metadata, not code (quiet in production, verbose in a scratch org). Present the records and let the user confirm names/values before writing.

## Step 6 — Review & write

Show every file to be created/modified and its content, then `yes` / `modify` / `skip`. On `yes`, write the files. Do not modify existing CI jobs beyond adding the Triton check unless the user approves.

## Constraints

- Only automate checks with crisp true/false answers (`System.debug`, `Triton.instance`). Leave judgment calls (right Area? right level?) to the review checklist — do not emit brittle regexes that produce false positives (e.g. "every `makeBuilder()` near a `setTemplate()`").
- Never touch application logging code — this skill writes CI/config/metadata only.
- Exempt `*Test.cls` from the `System.debug` rule.
- Don't overwrite an existing PR template or CI job without showing the diff and getting approval.
