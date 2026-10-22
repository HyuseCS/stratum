# Feature Specification: Codex Advisor

**Feature Branch**: `18-codex-advisor`

**Created**: 2026-10-23

**Status**: Draft

**Input**: User description: "Fix GitHub issue #18: use Codex (the `codex` CLI) as the Stratum orchestrator's advisor instead of `/advisor`. A second model from another vendor reviews the work at the three advisor points, returns structured findings with a verdict, and its approval is tied to a hash of what it reviewed. Codex is review-only."

Decisions are in `decisions.md` (D1 to D14).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Codex reviews at the three advisor points (Priority: P1)

A Stratum user runs a feature through the Full or Fast lane. At each advisor point the orchestrator asks Codex, waits for its answer, and reads a verdict (`APPROVED`, `REVISE`, `BLOCKED`) with findings. The three points are: the plan before the build gate (Inspect phase), a task test that is still red after two build tries, and the full diff before the build is called done. The user sees the verdict and the findings at the next gate and never has to run anything by hand.

**Why this priority**: This is the feature. A second model from another vendor catches what the first misses, and without the three points nothing else has value.

**Independent Test**: Run the advisor at one point against a small plan in a test repo with a fake `codex` on PATH that returns a fixed structured answer. The orchestrator gets the verdict and findings, and a record is written. Delivers the full review loop for one point.

**Acceptance Scenarios**:

1. **Given** `codex` is installed and logged in and the mode is `codex`, **When** the Inspect phase reaches step 4, **Then** the orchestrator calls the advisor with the paths of `spec.md`, `plan.md` and `tasks.md`, waits for the answer, and shows the verdict and findings before the gate "user OKs the build".
2. **Given** a task test is still red after two build tries, **When** the orchestrator reaches the "two tries" step, **Then** it calls the advisor with the task text, the test path and both failure outputs, waits, and passes the answer to the debug agent.
3. **Given** all tasks are ticked, **When** the orchestrator reaches the end of the build, **Then** it calls the advisor with the base commit, waits, and handles the findings like review findings before it says the build is done.
4. **Given** the verdict is `REVISE`, **When** the findings are checked against the source, **Then** real small ones are fixed, big ones go to the user, and the advisor runs once more on the changed input. Two rounds at most; then the user decides.
5. **Given** the verdict is `BLOCKED`, **When** the orchestrator reads it, **Then** it stops at once and shows the user the reason. Nothing passes the gate.
6. **Given** the advisor call is running, **When** the orchestrator waits, **Then** it does nothing else until the answer and the record exist. No background run, no polling.

---

### User Story 2 - The flow keeps working without Codex (Priority: P1)

A user without `codex`, or with a Codex that fails, still gets the same Stratum flow as today. Missing Codex is one line and the flow goes on. A failing Codex is a visible `BLOCKED`, never silent approval.

**Why this priority**: Stratum must stay usable on machines without Codex, and a broken reviewer must never look like a passing one.

**Independent Test**: Run the advisor with `codex` off PATH, then with a fake `codex` that exits non-zero, that writes nothing, and that writes text that is not the structured answer. Each case gives the documented one-line result and exit code.

**Acceptance Scenarios**:

1. **Given** `codex` is not on PATH, **When** the orchestrator reaches an advisor point, **Then** it gets one line `no advisor: codex not found`, the flow runs as before this feature, and `/advisor` is consulted only if the user set one.
2. **Given** `codex` exists but exits with an error (not logged in, no network, quota), **When** the orchestrator calls the advisor, **Then** it gets `BLOCKED: <reason>` on one line, shows it to the user, and asks whether to continue. On continue, the point is skipped and recorded as `BLOCKED, user continued`.
3. **Given** `codex` returns an empty answer or an answer that is not in the agreed shape, **When** the orchestrator reads it, **Then** the result is `BLOCKED: <reason>` and not approval.
4. **Given** the call runs longer than the time limit, **When** the limit passes, **Then** the result is `BLOCKED: timed out`.

---

### User Story 3 - Approval is tied to what was reviewed (Priority: P2)

Every advisor call appends a record to `specs/<feature>/advisor.md`: the point, a SHA256 of the input Codex reviewed, the verdict and the findings. At a gate, the orchestrator checks that the latest record for that point matches the current input. A changed plan or diff makes the old approval stale.

**Why this priority**: Without the tie, an approval of an old plan can carry a changed plan through the gate.

**Independent Test**: Run the advisor on a plan, change one line of the plan, and check at the gate. The gate reports "advisor approval is stale".

**Acceptance Scenarios**:

1. **Given** an `APPROVED` record for the plan, **When** `spec.md`, `plan.md` and `tasks.md` are unchanged at the gate, **Then** the gate shows `APPROVED` with the record's hash.
2. **Given** an `APPROVED` record for the plan, **When** any of `spec.md`, `plan.md` or `tasks.md` changed after the record, **Then** the gate shows "advisor approval is stale" and treats it as no approval.
3. **Given** two records for the same point, **When** the gate reads them, **Then** the latest record counts.

---

### User Story 4 - The user chooses the mode (Priority: P2)

A project owner sets the advisor mode in `.stratum/advisor.json`: `codex`, `both` (Codex, then `/advisor` if set), or `off` (the flow as today). No file means `off` and a one-line hint. `st-init` asks one question and writes the file for new projects.

**Why this priority**: Some users want both reviewers, some want none. The off switch is also the privacy control.

**Independent Test**: Set each mode in the file and run the advisor. `codex` runs Codex only, `both` runs Codex and reports that `/advisor` should follow, `off` prints one line and runs nothing.

**Acceptance Scenarios**:

1. **Given** no `.stratum/advisor.json`, **When** the advisor runs, **Then** it prints `no advisor: mode not set` with the instruction to write the file, exits with success, and Codex does not run.
2. **Given** `{"mode": "both"}`, **When** the advisor runs, **Then** Codex runs and the first output line tells the orchestrator to also consult `/advisor` if one is set.
3. **Given** `{"mode": "off"}`, **When** the advisor runs, **Then** it prints `no advisor: mode off`, exits 0, and the flow runs as before this feature.
4. **Given** `st-init` runs in a project without the file, **When** it reaches the advisor step, **Then** it asks one question with `codex` as the recommended answer and writes the file.

---

### User Story 5 - Codex is review-only and the user knows what leaves the machine (Priority: P1)

Codex never changes a file, never builds, never fixes. It runs in the read-only sandbox at every point. The prompt tells it to stay inside the named files and the diff and never open env or secret files. The README says in plain words that each call sends the prompt, and the files Codex reads, to OpenAI, and that `mode: off` is the switch.

**Why this priority**: A reviewer with write access is a second builder, and a hidden data flow is a privacy problem.

**Independent Test**: Read the command the advisor runs. It carries the read-only sandbox and no write or bypass flag. A test fails if any write-capable flag appears.

**Acceptance Scenarios**:

1. **Given** any advisor point, **When** Codex is called, **Then** the call uses the read-only sandbox and no flag that allows writes or skips the sandbox.
2. **Given** the README "Built in" section, **When** the user reads the advisor bullet, **Then** it states what is sent to OpenAI, that Codex only reviews, and how to turn it off.
3. **Given** the prompt sent to Codex, **When** it is read, **Then** it tells Codex to review only, to stay inside the named inputs, and not to open env or secret files.

---

### Edge Cases

- `codex` is installed but not logged in: `BLOCKED: <codex's error line>`.
- Codex answers with a verdict but zero findings: valid. `APPROVED` with no findings is a real result.
- Codex answers with findings but a missing or unknown verdict: `BLOCKED: no verdict`.
- The feature directory does not exist yet (Fast lane change outside a feature): not possible, the Fast lane requires a feature in `specs/`. The record goes to that feature's `advisor.md`.
- The input for the diff point is empty (no diff against the base): the advisor still runs and Codex reports no changes. The hash is of the empty diff.
- An input cannot be read (not a regular file, no permission), or the hash tool or `git` fails while the diff is collected: `cannot hash inputs`, exit 2, no record, no Codex call. The same stops `check`, so a failed hash never passes as a fresh approval.
- `.stratum/advisor.json` is not valid JSON or has an unknown mode: `BLOCKED: bad advisor.json`, never a silent default.
- Two advisor runs for the same point in one session: both records stay, the latest counts.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The orchestrator MUST consult the Codex advisor at exactly three points: the plan before the build gate (Inspect phase step 4), a task test still red after two build tries (Full and Fast lanes), and the full diff before the build is called done (Full and Fast lanes). The Quick lane has no advisor.
- **FR-002**: The orchestrator MUST wait for the advisor's answer in the foreground and read the verdict before it moves on. No background run, no polling.
- **FR-003**: Every answer MUST carry one verdict: `APPROVED`, `REVISE` or `BLOCKED`, and a list of findings, each with a claim, the evidence, a severity, and where it points (file and line when known). `APPROVED` with zero findings is valid. `REVISE` with zero findings is malformed and counts as `BLOCKED: REVISE with no findings`.
- **FR-004**: An empty, failed, malformed or late answer MUST count as `BLOCKED` with a one-line reason, never as approval. `BLOCKED` exits with a non-zero status; `no advisor` lines exit with success.
- **FR-005**: The orchestrator MUST treat `REVISE` findings like review findings: check each against the source, fix the real small ones, bring big ones to the user, drop the false ones, then run the advisor once more on the changed input. Two rounds at most per point per gate pass, then the user decides. A later gate pass on the same point starts a new count.
- **FR-006**: On `BLOCKED` the orchestrator MUST stop at that point and show the user the reason. If the user says to continue, the point is recorded as `BLOCKED, user continued` and skipped; the advisor is not retried at that point in this gate pass.
- **FR-007**: Every run that reaches a verdict MUST append a record to `specs/<feature>/advisor.md` with: the point, the date and time, the SHA256 of the input (the bytes of `spec.md`, `plan.md` and `tasks.md` joined in that order at the plan point, the bytes of `git diff <base> -- . ':(exclude)specs/<feature>/advisor.md'` followed by `git diff --no-index -- /dev/null <path>` for each untracked file (same exclusion) at the diff point, the bytes of both failure outputs joined at the test point), the verdict and the findings. If the input cannot be read or hashed (an unreadable file, a failing `git` or `sha256sum`, a digest that is not 64 hex characters), the run MUST stop with `cannot hash inputs`, exit status 2, and no record.
- **FR-008**: At a gate the orchestrator MUST compare the latest record's hash for that point with the current input. A mismatch is "advisor approval is stale" and counts as no approval.
- **FR-009**: The prompt MUST name paths and a base commit, not paste file contents, except the test point, where the task text, test path and both failure outputs are pasted because they are in no file.
- **FR-010**: The mode MUST come from `.stratum/advisor.json`: `codex`, `both`, or `off`. A missing file means `off`: the advisor prints `no advisor: mode not set` with the one-line instruction to write the file, exits with success, and nothing is sent to OpenAI. `both` runs Codex and tells the orchestrator to also consult `/advisor` if one is set. `off` prints `no advisor: mode off` and the flow runs as before this feature. A file that is not valid or has an unknown mode is `BLOCKED: bad advisor.json`.
- **FR-011**: When `codex` is not on PATH the advisor MUST print `no advisor: codex not found`, exit with success, and the flow MUST run as before this feature, with `/advisor` if the user set one.
- **FR-012**: Codex MUST run in the read-only sandbox at every point, with no flag that allows writes or bypasses the sandbox. Codex is used for review only, never to build or fix.
- **FR-013**: The prompt MUST tell Codex to review only, to stay inside the named inputs, never to open env or secret files, and never to quote a secret value in a finding. At the diff point, untracked paths whose file name matches `.env*`, `*.pem`, `*.key`, `*.p12` or `*.pfx` (in any directory) MUST be left out of the list sent to Codex but MUST stay in the hashed input.
- **FR-014**: The Codex model and reasoning effort MUST come from the optional `model` and `effort` keys in `.stratum/advisor.json` when present, else from the user's own Codex configuration. `st-init` writes only `mode`.
- **FR-015**: `st-init` MUST ask one question about the advisor mode, with `codex` as the recommended answer, and write `.stratum/advisor.json`, unless the file exists.
- **FR-016**: The README "Built in" advisor bullet, `skills/st-inspect/SKILL.md` step 4, `skills/st-build/SKILL.md` steps "Two tries" and the end-of-build advisor paragraph, and `skills/st-fast/SKILL.md` steps 3 and 4 MUST describe the Codex advisor, the wait, the verdict handling, the modes, the record, and the no-Codex path. The README MUST state what each call sends to OpenAI and that `mode: off` is the switch.
- **FR-017**: A test MUST cover: the happy path with a fake `codex`, `codex` missing from PATH, `codex` exiting non-zero, an empty answer, a malformed answer, a stale hash, each mode, and a check that the command carries the read-only sandbox and no write-capable flag.

### Key Entities

- **Advisor record**: one entry per call in `specs/<feature>/advisor.md`. Point, date and time, input hash, verdict, findings.
- **Advisor settings**: `.stratum/advisor.json` with `mode` (`codex`, `both`, or `off`) and optional `model` and `effort`.
- **Verdict**: `APPROVED`, `REVISE`, or `BLOCKED`.
- **Finding**: claim, evidence, location (file and line when known), severity.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a Full-lane run with Codex installed, all three advisor points produce a verdict and a record with no human step. 3 of 3.
- **SC-002**: With Codex missing, a Full-lane run completes with the same gates and outputs as before this feature, plus one `no advisor` line per point.
- **SC-003**: Every failure path (codex error, empty answer, malformed answer, timeout, bad mode file) ends in a one-line `BLOCKED: <reason>`. 0 silent approvals in the test.
- **SC-004**: A plan changed after approval is reported stale at the gate in 100% of test runs.
- **SC-005**: The command sent to Codex contains the read-only sandbox in 100% of calls and never a write or bypass flag.
- **SC-006**: A user reading the README advisor bullet can answer, without reading code: what Codex reviews, when, what leaves the machine, and how to turn it off.

## Assumptions

- `codex` CLI 0.163.0 or later is installed and logged in by the user. Stratum does not install it or log in.
- Running Codex in this repository is acceptable to the user, since the user already runs `codex` here. The off switch exists for projects where it is not.
- The read-only sandbox blocks writes but not reads. The prompt, not a technical block, keeps Codex out of env and secret files.
- The time and token cost per point are unknown until the Plan phase measures them on a real plan and a real diff. The time limit is set from those measurements, under the 10-minute cap of a foreground orchestrator call.
- One record file per feature is enough. Fast-lane changes record to their feature's `advisor.md`.
- The existing `/advisor` path is unchanged. Mode `both` adds Codex before it; mode `off`, a missing mode file and a missing `codex` leave it as the only advisor.
- Projects set up before this feature have no `.stratum/advisor.json`, so they stay on the old flow until the owner writes the file.
