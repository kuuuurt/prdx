# Case Generator: plan

Generate realistic, varied test cases for the PRDX `/prdx:plan` command.

Each case is a JSON object on a single line (JSONL) with this shape:

```json
{
  "id": "plan-0001",
  "input": {
    "request": "Plain-English feature request a user would type after /prdx:plan",
    "projectName": "kebab-case repo name",
    "stack": "One line describing the language/framework/notable libs",
    "codebaseSummary": "3-8 lines of bullet points describing relevant files, modules, patterns. Include a couple of concrete file paths.",
    "expectations": "What a good PRD for this case should mention or avoid. One sentence."
  }
}
```

## Diversity requirements

Across the N cases produced, vary on:

- **Platform**: backend (Go/Python/Node/Java), frontend (React/Vue/Svelte/Next), mobile (Android/Kotlin, iOS/Swift, Flutter), CLI tools, data pipelines.
- **Request type**: new feature, bug fix, refactor, performance work, security hardening, observability, migration.
- **Scope**: tiny (one function), medium (one module), large (cross-module).
- **Specificity of the request**: terse one-liner vs. paragraph with constraints.
- **Codebase shape**: greenfield vs. legacy, monolith vs. service, well-tested vs. untested.
- **Adversarial cases (~10%)**: ambiguous requests that should produce a PRD with explicit open questions; requests that *sound* like features but are really just bug reports; requests that drift toward implementation when they should stay scoped.

## Output

Produce exactly N JSONL lines. No prose, no fences, no preamble. Each line must be valid JSON. IDs must be sequential (`plan-0001`, `plan-0002`, ...).
