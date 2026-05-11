// Each artifact has its own input shape. Kept as a permissive bag since each
// artifact's buildUserMessage knows what fields it needs. The `expectations`
// field is shared — it's a free-form hint passed to the judge.
export interface Case {
  id: string;
  input: {
    expectations?: string;
    // plan
    request?: string;
    projectName?: string;
    stack?: string;
    codebaseSummary?: string;
    // publish
    prdMarkdown?: string;
    isChild?: boolean;
    parentIssue?: number | null;
    // pr-author
    issueNumber?: number | null;
    branchName?: string;
    commitSummaries?: string;
    diffSummary?: string;
    // simplify
    language?: string;
    filePath?: string;
    code?: string;
    [key: string]: unknown;
  };
}

export type StructuralCheck = (output: string, c: Case) => Record<string, boolean>;

export interface JudgeAxisScore {
  axis: string;
  score: number; // 1-5
  rationale: string;
}

export interface CaseResult {
  case_id: string;
  output: string;
  structural: Record<string, boolean>;
  structural_score: number;
  graded: JudgeAxisScore[];
  graded_score: number;
  case_score: number;
  error?: string;
}

export interface RunResult {
  run_id: string;
  artifact: string;
  prompt_hash: string;
  prompt_path: string;
  created_at: string;
  aggregate: number;
  structural_avg: number;
  graded_avg: number;
  per_axis: Record<string, number>;
  cases: CaseResult[];
}
