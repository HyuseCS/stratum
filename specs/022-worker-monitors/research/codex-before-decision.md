# Research: Codex before a big decision (FR-028, FR-029)
Written by: st-research

## Round 1

### Scope

Feature 022 (worker monitors, specs/022-worker-monitors/spec.md) needs a monitor agent to ask Codex about one big decision before it answers a worker (FR-028, FR-029 at specs/022-worker-monitors/spec.md:187-188). This round finds how scripts/st-advisor.sh can do that today and what it prints. skills/st-build/advisor.md holds the caller rules for the output lines.

### Key facts

#### Q1. Which points does scripts/st-advisor.sh have? Arguments, prompt text, record, time limit.

Accepted command shapes are the case list at scripts/st-advisor.sh:68 (`<cmd> <point> <argc>`, argc counts the point). `cmd` is `run` unless the first word is check, continued, waive, note, round or talk (scripts/st-advisor.sh:65-66).

Every Codex prompt starts with the same 4 lines (scripts/st-advisor.sh:217-221): reviewer only, never change a file or build, read only named inputs and cited files, never open or quote secrets, answer APPROVED / REVISE / BLOCKED with findings (claim, evidence, location, severity). The answer must match the JSON schema at scripts/st-advisor.sh:214 (verdict enum APPROVED, REVISE, BLOCKED; findings with severity CRITICAL, HIGH, MEDIUM, LOW).

Time limit: `lim=540` s for every point, `lim=1800` s for `review` (scripts/st-advisor.sh:266-267). The limit is total script time (`SECONDS=0` at scripts/st-advisor.sh:4, `left=$((lim - SECONDS))` at :268). With less than 60 s left the point is `BLOCKED: timed out` (:269). It applies only to the headless `codex exec` run (`timeout -k 10 $left`, :273). In the herdr Codex tab a review has no time limit (skills/st-build/advisor.md:39). The tab run first waits up to 50 s for the lock `codex-$HERDR_WORKSPACE_ID` and blocks with `Codex agent busy with another review` on exit 75 (scripts/st-advisor.sh:254-255).

Record: `rec=$f/advisor.md` where `f` is arg 2 without a trailing slash (scripts/st-advisor.sh:72, :77), except `review` (below). The header is `## <label> | <ts> | sha256 <hash> | <verdict>` (scripts/st-advisor.sh:288). The label is the point, or `<point> round <n>` for round (:70-71).

| Point | Arguments (scripts/st-advisor.sh:68, input checks :113-123) | Prompt text after the 4 head lines | Hash input |
|---|---|---|---|
| plan | `plan <feature dir>`; needs plan.md and tasks.md (:115) | :236-238, "Point: plan. Advise only on how the plan could be built better or done differently..." then `Inputs: <f>/spec.md, <f>/plan.md, <f>/tasks.md` | spec + plan without `## Validate` + tasks (:189) |
| test | `test <feature dir> <task file> <test path> <failure 1> <failure 2>` (:117) | :244, "Point: test. This task's test is still red after two build tries. Root cause or rabbit hole?" then test path, task text and both outputs pasted | both failure files (:190) |
| diff | `diff <feature dir> <base>`; base must be a commit, no change gives `no change since <base>: skip` exit 0 (:118-122) | :234, "Point: diff. Review the changes in git diff <base>..HEAD (run it yourself): hidden regressions and broken rules of the project's constitution. Do not build or fix." | git diff base..HEAD (:191) |
| decisions | `decisions <feature dir> <list file>` (:116) | :228-229, "Point: decisions. Below is the list of small decisions the orchestrator made. For each one, say whether it is fine. A finding with severity CRITICAL or HIGH means the decision must go to the user." then the list file pasted with `cat` | list file (:188) |
| change | `change <feature dir> <change file>` (:116) | :240-242, "Point: change. Review this change plan inside an existing feature: is the approach right and the simplest, and does it miss a test, a file or a caller? Do not build or fix." then `Inputs: <f>/spec.md, <change file>` (file named, not pasted) | change file (:188) |
| review | `review <base> [plan file]` (:68, :118-122) | :231-232, "Point: review. Do a full review of the changes in git diff <base>..HEAD (run it yourself): bugs, regressions, security and broken rules of the project's constitution. Do not build or fix." plus `Plan: <file>...` when given | diff, plus plan file when given (:191) |
| round | `round <plan|test|diff|decisions|change> <feature dir> <1-3> <views file>` (:68, :114) | :224-226, "Point: <point>, round <n> of 3 of a talk with another advisor. The views so far are below. For each open point, agree, or keep your view and give the reason." Round 3 adds "This is the last round. For every open point, propose a compromise aimed at the best result, one finding per compromise." Views file pasted. | views file (:187) |

Commands that do not call Codex: `check plan` (:102-106, :195-198), `continued <plan|test|diff|decisions|change>` (:107-111), `waive plan <reason>` (:124-127, :200-203), `note <point> <reason>` (:89-92), `talk <point> <file>` (:94-100), `count <feature dir>` (:79-84), `answer` and `watch` for the herdr tab (:28-64).

#### Q2. Can any point take one decision (a question plus the facts) and give a verdict before the caller acts? Is the `decisions` text usable for a decision not made yet?

1. No point is written for a decision that is not made yet. The only prompts that paste free text are `decisions` (list file, :229), `round` (views file, :226) and `test` (task and failures, :244). `change` names its file and the spec (:242).
2. The `decisions` text says, word for word: "Below is the list of small decisions the orchestrator made. For each one, say whether it is fine." (:228). It is past tense ("made"), names the orchestrator as the maker, and calls the items "small". It asks "whether it is fine" per item. It says "A finding with severity CRITICAL or HIGH means the decision must go to the user." The script does not check the list file content, only that it is a readable file (:116).
3. The verdict a caller gets is APPROVED, REVISE or BLOCKED (schema :214, check :308). APPROVED must have no findings and REVISE must have at least one (:314-317). There is no yes/no or condition field.
4. Who runs at the decisions point (Q4): Codex runs only in mode `auto` at risk high or normal. In mode `codex` or `both` the decisions point never calls Codex (:173).
5. `round` is the only point that runs Codex at every auto risk level (:164) and in modes codex and both (:173 excludes only diff and decisions). It needs a feature dir with spec.md (:73-76) and a views file, and its text frames a talk between two advisors (:224).
6. `change` asks "is the approach right and the simplest" about a "change plan inside an existing feature" (:241). At auto risk low and none it runs no advisor (:166).

#### Q3. Where in scripts/st-advisor.sh would a new point have to be added?

- Usage line: scripts/st-advisor.sh:5.
- Command word list (only for a new command word, not a new point): :66.
- Argument check (`cmd point argc` list): :68.
- Feature dir and spec check, skipped only for `review`: :73-76.
- Per-point input file check: :113-123 (decisions and change at :116).
- Review-only record path: :131-135.
- Risk table for mode auto: :163-169.
- Non-auto modes (points that get `/advisor` only): :173; the `mode both` line: :174.
- Input hash: :186-192 (decisions and change at :188).
- Prompt text: :222-245 (decisions at :227-229).
- Record: label :69-71, path :77, write in the Python block :286-288, output :320-323. `count` counts every header with a verdict, whatever the point (:82). `check` and `continued` take the point name in their grep (:103).
- Time limit: :266-267.
- Outside the script: the point table in skills/st-build/advisor.md:3-9; the exact usage line pinned in tests/test_advisor_matrix.sh:419 and tests/test_advisor.sh:498; the auto risk grid in tests/test_advisor_matrix.sh:76-95.

#### Q4. What does the `decisions` point print per risk level and mode?

Order of checks in a `run` (scripts/st-advisor.sh:129-181):
1. No `.stratum/advisor.json` in the cwd or the main checkout: `no advisor: mode not set. Write .stratum/advisor.json with "mode": "auto", "codex", "both" or "off".` exit 0, no record (:136-138).
2. Bad advisor.json: no mode lines; later `BLOCKED: bad advisor.json` with a BLOCKED record, exit 1 (:157, :211). Tested for decisions at tests/test_advisor_waive.sh:182-190.
3. Mode `off`: `no advisor: mode off`, exit 0 (:160).
4. Mode `auto`: risk comes from `$main/.stratum/state.json` key `risk` (:139, :152-155). No valid risk prints `risk not set: normal` and uses normal (:162).
   - high: `advisors: both (decisions, risk high)` (:165, :170), then Codex runs.
   - normal: `advisors: codex (decisions, risk normal)` (default :168), then Codex runs.
   - low: `advisors: /advisor (decisions, risk low)` and exit 0, no Codex, no record (:167, :171).
   - none: `advisors: none (decisions, risk none)` and exit 0, no Codex, no record (:166, :171).
5. Mode `codex` or `both`: `advisors: /advisor (mode codex)` or `advisors: /advisor (mode both)`, exit 0, no Codex, no record (:173).
6. Codex not on PATH (only reached for auto high or normal): `no advisor: codex not found`, exit 0 (:179). The `advisors:` line is not printed in that case, because `say` is printed later at :210.

When Codex runs, output is the `advisors:` line (:210), then `<VERDICT> sha256 <hash>`, `summary: ...`, one `- [SEV] location: claim Evidence: ...` per finding, `record: <path>` (:320-323). A Codex BLOCKED prints `BLOCKED: <summary>` first, exit 1 (:322, :324). Failures print `BLOCKED: <reason>` and `record: <path>`, exit 1 (:289-293, :205-208). The last line is the `codex: tab ...` or `codex: headless (...)` line (:248-264, :327).

Caller rules: `advisors: none` means no advisor at this point (skills/st-build/advisor.md:22). `advisors: /advisor` means consult `/advisor` only (:22), then run `note` (:37). `advisors: both` means Codex, then `/advisor`, then the talk of up to 3 `round` runs (:22-27). `no advisor: codex not found` or `mode off`: go on, consult `/advisor` only if the user set one (:19). `mode not set`: stop and ask the user (:20). `BLOCKED: <reason>`: stop and show the user, `continued` on the user's word (:40). `REVISE` with only MEDIUM and LOW counts as passed (:32).

#### Q5. Does a point need a feature dir with a spec? Where does the record go?

- Every point but `review` needs arg 2 to be a folder with a readable regular `spec.md`, and `advisor.md` in it must not be a symlink, else usage and exit 2 (scripts/st-advisor.sh:73-76). The folder can be any path; the script does not check that it is under `specs/`.
- The record goes to `<that folder>/advisor.md` (:77), appended (:288).
- `review` takes no folder. Its record is `<main checkout>/.stratum/advisor/<branch with / as ->.md` (:130-133), the folder is made at :182. Tested: tests/test_advisor.sh:503-512.
- Mode is read from `.stratum/advisor.json` in the cwd, else in the main checkout (:136-137). Risk is read from the main checkout's `.stratum/state.json` (:139), not from the given folder.
- The input file for decisions, change and round can be any readable file (:114, :116).

#### Q6. Which tests pin this behaviour?

- tests/test_advisor.sh: prompt head lines exact (:81-83), schema (:74), read-only argv (:68-70), plan/test/change prompts and hashes (:84-123), output and record for REVISE, BLOCKED and malformed answers (:93-199), timeout 540 (:203-208) and 1800 for review (:508), bad args exit 2 (:212-223), check/continued (:231-323), mode file lookup and modes (:332-381), model and effort (:386-397), hash failures (:405-436), review with no feature folder and its record path (:503-513), exact usage line (:498).
- tests/test_advisor_matrix.sh: auto risk grid for plan, test, decisions, diff and change with the first line and Codex call count (:76-126), `risk not set: normal` (:130), mode codex for decisions prints `advisors: /advisor (mode codex)` with no record (:141), mode both for diff (:146), bad advisor.json (:151), decisions prompt line and list text (:173-175), unreadable list gives usage (:177-182), no advisor.json and mode off for round (:228-233), round runs Codex at risk low (:238), worktree risk from the main checkout (:248), exact usage line (:419), timeout under 60 s left (M27, around :560-565), tab runs (R1-R5).
- tests/test_advisor_waive.sh: waive and check plan (:73-91), decisions and diff with bad advisor.json give BLOCKED and `continued` works (:182-190).
- tests/test_advisor_rules.sh: phrases that must be in, or gone from, skills/st-build/advisor.md, skills/st-build/SKILL.md, skills/st-inspect/SKILL.md and README.md (A1-A28, G1-G5).
- tests/test_risk_rules.sh:20 (R13): skills/st-build/SKILL.md holds the `st-advisor.sh decisions <feature dir> <list file>` call.
- tests/test_on_demand.sh:262-310: skill files name the plan, test, continued and check calls; st-fast uses only the change point.

### Open questions

- [planner] No point takes one undecided decision; the decisions point never calls Codex in modes codex and both, and in auto only at risk high and normal. Whether FR-028 uses an existing point (decisions, change, round) or a new one is a planning choice.
- [planner] FR-029 needs "a clear yes" with no condition. The script returns APPROVED, REVISE or BLOCKED only. How a monitor maps these to agreement is not defined anywhere in the repo.
- [planner] A point writes to `<folder>/advisor.md` and needs `<folder>/spec.md`. Which folder a monitor passes for a worker's decision is not defined.

### Commands

cat sr-opus-5.md procedures/research.md; wc -l scripts/st-advisor.sh skills/st-build/advisor.md; ls tests | grep -i advis; grep -rln st-advisor tests
grep -n "FR-028\|FR-029" specs/022-worker-monitors/spec.md; ls specs/022-worker-monitors/research/; grep -n "timeout\|sleep\|limit" scripts/st-codex-agent.sh; wc -l tests/test_advisor*.sh; grep -n decisions tests/*.sh
grep -n 'check "' tests/test_advisor_matrix.sh tests/test_advisor.sh tests/test_advisor_rules.sh tests/test_advisor_waive.sh
sed -n 70,130p tests/test_advisor_matrix.sh; sed -n 175,209p tests/test_advisor_waive.sh; sed -n 1,50p tests/test_advisor_rules.sh
grep -n 'check "' tests/test_advisor.sh; grep -n "540\|1800\|timed out\|spec.md\|\.stratum/advisor/" tests/test_advisor*.sh; grep -n st-advisor tests/test_on_demand.sh tests/test_lane_steps.sh tests/test_st_worker.sh tests/test_shell_writes.sh
sed -n 72,77p tests/test_advisor_matrix.sh; sed -n 415,425p tests/test_advisor_matrix.sh; sed -n 212,223p tests/test_advisor.sh; sed -n 495,512p tests/test_advisor.sh; git log --oneline -3 -- scripts/st-advisor.sh
