# Research: advisor tool in an agent with a fixed tools list
Written by: st-research

## Round 1

### Scope

Feature 022 (worker monitors, `specs/022-worker-monitors/spec.md`) adds a monitor agent with a fixed `tools:` list. FR-025 and FR-028 (`specs/022-worker-monitors/spec.md:184`, `:187`) need that agent to call the built-in Claude Code `advisor` tool. The question is whether an agent with a fixed tool list can have that tool.

### Key facts

#### Q1. Does a subagent with a fixed `tools:` list get the built-in `advisor` tool?

Yes, by the docs and by one live run.

- F1. The advisor is a server tool, not a Claude Code tool. "The advisor tool is a server tool that the API runs, rather than a tool that Claude Code implements. It has no name you can reference in permission rules or hook matchers." (https://code.claude.com/docs/en/tools-reference.md, line 854 of the page, read 2026-11-26)
- F2. Subagents get the advisor from the session setting, with a check on their own model. "Subagents inherit the configured advisor and apply the same pairing check against their own model." and "Subagents whose own model satisfies the pairing may still use the advisor." (https://code.claude.com/docs/en/advisor, read 2026-11-26). The page does not mention the `tools` field.
- F3. The errors page says the same for the case where the main model cannot use the advisor: "subagents may still use it" and "Leave the advisor set if you want subagents whose model it can advise to keep using it" (https://code.claude.com/docs/en/errors.md, lines 3025 and 3031 of the page, read 2026-11-26).
- F4. The subagent page describes `tools` as a filter on the tools "available to subagents" (built-in tools and MCP tools). It does not name `advisor` anywhere: no match for "advisor" in the whole page (https://code.claude.com/docs/en/sub-agents.md, lines 300, 447, 461, 463 of the page, read 2026-11-26).
- F5. Pairing for the monitor models in FR-025. On the Anthropic API, `sonnet` resolves to Sonnet 5.5 and `haiku` to Haiku 5.5. On Claude Platform on AWS they are Sonnet 4.6 and Haiku 4.5 (https://code.claude.com/docs/en/model-config.md, alias table, read 2026-11-26). Accepted advisors: Sonnet 5.5 main takes Fable, Opus 5 or later, Sonnet 5.5. Haiku 5.5 main takes Fable, Opus 4.7 or later, Sonnet 5 or later, Haiku 5.5. Haiku 4.5 and Sonnet 4.6 take Fable, Opus, Sonnet, Haiku 5.5 (https://code.claude.com/docs/en/advisor, read 2026-11-26). The advisor also needs the Anthropic API (or Claude Platform on AWS or Google Cloud Anthropic managed), a fetched feature flag, and no `CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1`. A Fable advisor needs the one-time usage-credits consent on some plans (same page).
- F6. Live run, 2026-11-26, Claude Code 2.1.331 (`claude --version`): this research run is the `st-research` agent. Its system prompt is the body of `agents/st-research.md`, and its file has the fixed list `tools: Read, Grep, Glob, Bash, Write, Edit, WebSearch, WebFetch` (`agents/st-research.md:4`). The list does not name `advisor`. The visible tools of the run were Read, Bash, Write, Edit, WebSearch, WebFetch, SubagentHandback and `advisor` (the harness says other tools can be deferred). The run called `advisor` once and got an answer back. The model was Opus 5.5 (`claude-opus-5-5`). The user setting is `"advisorModel": "fable"` (`~/.claude/settings.json:102`). It is not known if the run was foreground or background.
- F7. The same run had no Grep and no Glob tool, though the list names both. This matches the docs: on Linux, Glob and Grep are out of the default set. They come back for a subagent that lists them "and leaves out `Bash`", or for the session when `--tools` or `--allowedTools` names them at start (https://code.claude.com/docs/en/tools-reference.md, section "Glob tool behavior", line 324 of the page, read 2026-11-26). `st-research` lists Bash.
- F7a. The Claude Code changelog has 23 lines with "advisor". None says how the advisor relates to a subagent `tools` list. The one line that names subagents and the advisor: "Fixed `availableModels` restrictions not being applied to subagent model overrides, the agent dispatch model picker, and the advisor model" (https://code.claude.com/docs/en/changelog.md, line 9008 of the page, read 2026-11-26).

#### Q2. Must the list name `advisor`? Is `advisor` a valid name? What happens to an unknown name?

- F8. The docs give no tool name for the advisor in Claude Code ("It has no name you can reference in permission rules or hook matchers", F1). No doc page lists `advisor` as a value for the `tools` field. F6 shows the agent gets the tool without the name in its list.
- F9. Unknown names: when every entry fails, Claude Code refuses to launch the subagent. The error groups entries as "Unrecognized" (matches no tool name, such as `Grpe`), "Not available to subagents", or "Matched no tools in this session". Message form: `Agent 'code-reviewer' would be spawned with zero tools — refusing. Its tools list resolved to nothing: unrecognized [Grpe].` Since v2.1.208. (https://code.claude.com/docs/en/errors.md, section "Agent would be spawned with zero tools", read 2026-11-26; also https://code.claude.com/docs/en/sub-agents.md line 499 of the page)
- F10. The docs state the refusal only for a list that resolves to nothing. For tools removed from a background subagent: "The removal reports no error unless it leaves the `tools` list resolving to nothing." (https://code.claude.com/docs/en/sub-agents.md, line 463 of the page, read 2026-11-26). The docs do not say in words what happens to one unrecognized entry when the other entries resolve. F7 is a case of listed tools that the run did not get, with no error, but Grep and Glob are known names, not unrecognized ones.
- F11. Not found: whether Claude Code reads `advisor` in a `tools` list as unrecognized, as a match, or ignores it. Looked in sub-agents.md, advisor.md, tools-reference.md, errors.md. A run of a test agent with `advisor` in its list would answer it. That run was not made (no builds or tests in the brief).

#### Q3. Does any agent, skill or test depend on a tool not in an agent's list? How do tests pin the lists?

Agent bodies that name a tool missing from their own list:

- F12. `agents/st-fast.md:65-66` says "Use the Write or Edit tool". Its list is `Read, Grep, Glob, Bash, Write` (`agents/st-fast.md:4`), with no Edit.
- F13. `agents/st-quick.md:54-55` says "Use the Write or Edit tool". Its list is `Read, Grep, Glob, Bash, Edit` (`agents/st-quick.md:4`), with no Write.
- F14. `agents/st-inspect.md:89-90` says "Use the Write or Edit tool". Its list is `Read, Grep, Glob, Bash, Edit` (`agents/st-inspect.md:4`), with no Write.
- F15. 14 of the 16 agents list Grep and Glob together with Bash (`agents/*.md` line 4; only `st-ponytail-audit` and `st-ponytail-debt` have no Bash). By F7, a Linux run of those 14 does not get Grep or Glob by default. `agents/st-research.md:20` tells the agent to "search (Grep, Glob)".
- F16. No file in `agents/` or `procedures/` names `advisor`, `Monitor` or `SubagentHandback` (`grep -rln` gives no match). The advisor mentions are in these skills: `skills/st/SKILL.md`, `skills/st-build/SKILL.md`, `skills/st-build/advisor.md`, `skills/st-plan/SKILL.md`, `skills/st-inspect/SKILL.md`, `skills/st-fast/SKILL.md`, `skills/st-advisor/SKILL.md`, `skills/st-update/SKILL.md`, `skills/st-init/SKILL.md` (the `st-impeccable` and `st-ui-ux` hits are the word "advisory").
- F16a. `skills/st-build/advisor.md:13` tells its reader to use the Monitor tool. Its readers, by grep for `advisor.md`: `skills/st-build/SKILL.md:83`, `skills/st-plan/SKILL.md:32`, `skills/st-fast/SKILL.md:16`, `skills/st-advisor/SKILL.md:13`, `skills/st/SKILL.md:73`. `skills/st-build/SKILL.md:7` says "You are the orchestrator", so that skill runs in the session that spawns the agents. No agent file points to `advisor.md`. No agent list has Monitor.

Tests that pin a tool list, each by an exact line match (`grep -qx "tools: ..."`):

- F17. `tests/test_research.sh:45`: `st-research`, `tools: Read, Grep, Glob, Bash, Write, Edit, WebSearch, WebFetch`.
- F18. `tests/test_inspect.sh:28`: `st-inspect`, `tools: Read, Grep, Glob, Bash, Edit`.
- F19. `tests/test_design_lane.sh:70`: `st-design`, the full list with the 11 `mcp__plugin_stratum_figcraft__*` tools. `tests/test_design_lane.sh:76` also checks that no line of `agents/st-design.md` except the `tools:` line names figcraft.
- F20. `tests/test_on_demand.sh:56-66`: a loop over `st-impeccable`, `st-ponytail-audit`, `st-ponytail-debt`, `st-triage`. Line 63 matches `tools: $t` exactly, with `$t` set at lines 58, 60 and 61. Line 65 fails on Edit or Write in the list. Line 66 fails on Bash in the list for the agents whose `$t` has no Bash.
- F21. `tests/test_st_worker.sh:1154` pins the `--tools Read,Edit,Write,Glob,Grep,Bash` flag of the herdr worker `claude -p` command line. This is a CLI flag, not an agent file.
- F21a. `tests/test_on_demand.sh:131`: `st-review`, `tools: Read, Grep, Glob, Bash, Skill`.
- F22. No test pins the lists of `st-build`, `st-close`, `st-debug`, `st-fast`, `st-git`, `st-plan`, `st-quick`, `st-test` (search: `grep -rnE "tools: |--tools|allowedTools" tests/`).

### Open questions

- [planner] What Claude Code does with `advisor` written in a `tools:` list: unrecognized entry, match, or no effect (F11). Needs a run of a test agent, which the brief did not allow.
- [planner] F6 is one run, on Opus 5.5 with a Fable advisor set. A run of a `sonnet` or `haiku` agent with a fixed list was not made.
- [user] F6 reads the user settings of this machine only. The advisor setting on the other machine and in herdr worker sessions was not read.

### Commands

cat sr-opus-5.md; cat procedures/research.md; grep -n "^tools:\|^name:\|^model:" agents/*.md; ls tests/; ls specs/022-worker-monitors/
head -20 agents/st-research.md; grep -rn "tools" tests/*.sh tests/*.py tests/*.mjs; grep -rn -i "advisor" agents/ skills/; grep -n -i "advisor\|FR-025\|FR-028\|tools" specs/022-worker-monitors/spec.md
WebFetch https://code.claude.com/docs/en/sub-agents (two parts)
WebSearch "Claude Code advisor tool subagents /advisor documentation"
WebFetch https://code.claude.com/docs/en/advisor
WebFetch https://code.claude.com/docs/en/errors
curl -sL https://code.claude.com/docs/en/{errors,sub-agents,tools-reference,advisor}.md into the scratchpad; grep -n -i advisor on them
sed -n on tools-reference.md (lines 845-860, Glob section) and errors.md (zero-tools section); claude --version
for each agents/*.md: tools line against tool names in the body (grep -ow)
sed -n 50,70p tests/test_on_demand.sh
grep -nw "Edit"/"Write"/"Task" in agents/st-fast.md, st-triage.md, st-ponytail-audit.md, st-review.md, st-impeccable.md, st-git.md, st-inspect.md, st-quick.md, st-ponytail-debt.md
sed -n 63,67p agents/st-fast.md; sed -n 53,56p agents/st-quick.md; sed -n 88,91p agents/st-inspect.md
grep -rn "SubagentHandback\|advisor" agents/ tests/test_on_demand.sh tests/test_research.sh tests/test_inspect.sh tests/test_design_lane.sh; ls specs/022-worker-monitors/research
grep -rnE "tools: |--tools|allowedTools" tests/; grep -rln -i advisor agents/ skills/ procedures/; grep -rnE "Monitor|AskUserQuestion|SendMessage|SubagentHandback" procedures/ skills/st-build/
grep -n -i unrecogni on saved sub-agents.md and errors.md; curl -sL model-config.md and changelog.md into the scratchpad; grep -n -i advisor changelog.md; grep -n advisorModel ~/.claude/settings.json .claude/settings.json
sed -n 44,50p model-config.md; grep -rn "advisor.md" skills/ agents/ procedures/; sed -n 1,12p skills/st-build/SKILL.md; sed -n 56,62p tests/test_on_demand.sh
