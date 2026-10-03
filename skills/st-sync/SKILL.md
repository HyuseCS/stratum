---
name: st-sync
description: Maintainer only. In the Stratum repo, list each upstream change since the pinned commit in vendor.lock, draft the ports into Stratum's forks, and wait for review. Run monthly.
---

# /stratum:st-sync

Run only in the Stratum repo itself: the project root must hold `vendor.lock` and
`.claude-plugin/plugin.json` with `"name": "stratum"`. Anywhere else, say so and stop.

1. For each entry in `vendor.lock`: shallow-clone or fetch `repo` into the scratchpad, then list
   commits from `commit` to the newest on `ref` that touch `path` (or the whole repo if no path).
   Skip entries with no new commits.
2. Report one line per source: name, commits since pin, and a one-line summary of what changed.
   Ask the user which sources to port. Default: all with changes.
3. For each chosen source, start a subagent (sonnet) that reads the upstream diff for the files
   Stratum forked (see `THIRD_PARTY_NOTICES.md` for the mapping) and applies the same change to
   Stratum's copy, keeping Stratum's renames (`st-*` names, paths). It must not change design
   content beyond the upstream change, and reports anything it could not port.
4. graphify: compare the skill's upstream version with `graphify --version`. If the program is
   older than the skill, tell the user to upgrade it before taking the skill update.
5. Show the user the combined diff, source by source. On their OK, update each ported entry's
   `commit` (and `version` where present) and set `synced` to today in `vendor.lock`, then commit
   one commit per source: `sync(<source>): <summary> (<old>..<new>)`.
6. Run the tests in `tests/` and report the result. Push only on the user's "push".
