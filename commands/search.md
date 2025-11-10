# Search PRDs

Search for PRDs by keyword or phrase across all content.

## Usage

```bash
/prdx:search <keyword> [additional keywords...]
/prdx:search "exact phrase"
```

## Examples

```bash
/prdx:search auth0              # Find PRDs mentioning "auth0"
/prdx:search "memory leak"      # Find exact phrase
/prdx:search viewmodel state    # Find PRDs with both terms
```

## Instructions

You are helping the user search through PRD content to find relevant documents.

### Steps

1. **Parse search query**:
   - Extract all search terms
   - Handle quoted phrases as exact matches
   - Make search case-insensitive

2. **Search PRD files**:
   ```bash
   grep -r -i "<keyword>" .claude/prds --include="*.md" --exclude-dir=templates
   ```
   - Search all `.md` files in `.claude/prds/`
   - Exclude template directory
   - Use case-insensitive search
   - For multiple keywords, show PRDs that contain ANY keyword (OR logic)

3. **Parse matches** and extract:
   - **File name** and **path**
   - **Title** (from first line)
   - **Platform** and **Status** (from metadata)
   - **Section** where match was found (Problem, Goal, Approach, etc.)
   - **Context**: 1-2 lines around the match with the keyword highlighted

4. **Rank results** by relevance:
   - Title matches: highest priority
   - Metadata matches: high priority
   - Section heading matches: medium priority
   - Content matches: normal priority
   - Multiple keyword matches: boost ranking

5. **Display results** in a clear format:

```
Found 5 PRDs matching "auth0":

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Optimize LoginViewModel (android-optimize-loginviewmodel.md)
   Platform: android | Status: draft | Created: 2025-11-05

   [Problem]
   ...uses DoLoginUseCase/ConfirmOtpUseCase which just wrap **Auth0Client** calls.
   This violates the project's architectural direction...

   [Goal]
   Simplify LoginViewModel by calling **Auth0Client** directly and using UIState...

   [3 matches total]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

2. Fix Auth0 Token Refresh (backend-fix-auth0-token-refresh.md)
   Platform: backend | Status: in-progress | Created: 2025-11-03 | Issue: #215

   [Title]
   Fix **Auth0** Token Refresh

   [Problem]
   The **Auth0** token refresh mechanism is not properly handling expired tokens...

   [5 matches total]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

3. Add Biometric Authentication (ios-biometric-auth.md)
   Platform: ios | Status: draft | Created: 2025-11-02

   [Approach]
   ...integrate with existing **Auth0** authentication flow and use LocalAuthentication...

   [1 match total]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Summary: 5 PRDs found (9 total matches)
Platforms: android (1), backend (3), ios (1)
Statuses: draft (3), in-progress (2)
```

6. **Search tips** (show if no results):
   ```
   No PRDs found matching "xyz".

   Search tips:
   - Try different keywords or synonyms
   - Use /prdx:list to browse all PRDs
   - Check spelling and try singular/plural variations
   - Use broader terms (e.g., "auth" instead of "authentication")
   ```

## Advanced Features

- **Section filtering** with `--section` flag:
  ```bash
  /prdx:search auth0 --section "Problem"
  ```
  Only search within specific sections (Problem, Goal, Approach, Implementation)

- **Platform filtering** with `--platform` flag:
  ```bash
  /prdx:search viewmodel --platform android
  ```
  Only search PRDs for specific platform

- **Regex support** with `--regex` flag:
  ```bash
  /prdx:search "Auth0.*Client" --regex
  ```
  Use regular expressions for advanced patterns

- **Open PRD** directly from results:
  ```
  Enter number to view PRD (1-5), or press Enter to exit: 2
  → Opening: backend-fix-auth0-token-refresh.md
  ```

## Implementation Notes

- Use `grep` for fast searching across all files
- Highlight matches with **bold** or color (if terminal supports it)
- Limit context to 100 characters before/after match
- If more than 10 PRDs match, show top 10 and mention total count
- Cache results for follow-up refinement (optional)

## Edge Cases

- Handle special characters in search terms (escape for grep)
- If search term is too short (<2 chars), warn:
  ```
  Search term too short. Please use at least 2 characters.
  ```
- Handle PRDs with malformed structure gracefully
- Show partial results even if some files can't be parsed

## Integration with Other Commands

- Suggest related commands:
  ```
  Found what you're looking for?
  - View details: Read the file directly
  - Start work: /prdx:dev:start <slug>
  - Update PRD: /prdx:update <slug>
  ```
