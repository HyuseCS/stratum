## plan | 2026-11-17T06:52:28Z | sha256 60e5c493834a27d75620663f345e033695cea39aef28e72620de6535332d5b68 | REVISE
summary: The approach is compact, but the implementation sequence can be simplified.
- [LOW] specs/021-background-research/tasks.md:129: Merge US1–US3 into one test-first implementation batch while retaining their acceptance checks. Evidence: Tasks T001–T006 repeatedly edit the same research test and rule files and run the same broad <SK> suite after each build task. The execution strategy already requires these stories to ship together. One combined red-test task followed by one implementation task would reduce repeated editing and validation without changing the deliverable.

## plan | 2026-11-17T07:10:59Z | sha256 64961e92ef9941e74b4eb467b636e0c742e695c2eaa409aae39590a7fe943a75 | REVISE
summary: The earlier opportunity to simplify the implementation sequence remains.
- [LOW] specs/021-background-research/tasks.md:131: Merge US1–US3 into one test-first implementation batch, retaining all acceptance checks. Evidence: T001–T006 still alternate edits to the same test and rule files, with the broad <SK> suite repeated after each build task. The implementation strategy explicitly says these stories ship together. Combining their test tasks and then their implementation tasks would reduce repeated editing and validation.
