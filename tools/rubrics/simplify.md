# Code Simplification Rubric (for /prdx:simplify)

Score each axis 1-5. Be strict; 3 = adequate, 5 = exemplary.

The artifact is the **full content of the file after simplification**. Compare
against the original code (provided in the case input).

**Scope:** `/prdx:simplify` is a chained command — Phase 2 delegates a deep
review to the built-in `simplify` skill (3 sub-agents), then Phase 3 applies
PRDX's pragmatism pass. The pure-function eval harness cannot invoke the
skill/sub-agents, so this rubric scores **Phase 3 only**: the conciseness +
comment-discipline + pragmatism-fence pass over a single file. Reuse/efficiency
findings (Phase 2) are out of scope here and must be monitored separately.

## Axes

### behavior_preserved
Does the simplified code do exactly the same thing as the original?
Same public API, same side effects, same control flow at the observable level.
- 1: alters behavior, changes signatures, or breaks the contract
- 3: probably equivalent but introduces subtle risk (different default,
     reordered side effect)
- 5: identical observable behavior; only structural cleanup

### comment_discipline
Did it remove what-style doc comments and *keep* `// MARK:`, `// TODO:`,
`// FIXME:`, and why-comments per the prompt's rules?
- 1: stripped TODO/MARK or kept restating-the-name comments
- 3: mostly right but missed a few
- 5: textbook — all noise gone, all signal preserved

### actually_simpler
Is the result genuinely cleaner — fewer single-use indirections, less
ceremony, better-named identifiers? Not "fewer lines at any cost".
- 1: just shorter, but harder to read; or unchanged
- 3: modestly cleaner
- 5: noticeably easier to read; ceremony gone without losing clarity

### pragmatism_fence
Did it stay within the pragmatism fence — no NEW features, abstractions, error
handling, comments, or dependencies, and no architecture/API restructuring or
behavior change? Phase 3's job is to *revert* over-reach, not introduce it.
- 1: added new helpers/validation, or refactored/abstracted beyond simplification
- 3: tiny additions that may be defensible
- 5: pure subtraction / rewording; no new constructs, no restructuring

### output_format
Did it emit just the file contents (optionally inside one code fence) with
no surrounding commentary, no "here is the simplified code" preamble?
- 1: prose preamble or trailing summary surrounding the code
- 3: minor leading/trailing prose
- 5: clean — just the code
