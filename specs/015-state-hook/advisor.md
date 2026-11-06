## plan | 2026-11-06T02:34:42Z | sha256 241d792168630644ed56803bddc18207b54306a6b4a61f20739d48fecdc4d236 | REVISE
summary: Simplify the implementation sequence by building the final marker grammar once.
- [LOW] specs/015-state-hook/ tasks.md:56: Fold T011–T012 into the initial marker test and implementation tasks instead of implementing a restricted grammar and then replacing it. Evidence: T004 introduces a plain Lane pattern and T010 introduces plain completion patterns; T011–T012 then extend all three with prefixes, wrappers and punctuation. The final grammar is already specified in data-model.md:61–78. Move the corresponding positive and negative cases into T003 and T009, and implement the final patterns in T004 and T010. This preserves test-first development while removing a separate rewrite and validation cycle.

## plan | 2026-11-06T02:52:27Z | sha256 9f430057e9caaa603ba3c8b06d42edfb9e079be496c975e5796979fae136bcac | APPROVED
summary: The revised plan builds the final marker grammar once, addressing the previous finding. No further simplification warrants revision within this plan-only review.
