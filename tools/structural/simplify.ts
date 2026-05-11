// Deterministic checks on the simplified code that /prdx:simplify produces.
// Eval invocation gives the prompt a single file's worth of source code; the
// expected output is the simplified version of that same file (we instruct
// the prompt to emit the full file content).

import type { Case } from "../types.ts";

const KEEP_COMMENT_RE = /^\s*(\/\/\s*(MARK|TODO|FIXME)\b|\/\*\s*(MARK|TODO|FIXME)\b)/i;
const DOC_COMMENT_RE = /^\s*(\/\/|#|\/\*\*?)/;

export function check(output: string, c: Case): Record<string, boolean> {
  const cleaned = stripCodeFence(output);
  const inputLines = c.input.code?.split("\n") ?? [];
  const outputLines = cleaned.split("\n");

  const inputCommentLines = inputLines.filter(
    (l) => DOC_COMMENT_RE.test(l) && !KEEP_COMMENT_RE.test(l),
  ).length;
  const outputCommentLines = outputLines.filter(
    (l) => DOC_COMMENT_RE.test(l) && !KEEP_COMMENT_RE.test(l),
  ).length;

  const inputKept = inputLines.filter((l) => KEEP_COMMENT_RE.test(l)).length;
  const outputKept = outputLines.filter((l) => KEEP_COMMENT_RE.test(l)).length;

  return {
    output_not_empty: cleaned.trim().length > 0,
    not_truncated: !cleaned.trim().endsWith("..."),
    no_obvious_refusal: !/(i can't|i cannot|sorry)/i.test(cleaned.slice(0, 200)),
    not_longer_than_input:
      cleaned.length <= (c.input.code?.length ?? 0) * 1.05, // 5% tolerance
    doc_comments_reduced_or_equal: outputCommentLines <= inputCommentLines,
    mark_todo_fixme_preserved: outputKept >= inputKept,
    no_added_explanation_prose:
      !/^this (function|class|file|module)\b/im.test(cleaned),
  };
}

function stripCodeFence(s: string): string {
  const t = s.trim();
  const m = t.match(/^```(?:[a-zA-Z0-9_+-]+)?\n([\s\S]*?)\n```\s*$/);
  return m ? m[1] : s;
}
