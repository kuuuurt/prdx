---
description: "Explore codebase or look up documentation"
argument-hint: "[code|docs] [query]"
---

# /prdx:explore - Codebase & Documentation Explorer

Quick exploration without starting a PRD. Delegates to `prdx:code-explorer` or `prdx:docs-explorer` agents running in **isolated context**.

## Usage

```bash
/prdx:explore code "how is authentication handled?"
/prdx:explore docs "React Query mutations"
/prdx:explore                                        # Prompts for type and query
```

## How It Works

This command is a **thin wrapper** that:
1. Parses the exploration type and query
2. Invokes the appropriate agent in isolated context
3. Displays the agent's summary directly

No PRD, no branch, no status tracking. Just answers.

## Workflow

### Step 1: Parse Arguments

**If two arguments provided** (type + query):
- First argument: `code` or `docs`
- Remaining text: the query

**If one argument that looks like a query** (not `code` or `docs`):
- Use AskUserQuestion to determine type:

```
Question: "What kind of exploration?"
Header: "Type"
Options:
  - Label: "Code"
    Description: "Explore the codebase — architecture, patterns, how things work"
  - Label: "Docs"
    Description: "Look up library/API documentation from the web"
```

- Use the provided text as the query

**If no arguments:**
- Use AskUserQuestion to determine type (same as above)
- Then ask for the query:

```
Question: "What do you want to explore?"
Header: "Query"
Options:
  - Label: "Architecture overview"
    Description: "How is the codebase structured?"
  - Label: "Specific feature"
    Description: "How is a specific feature implemented?"
  - Label: "Custom query"
    Description: "Enter your own question"
```

If user selects a preset, use it as the query. If "Custom query", ask the user to type their question.

### Step 2: Invoke Agent

**For code exploration:**

```
subagent_type: "prdx:code-explorer"

prompt: "{QUERY}

Explore the codebase to answer this question. Return a concise summary with key findings and relevant code snippets."
```

**For docs exploration:**

```
subagent_type: "prdx:docs-explorer"

prompt: "{QUERY}

Search for up-to-date documentation to answer this question. Return a concise summary with key examples and links."
```

### Step 3: Display Results

Display the agent's response directly. No formatting wrapper needed — the agent returns a well-structured summary.

After displaying results, show:

```
---
Explore more:
  /prdx:explore code "follow-up question"
  /prdx:explore docs "related topic"
```

## Examples

### Explore Code

```
User: /prdx:explore code "how does the auth middleware work?"

→ prdx:code-explorer agent invoked
→ Agent explores codebase, traces auth middleware
→ Returns summary with key files and patterns

[Agent's summary displayed here]

---
Explore more:
  /prdx:explore code "follow-up question"
  /prdx:explore docs "related topic"
```

### Explore Docs

```
User: /prdx:explore docs "Hono middleware patterns"

→ prdx:docs-explorer agent invoked
→ Agent searches web and Context7 for docs
→ Returns summary with examples and links

[Agent's summary displayed here]

---
Explore more:
  /prdx:explore code "follow-up question"
  /prdx:explore docs "related topic"
```

### Interactive (No Args)

```
User: /prdx:explore

→ Asks: Code or Docs?
→ User: Code
→ Asks: What do you want to explore?
→ User: "how are database migrations handled?"
→ Invokes prdx:code-explorer
→ Displays results
```

## Error Handling

### Invalid Type

```
Unknown exploration type: "{type}"

Valid types:
  code  — Explore the codebase
  docs  — Look up documentation

Usage: /prdx:explore [code|docs] "query"
```

## Key Points

1. **Standalone** — No PRD required
2. **Isolated context** — Agent handles exploration, returns summary only
3. **Two modes** — Code (codebase) and Docs (web/Context7)
4. **Quick** — No planning, no branches, just answers
