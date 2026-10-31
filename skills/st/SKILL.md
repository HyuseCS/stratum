---
name: st
description: Stratum main entry. Takes a task in plain words, picks the lane (Full, Fast, Quick, Design) by impact area, says which in one line, and runs it as the orchestrator.
---

# /stratum:st <task>

You are the orchestrator. You route and verify. You do not implement. Plugin root is two levels up
from this skill's base directory. Read `<project>/.stratum/state.json` and, if present,
`<project>/.stratum/handoff.md` before anything else.

If `<project>/.stratum/` does not exist, stop and tell the user to run `/stratum:st-init`.

## 1. Pick the lane

When the task names GitHub issue numbers (`#51` or an issue URL), run `/stratum:st-triage` on them first (Skill tool), show its short verdict per issue, then pick the lane.

Find the impact areas the task touches (graph first: `graphify-out/GRAPH_REPORT.md`, then search).
The highest area wins:

| Impact area | Examples | Lowest lane |
|-------------|----------|-------------|
| Privacy and access | access rules, data model, contracts, sign-in, personal or minors' data | Full |
| New look, page or screen | a new look, or a page or screen the project does not have yet, when the screen is the whole task | Design |
| New user story or feature | anything not in a current spec | Full |
| Core runtime | background services, offline queue, workers, notices | Fast |
| Screens | layout, components, navigation | Fast (Quick for a small fix in a few files) |
| Text and docs | labels, typos, wording | Quick |

A new page that also needs API, data or sign-in work goes to Full.

Before the first lane skill or agent starts, Quick too, say it in one line: `Lane: <lane>, risk <level> (<area>: <why>). Say "full", "fast", "quick" or "design" to override. Say "risk high", "risk normal" or "risk low" to change the risk.`
Risk level: High for privacy and access, the data model, contracts, secrets, money, or work that cannot be undone. Normal for other Full work. Low for Fast. None for Quick and Design.
Write the risk as `risk` (`high`, `normal`, `low` or `none`) in `<project>/.stratum/state.json` and keep the other keys. On the user's "risk <level>", write the new level.
Then run the lane. If the user overrides, use their lane.

## 2. Run the lane

- **Full:** run `/stratum:st-define`, `/stratum:st-plan`, `/stratum:st-inspect`, `/stratum:st-build`,
  `/stratum:st-close` in order, stopping at each gate those skills name.
- **Fast:** run `/stratum:st-fast`.
- **Quick:** run `/stratum:st-quick` for one file. For a small bounded fix across a few files with
  no plan, start the `stratum:st-build` agent with the brief, the plugin root and the project root,
  never `general-purpose`. Then verify, and the `stratum:st-git` agent commits the exact files.
  If the agent reports "Needs the Fast lane", run `/stratum:st-fast`.
- **Design:** run `/stratum:st-design`.

## 3. Moving up a lane

If any subagent reports that the work touches a higher impact area than its lane allows, stop,
tell the user in one line, and restart at the higher lane with what was learned.

## Always

- Big decisions go to the user, one question at a time, with your recommended option. Big means
  it changes the spec, the scope, or the plan's approach; touches privacy and access, the data
  model, contracts, or dependencies; cannot be undone; reaches an audience; or costs a lot.
- Small decisions you make yourself: problems found on the way, naming, placement, a fix inside
  the files the work already touches. Do not stop for them. When the run is done, list each one:
  what you found, what you did.
  Write each small decision in a list as you make it. At each story review, and at the end of a Fast change, the list goes to the advisors the matrix names. A decision an advisor sends to the user is undone if the user says no.
- Findings from any agent or review are hypotheses. Before acting, check each one against the
  source: the defect exists at that `file:line`, and the stated cause is the real one. Drop the
  false ones. A real finding is a decision like any other: small ones get fixed, big ones go to
  the user. The end-of-run list names what was fixed and what was dropped, and why.
- Before accepting code from a subagent, run
  `bash <plugin root>/scripts/st-verify.sh '<test command>' <files it touched>`
  from the project root. It re-runs the tests and greps the diff for added comment lines. Send
  back any `FAIL`.
- On `Needs a test choice: <why>`, ask the user: say why in short words, and offer a named list of tests or the full suite.
- Push only when the user says "push". An Approve at the `/stratum:st-pr` gate counts as that word.
- Every merge into main goes through its GitHub PR (`gh pr merge --merge`), never a local merge
  into main. Never merge a PR before the user says they tested it. A session that works a branch
  toward main opens the PR itself with `/stratum:st-pr` and stays open until the PR is merged.
- Make a GitHub issue only when the user asks in their own words. Do not end a reply
  with an offer to file issues for the items in a list. Keep the list in the conversation and
  the handoff.
- Leave every branch and worktree alone, even one that is merged, done, or looks useless.
  Delete one only when the user says to delete it. Never delete a remote branch: the user does
  that. Never suggest deleting a local branch. When work is done, suggest only removing its
  worktree folder and its merged remote branch.
- Autonomous build mode turns on only when the user says so in their own words for this run ("build with workers, autonomous", "autonomous mode"). Then run `printf '%s\n' "$CLAUDE_CODE_SESSION_ID" > "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/.stratum/autonomous"` (the main checkout's flag, also from a linked worktree) and say `Autonomous build mode: on for this run`.
  It ends when the Build or worker run ends, or when the user says "stop autonomous": run `bash <plugin root>/scripts/st-worker.sh autonomous-off --roster <roster file>` if workers ran, then `rm -f "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/.stratum/autonomous"`, and say `Autonomous build mode: off`. A new session never starts in it.
- When the user asks to open workspaces for agents to work in by themselves, use `/stratum:st-worker` with autonomous build mode on, and a worker on a whole issue opens its own PR. `/stratum:st-herdr-workspace` stays a tool the user runs by hand.
- When the user says they are done, run `/stratum:st-handoff`.
