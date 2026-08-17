---
name: instrument-flows
summary: Add Triton Log actions to a Salesforce Flow's metadata XML, then optionally deploy.
usage: instrument-flows <path-to-flow-xml> [--area <Area>] [--level <Level>] [--deploy]
---

# Instrument Flows

Add Triton logging action calls to a Salesforce Flow's metadata XML, following Pharos best practices, then optionally deploy to the connected Salesforce org.

> **Agent-agnostic skill.** Run it however your agent invokes skills — a slash command (`/pharos:instrument-flows <path>`), an `@`-mentioned instruction, or a pasted prompt. The steps are identical regardless.

> **API note:** Flow logging calls the `TritonFlow` invocable (Apex action, Label "Log") with **individual named String inputs** — the log record is built in Apex; the Flow supplies primitive inputs only. Required inputs: **`area`**, **`summary`**, **`interviewGUID`**.

## Step 0 — Prerequisites check

```bash
which sf || which sfdx
```

If neither found → stop:
> "This skill requires the Salesforce CLI (`sf` or `sfdx`). Install it from https://developer.salesforce.com/tools/salesforcecli, then re-run."

```bash
sf org display --json 2>&1 || sfdx force:org:display --json 2>&1
```

If no default org → stop:
> "No default Salesforce org connected. Run `sf org login web` and `sf config set target-org <alias>`, then re-run."

Verify Triton is installed in the target org (the `TritonFlow` invocable must exist):

```bash
sf apex run --target-org <defaultOrg> --code "System.debug(TritonTypes.Level.ERROR);" --json
```

If this fails with a type error → stop:
> "Triton is not installed in the connected org. Deploy the Triton package first, then re-run."

## Step 1 — Parse arguments

- **Flow XML path** — the `.flow-meta.xml` file (required). If not provided, ask.
- **`--area`** — the business/functional area (a free String, required on every log action). **Infer it from the flow's purpose and keep it consistent with related code** — reuse the area used by the LWC/Apex that invokes this flow, or by related flows (below). The examples below are illustrative, not a required mapping.
- **`--level`** — default level for informational checkpoints. Default: `INFO`. Fault paths always use `ERROR`.
- **`--deploy`** — deploy after instrumentation.

**Choosing the Area (give this special attention).** Area is the primary grouping/search key and is a free String on the invocable, so infer it from the flow's business domain and, above all, **match what related code uses**:
- If an LWC/Apex invokes this flow and already sets an Area, reuse that exact value so the whole transaction groups together.
- Otherwise reuse the Area of related flows in the same domain, or derive one from the flow's purpose.
- Standard values (`OpportunityManagement`, `Accounts`, …) are only examples — don't force the flow into one when a domain-specific value is clearer.

## Step 2 — Read and parse the Flow XML

Read the file. Parse the structure to identify:

1. **Flow type** — `<processType>` (`Flow`, `AutoLaunchedFlow`, etc.) — used to set the optional `type` input.
2. **All elements** — every `<actionCalls>`, `<assignments>`, `<decisions>`, `<loops>`, `<recordCreates>`, `<recordDeletes>`, `<recordLookups>`, `<recordUpdates>`, `<screens>`, `<subflows>`, `<waits>` with their `<name>` values.
3. **Fault connectors** — elements with a `<faultConnector>` child (these need an ERROR log on the fault path).
4. **Start element** — the `<start>` node's first target (log flow entry here).
5. **Transaction input** — whether the flow already declares an input variable for a transaction id (to stitch into an LWC/Apex transaction).
6. **Existing Triton actions** — search for `<actionName>TritonFlow</actionName>` and skip re-instrumenting those elements.

Summarize the flow structure (type, element counts, fault paths) to the user, then proceed.

## Step 3 — Instrument the Flow XML

Each logging point is a single `<actionCalls>` element referencing the `TritonFlow` invocable. **Pass each field as its own `<inputParameters>`** — do not build a record or a collection.

**Real invocable inputs** (from `TritonFlow.FlowLog`):

| Input | Required | Notes |
|-------|----------|-------|
| `area` | **yes** | Area string |
| `summary` | **yes** | Log summary |
| `interviewGUID` | **yes** | Always `{!$Flow.InterviewGuid}` (exact casing: `interviewGUID`) |
| `category` | no | Recommend `Flow` (invalid values fall back to `Flow`) |
| `type` | no | From `<processType>` (e.g. `Screen Flow`, `Autolaunched Flow`) |
| `level` | no | `INFO`/`DEBUG`/`WARNING`/`ERROR` string; defaults to `INFO` |
| `details` | no | Additional context |
| `operation` | no | Operation name |
| `flowApiName` | no | The **plain** flow API name — never append a `-<version>` suffix |
| `flowVersion` | no | Numeric flow version as a string (e.g. `4`); pairs with the plain `flowApiName`, matching native flow error logs |
| `transactionId` | no | Stitch into an existing transaction (Step 3f) |
| `additionalFields` | no | JSON string → arbitrary `pharos__Log__c` fields |
| `stacktrace` / `fullStacktrace` | no | Carry-through inputs for chaining fault context |

**Outputs:** `fullStacktrace` (populated) and `stacktrace` (**always null — do not rely on it**). To chain, assign `fullStacktrace` to a variable and pass it as the `fullStacktrace` **input** of a later action.

### Canonical log-action template

```xml
<actionCalls>
    <name>Triton_Log_<SuffixDescribingLocation></name>
    <label>Triton Log — <Human Readable Label></label>
    <locationX>50</locationX>
    <locationY><computed-y-position></locationY>
    <actionName>TritonFlow</actionName>
    <actionType>apex</actionType>
    <connector>
        <targetReference><nextElementName></targetReference>
    </connector>
    <inputParameters>
        <name>area</name>
        <value><stringValue><area></stringValue></value>
    </inputParameters>
    <inputParameters>
        <name>summary</name>
        <value><stringValue><summary text></stringValue></value>
    </inputParameters>
    <inputParameters>
        <name>interviewGUID</name>
        <value><elementReference>$Flow.InterviewGuid</elementReference></value>
    </inputParameters>
    <inputParameters>
        <name>category</name>
        <value><stringValue>Flow</stringValue></value>
    </inputParameters>
    <inputParameters>
        <name>flowApiName</name>
        <value><stringValue><FlowApiName></stringValue></value>
    </inputParameters>
    <inputParameters>
        <name>flowVersion</name>
        <value><stringValue><FlowVersionNumber></stringValue></value>
    </inputParameters>
    <inputParameters>
        <name>level</name>
        <value><stringValue>INFO</stringValue></value>
    </inputParameters>
</actionCalls>
```

Every log action must include the three required inputs (`area`, `summary`, `interviewGUID`). The sections below list the additional per-location inputs.

Pass the plain API name in `flowApiName` and the version separately in `flowVersion` (omit it when unknown). Version-suffixed names like `My_Flow-4` are a legacy artifact — the log-level engine tolerates them, but new instrumentation must not emit them.

### 3a — Flow entry logging

After the `<start>` connector's first target element, insert a log:
- `summary` → `Flow started: <FlowApiName>`
- `level` → `INFO` (or `--level`)

### 3b — Decision branch logging (WARNING paths)

For `<decisions>` outcomes representing error states, empty results, or negative branches, insert a log on that outcome path with `level=WARNING`. Keep happy-path branches at `DEBUG` (low noise).

### 3c — Fault path logging (most critical)

For every element with a `<faultConnector>`, insert a log as the first element on the fault path:
- `summary` → `<ElementName> fault`
- `details` → `{!$Flow.FaultMessage}` (via `<elementReference>$Flow.FaultMessage</elementReference>`)
- `level` → `ERROR` (auto-creates a Pharos issue)
- `fullStacktrace` → carry through from a prior action's output variable if one is set

Fault logs are how Pharos surfaces unhandled Flow errors — instrument **every** fault connector.

### 3d — Record operation logging

After `<recordCreates>`, `<recordUpdates>`, `<recordDeletes>` (success paths), add a log:
- `summary` → `<OperationType> completed — <ObjectApiName>`
- `operation` → `<OperationType>`
- `level` → `DEBUG`
- `details` → record-count reference if available

### 3e — Subflow boundary logging

Before each `<subflows>` element, add an INFO log:
- `summary` → `Calling subflow: <SubflowLabel>`
- `level` → `INFO`

### 3f — Transaction id propagation (stitching)

To tie this Flow into an existing LWC/Apex transaction, pass the id as the `transactionId` input on **every** log action:

If the flow already has a transaction-id input variable, reference it:
```xml
<inputParameters>
    <name>transactionId</name>
    <value><elementReference><TransactionIdVariable></elementReference></value>
</inputParameters>
```

If none exists and the flow is invoked from Apex/LWC, add an input variable and pass it:
```xml
<variables>
    <name>TritonTransactionId</name>
    <dataType>String</dataType>
    <isCollection>false</isCollection>
    <isInput>true</isInput>
    <isOutput>false</isOutput>
</variables>
```

(If no transaction id is supplied, `TritonFlow` starts/uses one automatically and correlates via the Interview GUID — so `transactionId` is optional.)

> ⚠️ **When this Flow is stitched from an LWC `@wire`, the id must arrive as the explicit `transactionId` input** — pass it into the flow (from the LWC or the invoking Apex) and reference it here. `@wire` calls cacheable Apex, which is read-only for Platform Cache, so a cache-based stitch (`withCache()`) can't carry the id into this flow. Cacheable Apex / `@wire` can't use Platform Cache for stitching — pass `transactionId` explicitly. See https://resources.pharos.ai/wire-cache-antipattern

### 3g — Data richness by level (attach more the more severe it is)

**Per-log payload richness scales inverse to severity** — independent of how *often* a level fires. In Flows the richness knobs are the `details` input and `additionalFields` (a JSON string mapping to arbitrary `pharos__Log__c` fields). Match what you attach to the level:

| Level | Per-log data |
|-------|--------------|
| **ERROR / WARNING / INFO** | **Maximum.** Put full context in `details` (`{!$Flow.FaultMessage}` on faults, plus the relevant flow variable values), and add an `additionalFields` JSON input carrying the key record ids / field values in scope at that point. |
| **DEBUG** | **Reduced.** A short `summary` and one or two variable values in `details`. No `additionalFields` dump. |
| **FINER / FINEST equivalents** | Not typical in Flows — keep low-level checkpoints terse (summary only). |

Example `additionalFields` input on an ERROR fault log (JSON string; reference flow variables via a formula/text template resource if the values are dynamic):

```xml
<inputParameters>
    <name>additionalFields</name>
    <value><elementReference>Triton_AdditionalFields_JSON</elementReference></value>
</inputParameters>
```

**Be more granular.** Verbosity is runtime-tunable via `Log_Level__mdt`, so add *more* DEBUG checkpoints than you otherwise would — but keep each lean. Runtime filtering, not sparse payloads, keeps production quiet.

**PII carve-out.** Never place secrets or PII (passwords, tokens, SSNs, card numbers) into `details` or `additionalFields`. Omit those fields; this overrides the "attach maximum data" rule every time.

## Step 4 — Review diff with user

```
## Instrumentation changes for <FlowApiName>

### Summary
- Flow entry log added (INFO)
- N fault paths instrumented (ERROR)
- N decision negative branches instrumented (WARNING)
- N record operations logged (DEBUG)
- N subflow calls logged (INFO)
- category=Flow / type=<from processType> set on log actions
- Transaction id input: <existing var | TritonTransactionId added | none>

### Key changes
[Show: flow entry action XML, one fault path action XML]

Apply? (yes / modify / skip)
```

On "modify": adjust and re-present. On "skip": stop without writing.

## Step 5 — Write the instrumented file

Write the modified XML back to the original `.flow-meta.xml` path. Preserve all existing indentation and XML structure.

## Step 6 — Deploy

If `--deploy` not passed, ask: "Deploy to org now? (yes / no)"

On yes:

```bash
sf project deploy start --source-dir <path-to-flow-xml> --json
```

Or:
```bash
sfdx force:source:deploy -p <path-to-flow-xml> --json
```

Parse result:
- `"status": "Succeeded"` → "Flow `<FlowApiName>` deployed successfully."
- Errors → show failures. Do not revert the file.

**Note on activation:** deploying a Flow creates a new version in Draft state. Remind the user:
> "The new Flow version is in Draft. Go to Setup → Flows → `<FlowApiName>` → Activate to put it live."

## Constraints

- Call the `TritonFlow` invocable with **individual named inputs** — never a `flowLogs` collection, never a `pharos__Log__c` / SObject record (those inputs do not exist and the Flow won't save/deploy).
- Every log action must include the required inputs: `area`, `summary`, and `interviewGUID` (= `{!$Flow.InterviewGuid}`, exact casing `interviewGUID`).
- `area` is a free String — infer it and keep it consistent with the area used by related code (invoking LWC/Apex or related flows). Keep `category` standard (`Flow`).
- Never remove existing Flow elements or connectors — only insert new `<actionCalls>`.
- Always instrument fault connectors with an `ERROR` log — non-negotiable for production visibility.
- Never add Triton logs inside Loop elements (log before/after the loop, not per iteration).
- Do not duplicate Triton actions on elements already instrumented (check for existing `<actionName>TritonFlow</actionName>`).
- Reserve `ERROR` for fault paths and genuine failure branches — never on happy-path logs.
- **Scale per-log data to level (§3g):** ERROR/WARNING/INFO carry rich `details` + `additionalFields`; DEBUG stays a short summary with one or two values. The PII carve-out always wins over "attach maximum data."
- **When stitching from an LWC `@wire`, the id must come via the explicit `transactionId` input**, not a cache-based stitch (cacheable Apex is read-only for Platform Cache). See https://resources.pharos.ai/wire-cache-antipattern
- Do not rely on the `stacktrace` output (always null); chain via `fullStacktrace`.
