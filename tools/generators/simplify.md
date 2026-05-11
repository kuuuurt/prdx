# Case Generator: simplify

Generate test cases for the `/prdx:simplify` command, which rewrites a source
file to remove ceremony per its simplification rules (inline single-use
helpers, drop what-style doc comments, keep MARK/TODO/FIXME, etc.).

Each case is a JSON object on a single line (JSONL):

```json
{
  "id": "simplify-0001",
  "input": {
    "language": "kotlin | swift | typescript | javascript",
    "filePath": "src/auth/UserService.kt",
    "code": "Full file contents (40-150 lines). Realistic — class/function definitions, imports, mix of useful and removable comments. Include AT LEAST one signal the prompt must preserve (a // MARK:, // TODO:, // FIXME:, or why-comment) AND AT LEAST one signal it must remove (a doc comment that restates the function name, or a single-use private helper that should be inlined).",
    "expectations": "One sentence on what a good simplification must preserve and what it must remove for THIS file."
  }
}
```

The `code` field is the literal file content (with `\n` for newlines in the
JSON string).

## Diversity

- **Languages**: 35% kotlin, 25% swift, 25% typescript, 15% javascript
- **File types**: services, view models, repositories, utility files, route
  handlers, components
- **Simplification opportunities**:
  - Doc comments to remove (~all cases)
  - Single-use private helpers (~50%)
  - Single-use variables (~50%)
  - Redundant abstractions (~30%)
- **Preservation traps (~all cases)**: include at least one `// MARK:`,
  `// TODO:`, `// FIXME:`, or genuine why-comment that must NOT be deleted
- **Adversarial (~10%)**:
  - File that is already simple — correct behavior is to return ~unchanged
  - File where a "single-use" helper is actually called twice — should NOT
    be inlined
  - File with a misleading TODO that looks like a doc comment — must keep

## Output

Produce exactly N JSONL lines. No prose, no fences. IDs start at `simplify-0001`.
The `code` field must be valid JSON-escaped (use `\n` for newlines, `\"` for
quotes).
