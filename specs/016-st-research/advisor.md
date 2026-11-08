## plan | 2026-11-08T11:22:58Z | sha256 799d32cb03062fc6c2d21890d0f9be4cf0658e88942e31ce2da7f94138fac675 | REVISE
summary: One task consolidation would reduce implementation churn while preserving test-first delivery.
- [LOW] specs/016-st-research/tasks.md:127: Merge the web-research test and implementation tasks into the initial agent/procedure tasks. Evidence: T002 creates temporary code-only versions of the agent and procedure; T008 then changes the tools assertion, and T009 revisits both files to add already-specified web behavior. Include the US4 checks in T001 and the final web text in T002, retaining Q7 as a separate manual check. This removes two tasks and the contract's temporary [US4: ...] variants without adding dependencies.

## plan | 2026-11-08T11:35:26Z | sha256 847cce862a74257faee38c6a62295d7a690d9964893c88ddcb6eb13de2660241 | WAIVED
reason: Inspect fixes F1-F10 only: target platform line, quickstart steps, marker line, secret rule, test commands; no task added or removed, no approach change

## decisions | 2026-11-08T11:56:35Z | /advisor
summary: 25 small decisions approved; notes: st-define line is dense (Close decides), two duplicate-name test groups go to the shortcut list

## diff | 2026-11-08T11:57:04Z | /advisor
summary: post-review diff is the US4 F2 secret-in-URL line and the T010 tick; approved, no findings
