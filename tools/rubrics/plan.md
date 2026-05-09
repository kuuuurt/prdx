# PRD Quality Rubric

Score each axis 1-5. Be strict; 3 = adequate, 5 = exemplary.

## Axes

### problem_specificity
Is the Problem section concrete and specific to this codebase/feature, not a generic restatement of the request?
- 1: missing or restates the title
- 3: names the actual user/system pain
- 5: includes the concrete trigger, who is affected, and why it matters now

### goal_clarity
Is the Goal a single, unambiguous outcome that an engineer could decide "done" against?
- 1: missing, or multiple goals tangled together
- 3: one outcome, but somewhat vague
- 5: one outcome, measurable or directly observable

### ac_testability
Are the acceptance criteria written so that each one can be verified by a test or a manual check?
- 1: AC are aspirations ("works well", "is fast")
- 3: AC are concrete behaviors but missing edge cases
- 5: AC cover happy path + key edge cases, each phrased as an observable behavior

### scope_bounded
Does the PRD avoid scope creep — i.e., it sticks to the requested feature without inventing adjacent work?
- 1: introduces unrelated rewrites or future-proofing
- 3: stays mostly on topic with minor drift
- 5: sharply scoped; out-of-scope items called out explicitly

### codebase_grounded
Does the PRD reference the actual stack/files/patterns from the synthesized repo context, rather than generic guidance?
- 1: could apply to any codebase
- 3: mentions the stack but not specific files
- 5: references concrete files/modules/patterns from the provided context

### actionability
Could an engineer (or a downstream dev-planner agent) start work from this PRD without follow-up questions?
- 1: too vague to start
- 3: most decisions clear, a few ambiguities
- 5: ready to hand off; ambiguities explicitly flagged as open questions
