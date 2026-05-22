---
description: Add Triton release/2.0 logging to a Salesforce Flow's metadata XML and deploy to the connected org. Usage:/pharos:instrument-flows <path-to-flow-meta-xml> [--area <Area>] [--level <Level>]
---

# pharos:instrument-flows

Insert Triton logging actions into a Salesforce Flow's metadata XML using
the `TritonFlow.log` invocable, then deploy the modified flow to the
connected org. Follows the Pharos best practices: every fault path
instrumented at ERROR, flow entry logged at INFO, transaction IDs
propagated when available, and `interviewGUID` set everywhere for
correlation. This skill targets the **release/2.0 Triton API**.

## Step 0 — Load shared context, then check prerequisites

**Always read `../_triton-context.md` first** (the shared Triton API
reference, one directory up from this skill). It is the source of truth
for the `TritonFlow.log` invocable signature, the `FlowLog` /
`FlowLogOutput` parameters, valid enum members, and the cross-context
transaction-propagation rules. Treat anything here that contradicts it
as an error in this file.

Then run the shared CLI guard (same as the other skills):

```bash
sf --version >/dev/null 2>&1 || sfdx --version >/dev/null 2>&1
sf org display --json 2>&1 || sfdx force:org:display --json 2>&1
```

- No CLI → stop: "Install the Salesforce CLI from
  https://developer.salesforce.com/tools/salesforcecli, then re-run."
- No default org → stop: "Run `sf org login web` and `sf config set
  target-org <alias>`, then re-run."

**Flow-specific extra: verify Triton is installed in the target org.** The
flow will reference `TritonFlow` as an Apex action and the action must
exist in the org at deploy time.

```bash
sf apex run --target-org "$(sf config get target-org --json | jq -r '.result[0].value')" \
   --code "System.debug(TritonTypes.Level.ERROR); System.debug(TritonFlow.class);" --json
```

If this fails with a type-resolution error, stop and tell the user:
> "Triton is not installed in the connected org. Install the Triton
> managed package (or deploy the release/2.0 unmanaged source) before
> re-running this skill."

## Step 1 — Parse arguments

- **Flow XML path** (required) — a `.flow-meta.xml` file. If missing,
  ask: "Which Flow metadata file do you want to instrument?"
- **`--area`** — a `TritonTypes.Area` enum name (`OpportunityManagement`,
  `LeadConversion`, `Accounts`, `Community`, `RestAPI`, `LWC`, `Flow`)
  or any custom string. Default: infer from flow API name (see Step 2).
- **`--level`** — default level for informational checkpoints (start,
  record-op success, subflow boundary). Default: `INFO`. Fault paths
  always use `ERROR` regardless.

## Step 2 — Read and analyse the Flow XML

Read the file. Parse the structure and catalogue:

1. **Flow type** — `<processType>` value: `Flow`, `AutoLaunchedFlow`,
   `ScreenFlow`, `Workflow`, `InvocableProcess`, etc.
2. **API version** — `<apiVersion>` (preserve when writing back).
3. **Flow API name** — the file name without `.flow-meta.xml`.
4. **All addressable elements** — every child of `Flow` that has a `<name>`:
   `<actionCalls>`, `<assignments>`, `<decisions>`, `<loops>`,
   `<recordCreates>`, `<recordDeletes>`, `<recordLookups>`,
   `<recordUpdates>`, `<screens>`, `<subflows>`, `<waits>`,
   `<apexPluginCalls>`.
5. **Fault-capable elements** — the subset above that *can* fault and
   therefore needs a `<faultConnector>`:
   `<recordCreates>`, `<recordUpdates>`, `<recordDeletes>`,
   `<recordLookups>`, `<actionCalls>` (other than existing TritonFlow
   actions), `<subflows>`, `<waits>`, `<apexPluginCalls>`.
   Note any of these that already have a `<faultConnector>` — those
   target an existing recovery path and the Triton action must be
   inserted **between** the source element and the prior fault target.
6. **Start element** — `<start>` and its first `<connector><targetReference>`.
7. **Existing Triton actions** — search for
   `<actionCalls>` whose `<actionName>` is `TritonFlow`. Skip
   re-instrumenting elements that already feed into one of these.
8. **Existing transaction-ID variable** — search `<variables>` for one
   with `isInput=true` whose name contains `transactionId` (case
   insensitive). Reuse if found; otherwise we add `TritonTransactionId`.
9. **Existing stack-trace variables** — search for `<variables>` named
   `Triton_StackTrace` / `Triton_FullStackTrace`. Add them if missing.

**Area inference from the Flow API name** (case-insensitive substring),
when `--area` was not provided:

- contains `Opportunity` / `Quote` / `Order` → `OpportunityManagement`
- contains `Lead` → `LeadConversion`
- contains `Account` / `Contact` → `Accounts`
- contains `Community` / `Portal` → `Community`
- contains `Rest` / `Api` / `Callout` → `RestAPI`
- otherwise → pass the Flow API name as a string

Summarise the flow (one short paragraph: process type, element counts,
fault-capable elements found vs. already-faulted, whether transaction-ID
variable exists, existing Triton actions count) before applying
instrumentation.

## Step 3 — Insert Triton actions and variables

`TritonFlow.log` flushes nothing immediately — it drains buffered logs
into `TritonFlowFlushBatch`, a singleton-checked batch with a 1-minute
delay, so the same job ID handles concurrent flows and platform-event
allocations stay low. Skill output should never recommend a manual flush.

Every Triton action call has this base shape. Use named input parameters
on the invocable — there is no helper SObject wrapper variable to build.

```xml
<actionCalls>
    <name>Triton_Log_<Suffix></name>
    <label>Triton Log — <Human readable></label>
    <locationX>50</locationX>
    <locationY><computed></locationY>
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
        <value><stringValue><one-line summary></stringValue></value>
    </inputParameters>
    <inputParameters>
        <name>interviewGUID</name>
        <value><elementReference>$Flow.InterviewGuid</elementReference></value>
    </inputParameters>
    <inputParameters>
        <name>flowApiName</name>
        <value><stringValue><flow API name></stringValue></value>
    </inputParameters>
    <inputParameters>
        <name>level</name>
        <value><stringValue><INFO|DEBUG|WARNING|ERROR></stringValue></value>
    </inputParameters>
    <!-- `details` (optional): for fault logs, set to $Flow.FaultMessage as shown below;
         for other logs, omit, or use a literal via <stringValue>...</stringValue>. -->
    <inputParameters>
        <name>details</name>
        <value><elementReference>$Flow.FaultMessage</elementReference></value>
    </inputParameters>
    <inputParameters>
        <name>transactionId</name>
        <value><elementReference>TritonTransactionId</elementReference></value>
    </inputParameters>
    <inputParameters>
        <name>fullStacktrace</name>
        <value><elementReference>Triton_FullStackTrace</elementReference></value>
    </inputParameters>
    <outputParameters>
        <assignToReference>Triton_StackTrace</assignToReference>
        <name>stacktrace</name>
    </outputParameters>
    <outputParameters>
        <assignToReference>Triton_FullStackTrace</assignToReference>
        <name>fullStacktrace</name>
    </outputParameters>
</actionCalls>
```

Notes that apply to every insertion:
- `$Flow.InterviewGuid` is **required** by `TritonFlow.log` —
  `_triton-context.md` lists it as a required `FlowLog` parameter.
- `level=ERROR` automatically triggers `createIssue()` on the resulting
  log — do not also try to set it.
- Always wire the two `<outputParameters>` so the stack trace
  accumulates across actions: each action's `fullStacktrace` input
  feeds from the previous action's output of the same name.
- Preserve element ordering: Flow XML is alphabetical at the top level
  (`<actionCalls>` before `<assignments>` before `<decisions>` …),
  and elements of the same type are also alphabetised by `<name>`.
  Insert the new elements in their correct sorted positions.
- Pick `locationX`/`locationY` values that don't overlap existing
  elements. A safe default is to set `locationX` 200 units to the right
  of the source element and `locationY` 50–100 units below.

### 3a — Add tracking variables

If they do not already exist, add to the `<variables>` collection:

```xml
<variables>
    <name>Triton_StackTrace</name>
    <dataType>String</dataType>
    <isCollection>false</isCollection>
    <isInput>false</isInput>
    <isOutput>false</isOutput>
</variables>
<variables>
    <name>Triton_FullStackTrace</name>
    <dataType>String</dataType>
    <isCollection>false</isCollection>
    <isInput>false</isInput>
    <isOutput>false</isOutput>
</variables>
```

If no input transaction-ID variable was found in Step 2, also add:

```xml
<variables>
    <name>TritonTransactionId</name>
    <dataType>String</dataType>
    <isCollection>false</isCollection>
    <isInput>true</isInput>
    <isOutput>false</isOutput>
</variables>
```

When an existing input variable already carries the transaction ID,
reuse its name in every `transactionId` input parameter — do not add a
duplicate.

### 3b — Flow entry log

Insert a `Triton_Log_Start` action between `<start>` and its current
target, then rewrite the start connector to point at the new action.

- `area` → resolved area (string literal)
- `summary` → `Flow started: <flowApiName>` (string literal)
- `level` → value of `--level` (default `INFO`)
- `flowApiName` → the Flow API name
- `interviewGUID` → `$Flow.InterviewGuid` (elementReference)
- `transactionId` → `TritonTransactionId` (or the reused input variable)

### 3c — Fault path log on every fault-capable element

For every fault-capable element (Step 2 catalogue) that does **not**
already have a downstream Triton action on its fault path, insert a
`Triton_Log_<ElementName>_Fault` action and wire it:

1. Add the new action with:
   - `summary` → `<ElementName> fault` (string literal)
   - `details` → `$Flow.FaultMessage` (elementReference)
   - `level` → `ERROR`
   - `interviewGUID` → `$Flow.InterviewGuid`
   - `flowApiName` → the Flow API name
   - `fullStacktrace` → `Triton_FullStackTrace` (elementReference)
   - `transactionId` → as in 3b
   - `outputParameters` → assign `stacktrace` →
     `Triton_StackTrace` and `fullStacktrace` →
     `Triton_FullStackTrace`.

2. If the source element previously had no `<faultConnector>`, leave the
   new action with no `<connector>` (the fault path ends there) and add:

   ```xml
   <faultConnector>
       <targetReference>Triton_Log_<ElementName>_Fault</targetReference>
   </faultConnector>
   ```

   to the source element.

3. If the source element **already** had a `<faultConnector>`, splice the
   new action between source and prior target:
   - The new action's `<connector><targetReference>` points at the prior
     fault target.
   - The source element's `<faultConnector><targetReference>` is rewritten
     to point at the new action.

This is the most critical instrumentation — without it, Pharos cannot
surface unhandled Flow errors.

### 3d — Decision negative-branch logging (optional, low-noise)

For each `<decisions>` element, identify branches whose `<rules>` name or
`<label>` matches an error/empty/negative pattern (case-insensitive: `fail`,
`error`, `empty`, `none`, `invalid`, `not_found`, `no_*`). On the negative
branch, insert a `Triton_Log_<Decision>_<Rule>` action between the
decision and the rule's current target, then rewire the rule's
`<connector><targetReference>` to the new action:

- `summary` → `<DecisionName> hit <RuleName>` (string literal)
- `level` → `WARNING`
- everything else as in 3b

Keep positive-path / default branches uninstrumented (low noise).

### 3e — Record operation success logging (low-noise)

After each `<recordCreates>`, `<recordUpdates>`, `<recordDeletes>` happy
path (not the fault path), if the user wants visibility into successful
DML in this flow, insert a `Triton_Log_<ElementName>_Done` between the
record op and its current `<connector>` target. Wire it the same way as
3b. Use:

- `summary` → `<OperationType> completed — <ObjectApiName>` (string literal)
- `level` → `DEBUG`
- `details` → include any output count if the record op exposes one

This is opt-in noise — only emit it when `--level` is `DEBUG` or lower,
otherwise the cost outweighs the value.

### 3f — Subflow boundary logging

Before each `<subflows>` element, insert a `Triton_Log_<Subflow>_Call`
with:

- `summary` → `Calling subflow: <subflow API name>` (string literal)
- `level` → `INFO`
- everything else as in 3b

This makes cross-flow tracing visible in the Pharos UI.

### 3g — Transaction ID propagation

Every Triton action inserted above must include the `transactionId` input
parameter wired to the in-scope transaction variable (the existing input
variable from Step 2, or the new `TritonTransactionId` from 3a). The
calling Apex / LWC populates this variable when starting the flow; if the
flow is launched standalone, the variable is empty and `TritonFlow.log`
generates a fresh transaction ID server-side.

## Step 4 — Review diff with the user

Present a compact summary and a few representative XML snippets.

```
## Instrumentation changes for <FlowApiName>

### Summary
- Flow type: <processType>, API version <apiVersion>
- Flow entry action added: <yes/no>
- Fault actions added: N (M elements already had fault connectors and were rewired)
- Decision negative-branch warnings added: N
- Record-op success debug logs added: N (only when --level=DEBUG)
- Subflow boundary infos added: N
- Tracking variables added: Triton_StackTrace, Triton_FullStackTrace
- Transaction ID variable: <added TritonTransactionId | reused <existing var>>
- Flush behaviour: deferred via TritonFlowFlushBatch (no manual flush wired)

### Key changes
[show: the new <variables> block; the flow entry actionCalls block;
 one fault-path actionCalls block + the matching <faultConnector> rewrite]

Apply? (yes / modify / skip)
```

On "modify": accept the correction and re-apply before asking again.
On "skip": stop without writing.

## Step 5 — Write the instrumented file

Write the modified XML back to the original `.flow-meta.xml` path.

- Preserve the existing two-space indentation and the alphabetical
  ordering of element types at the top level.
- Preserve `<apiVersion>`, `<status>` (`Active` / `Draft` /
  `Obsolete`), `<interviewLabel>`, `<label>`, all `<processMetadataValues>`,
  and the `<start>` element's `locationX`/`locationY`.
- Do not touch elements that were not part of the instrumentation —
  this is a surgical edit, not a reformat.

## Step 6 — Deploy (mandatory; doubles as compile-check)

Deployment is **not optional** — it validates the modified Flow XML
against the target org's Flow schema, confirms `TritonFlow` resolves as
an invocable action, and surfaces any structural mistakes (orphan
connectors, missing required input parameters, unknown element
references). Always run it after the user accepts the diff in Step 4.
Do not ask for permission.

```bash
sf project deploy start --source-dir <path-to-flow-meta-xml> --json
# or
sfdx force:source:deploy -p <path-to-flow-meta-xml> --json
```

Parse the JSON result:

- `"status": "Succeeded"` → report "Flow `<FlowApiName>` deployed
  successfully. Activation needed — see note below."
- Any component failure → enter the **repair loop** below.

### Repair loop

The deploy failure messages are your validation feedback. Common roots:

- A `<connector><targetReference>` points at an element that doesn't
  exist (typically a typo in the new Triton action's `<name>`, or a
  fault-connector rewrite that lost track of the prior target).
- A required `FlowLog` input parameter is missing on a new Triton action
  (`area`, `summary`, and `interviewGUID` are required — see
  `../_triton-context.md`'s *FlowLog input parameters* table).
- An `<elementReference>` value points at a variable that does not exist
  (e.g. `Triton_FullStackTrace` was referenced but the matching
  `<variables>` block was not added).
- Top-level element ordering is wrong — Salesforce's deploy is lenient
  here but strict ordering helps reviewability; not usually a deploy
  blocker.
- A duplicate `<name>` across two new actions.

Steps:

1. Print the component failure table (file, line, error message).
2. Analyse each error against the original Flow XML and
   `../_triton-context.md`. If an error says an element or variable
   reference is invalid, the fix is in the instrumentation you just
   inserted — not in the original flow.
3. Make a focused edit to the `.flow-meta.xml`. Do not revert unrelated
   lines; do not remove any pre-existing flow element.
4. Redeploy once.

If the second deploy still fails, **stop**. Print the remaining
failures and tell the user: "Deploy is still failing after one repair
pass. Review the errors above; the flow XML is left in place so you
can hand-edit before re-running the deploy command."

**Activation reminder:** deploying a flow creates a new version in the
org and that new version is in `Draft` state unless the source's
`<status>` was already `Active` and Salesforce allows the version to
deploy active. Tell the user:

> "The new Flow version may be in Draft. Go to Setup → Flows →
> `<FlowApiName>` and activate the latest version to put it live.
> Logs from `TritonFlow.log` will appear in Pharos within ~1 minute
> of the flow running (the `TritonFlowFlushBatch` job delay)."

## Constraints

- Always set `interviewGUID` to `$Flow.InterviewGuid` on every Triton
  action — without it, Pharos cannot correlate logs from this flow run.
- Always instrument fault connectors on record CRUD elements,
  `<actionCalls>` (other than Triton itself), `<subflows>`, `<waits>`,
  and `<apexPluginCalls>`. This is non-negotiable for production
  visibility.
- Never remove or rename existing flow elements / variables. Only insert
  new elements and rewire connectors that point at the new actions.
- Never insert Triton actions inside a `<loops>` element. Log before and
  after the loop, never per iteration — each invocation buffers Org
  Cache memory and stresses the deferred flush batch.
- Never set `level=ERROR` on happy-path logs. Reserve it for fault paths
  and confirmed-negative decision branches. The server-side
  `TritonFlow.log` automatically calls `createIssue()` when level is
  `ERROR` — extra invocations create noise in Pharos issue tracking.
- Never duplicate a Triton action — check Step 2's catalogue for
  existing `<actionName>TritonFlow</actionName>` blocks before
  inserting.
- Never add a manual `flush`/`stopTransaction` step after a Triton
  action — `TritonFlow.log` defers to `TritonFlowFlushBatch`
  automatically. Adding extra steps is redundant and confuses the
  deferred batching contract.
- Preserve the alphabetical order of element types at the top level
  (`<actionCalls>` → `<assignments>` → `<decisions>` →
  `<recordLookups>` → `<recordUpdates>` → `<screens>` → `<start>` →
  `<variables>`) and within each type by `<name>`.
- Never log PII inside `details` or `summary` (passwords, tokens,
  session IDs, full SSNs, credit-card numbers). If a Flow variable
  carries one, leave the input parameter unset and add a comment for
  the reviewer.
