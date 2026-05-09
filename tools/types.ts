export interface Case {
  id: string;
  input: {
    request: string;
    projectName: string;
    stack: string;
    codebaseSummary: string;
    // Free-form: lets the judge know what to look for in this specific case.
    expectations?: string;
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
