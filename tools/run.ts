#!/usr/bin/env bun
import { readFile, writeFile, mkdir, readdir, stat } from "node:fs/promises";
import { existsSync } from "node:fs";
import { createHash } from "node:crypto";
import { join, dirname, resolve } from "node:path";
import { call, pool, getBackend } from "./api.ts";
import { getCliStats, resetCliStats } from "./claude-cli.ts";
import { judge } from "./judge.ts";
import { getArtifact, ARTIFACTS } from "./artifacts.ts";
import type { Case, CaseResult, RunResult } from "./types.ts";

const REPO_ROOT = resolve(import.meta.dir, "..");
const EVAL_ROOT = import.meta.dir;
const RUNS_DIR = join(EVAL_ROOT, "runs");
const CACHE_DIR = join(RUNS_DIR, ".cache");
const CASES_DIR = join(EVAL_ROOT, "cases");

// Lower concurrency on CLI backend: each call spawns a Claude Code process
// and parallel spawns can hit subscription rate limits / be slow.
const CONCURRENCY = getBackend() === "cli" ? 3 : 8;

// ─── helpers ────────────────────────────────────────────────────────────────

const sha = (s: string) => createHash("sha256").update(s).digest("hex").slice(0, 12);

async function readRepoFile(rel: string): Promise<string> {
  return readFile(join(REPO_ROOT, rel), "utf-8");
}

function stripFrontmatter(md: string): string {
  // Slash-command/agent files often start with --- frontmatter ---
  const m = md.match(/^---\n[\s\S]*?\n---\n/);
  return m ? md.slice(m[0].length) : md;
}

async function loadCases(artifact: string): Promise<Case[]> {
  const path = join(CASES_DIR, `${artifact}.jsonl`);
  if (!existsSync(path)) {
    throw new Error(`No cases at ${path}. Run: bun run.ts generate ${artifact} --n 100`);
  }
  const lines = (await readFile(path, "utf-8")).split("\n").filter((l) => l.trim());
  return lines.map((l, i) => {
    try {
      return JSON.parse(l) as Case;
    } catch (e) {
      throw new Error(`Bad JSON on line ${i + 1} of ${path}: ${e}`);
    }
  });
}

async function ensureDir(p: string) {
  if (!existsSync(p)) await mkdir(p, { recursive: true });
}

function mean(xs: number[]): number {
  return xs.length === 0 ? 0 : xs.reduce((a, b) => a + b, 0) / xs.length;
}

// Strip an outer markdown fence the model sometimes wraps the whole PRD in
// when invoked as a pure function (an artifact of API/CLI invocation, not of
// commands/plan.md itself).
function stripOuterFence(s: string): string {
  const t = s.trim();
  const m = t.match(/^```(?:[a-zA-Z]+)?\n([\s\S]*?)\n```\s*$/);
  return m ? m[1] : s;
}

// ─── generate ───────────────────────────────────────────────────────────────

async function cmdGenerate(artifact: string, n: number) {
  const a = getArtifact(artifact);
  const generator = await readRepoFile(a.generatorPath);

  console.log(`Generating ${n} cases for ${artifact}...`);

  // Generate in batches of 25 so each call stays within reasonable token limits
  // and we can recover from a single bad batch.
  const batchSize = 25;
  const batches = Math.ceil(n / batchSize);
  const lines: string[] = [];

  for (let b = 0; b < batches; b++) {
    const want = Math.min(batchSize, n - b * batchSize);
    const offset = b * batchSize;
    const userMsg = [
      generator,
      ``,
      `Produce exactly ${want} JSONL lines.`,
      `Start IDs at ${String(offset + 1).padStart(4, "0")}.`,
    ].join("\n");

    process.stdout.write(`  batch ${b + 1}/${batches}... `);
    const raw = await call({
      messages: [{ role: "user", content: userMsg }],
      temperature: 0.8,
      maxTokens: 8192,
    });
    const batchLines = raw
      .trim()
      .split("\n")
      .map((l) => l.trim())
      .filter((l) => l.startsWith("{"));

    let kept = 0;
    for (const l of batchLines) {
      try {
        JSON.parse(l);
        lines.push(l);
        kept++;
      } catch {
        // Skip malformed lines silently.
      }
    }
    console.log(`${kept} cases`);
  }

  await ensureDir(CASES_DIR);
  const path = join(CASES_DIR, `${artifact}.jsonl`);
  await writeFile(path, lines.join("\n") + "\n");
  console.log(`Wrote ${lines.length} cases → ${path}`);
}

// ─── eval ───────────────────────────────────────────────────────────────────

async function cmdEval(artifact: string) {
  const a = getArtifact(artifact);
  const promptRaw = await readRepoFile(a.promptPath);
  const promptSystem = stripFrontmatter(promptRaw);
  const promptHash = sha(promptSystem);
  const rubric = await readRepoFile(a.rubricPath);
  const cases = await loadCases(artifact);

  const runId = `${new Date().toISOString().slice(0, 10)}-${promptHash}-${Date.now().toString(36).slice(-4)}`;
  console.log(
    `Eval ${artifact}  prompt=${promptHash}  cases=${cases.length}  backend=${getBackend()}  concurrency=${CONCURRENCY}  run=${runId}`,
  );

  resetCliStats();
  await ensureDir(CACHE_DIR);

  let done = 0;
  const results = await pool(cases, CONCURRENCY, async (c) => {
    const r = await scoreCase(a, promptSystem, promptHash, rubric, c);
    done++;
    process.stdout.write(`\r  ${done}/${cases.length} cases`);
    return r;
  });
  process.stdout.write("\n");

  const ok = results.filter((r) => !r.error);
  const aggregate = mean(ok.map((r) => r.case_score));
  const structuralAvg = mean(ok.map((r) => r.structural_score));
  const gradedAvg = mean(ok.map((r) => r.graded_score));

  const perAxis: Record<string, number[]> = {};
  for (const r of ok) for (const g of r.graded) (perAxis[g.axis] ??= []).push((g.score - 1) / 4);
  const perAxisMean = Object.fromEntries(Object.entries(perAxis).map(([k, v]) => [k, mean(v)]));

  const run: RunResult = {
    run_id: runId,
    artifact,
    prompt_hash: promptHash,
    prompt_path: a.promptPath,
    created_at: new Date().toISOString(),
    aggregate,
    structural_avg: structuralAvg,
    graded_avg: gradedAvg,
    per_axis: perAxisMean,
    cases: results,
  };

  await ensureDir(RUNS_DIR);
  const runPath = join(RUNS_DIR, `${runId}.json`);
  await writeFile(runPath, JSON.stringify(run, null, 2));

  console.log("");
  console.log(`aggregate:      ${aggregate.toFixed(3)}`);
  console.log(`  structural:   ${structuralAvg.toFixed(3)}`);
  console.log(`  graded:       ${gradedAvg.toFixed(3)}`);
  console.log("per axis:");
  for (const [k, v] of Object.entries(perAxisMean)) console.log(`  ${k.padEnd(24)} ${v.toFixed(3)}`);
  if (results.some((r) => r.error)) {
    const errs = results.filter((r) => r.error);
    console.log(`\nerrors: ${errs.length}`);
    for (const e of errs.slice(0, 5)) console.log(`  ${e.case_id}: ${e.error}`);
  }
  if (getBackend() === "cli") {
    const stats = getCliStats();
    console.log(
      `\ncli stats: ${stats.totalCalls} calls, list-price equivalent $${stats.totalCost.toFixed(3)} (counts against subscription quota; no charge with OAuth)`,
    );
  }
  console.log(`\nrun saved → ${runPath}`);
}

async function scoreCase(
  a: ReturnType<typeof getArtifact>,
  promptSystem: string,
  promptHash: string,
  rubric: string,
  c: Case,
): Promise<CaseResult> {
  const cacheKey = `${a.name}-${c.id}-${promptHash}-${sha(JSON.stringify(c.input))}`;
  const cachePath = join(CACHE_DIR, `${cacheKey}.json`);
  if (existsSync(cachePath)) {
    return JSON.parse(await readFile(cachePath, "utf-8"));
  }

  let result: CaseResult;
  try {
    const raw = await call({
      model: a.model,
      system: promptSystem,
      messages: [{ role: "user", content: a.buildUserMessage(c) }],
      temperature: 0,
      maxTokens: a.maxTokens,
    });
    const output = stripOuterFence(raw);

    const structural = a.structural(output, c);
    const passed = Object.values(structural).filter(Boolean).length;
    const total = Object.values(structural).length;
    const structuralScore = total === 0 ? 0 : passed / total;

    const graded = await judge(rubric, c, output);
    const gradedScore = mean(graded.map((g) => (g.score - 1) / 4));

    const caseScore =
      a.structuralWeight * structuralScore + (1 - a.structuralWeight) * gradedScore;

    result = {
      case_id: c.id,
      output,
      structural,
      structural_score: structuralScore,
      graded,
      graded_score: gradedScore,
      case_score: caseScore,
    };
  } catch (e: any) {
    result = {
      case_id: c.id,
      output: "",
      structural: {},
      structural_score: 0,
      graded: [],
      graded_score: 0,
      case_score: 0,
      error: e?.message ?? String(e),
    };
  }

  await writeFile(cachePath, JSON.stringify(result, null, 2));
  return result;
}

// ─── diff ───────────────────────────────────────────────────────────────────

async function cmdDiff(idA: string, idB: string) {
  const a = await loadRun(idA);
  const b = await loadRun(idB);
  console.log(`A: ${a.run_id}  prompt=${a.prompt_hash}  ${a.created_at}`);
  console.log(`B: ${b.run_id}  prompt=${b.prompt_hash}  ${b.created_at}`);
  console.log("");
  diffLine("aggregate", a.aggregate, b.aggregate);
  diffLine("  structural", a.structural_avg, b.structural_avg);
  diffLine("  graded", a.graded_avg, b.graded_avg);
  console.log("per axis:");
  const axes = new Set([...Object.keys(a.per_axis), ...Object.keys(b.per_axis)]);
  for (const ax of axes) diffLine(`  ${ax}`, a.per_axis[ax] ?? 0, b.per_axis[ax] ?? 0);

  // Per-case regressions
  const aMap = new Map(a.cases.map((c) => [c.case_id, c.case_score]));
  const regressed: Array<[string, number, number]> = [];
  for (const c of b.cases) {
    const prev = aMap.get(c.case_id);
    if (prev != null && c.case_score < prev - 0.1) regressed.push([c.case_id, prev, c.case_score]);
  }
  if (regressed.length) {
    console.log(`\nregressed cases (>0.1 drop):`);
    regressed.sort((x, y) => x[2] - x[1] - (y[2] - y[1]));
    for (const [id, p, n] of regressed.slice(0, 10)) {
      console.log(`  ${id}: ${p.toFixed(3)} → ${n.toFixed(3)}  (${(n - p).toFixed(3)})`);
    }
  }
}

function diffLine(label: string, a: number, b: number) {
  const d = b - a;
  const arrow = d > 0.001 ? "▲" : d < -0.001 ? "▼" : " ";
  const sign = d >= 0 ? "+" : "";
  console.log(`${label.padEnd(24)}  ${a.toFixed(3)} → ${b.toFixed(3)}  ${arrow} ${sign}${d.toFixed(3)}`);
}

async function loadRun(id: string): Promise<RunResult> {
  // Allow prefix match.
  const files = await readdir(RUNS_DIR);
  const match = files.find((f) => f.startsWith(id) && f.endsWith(".json"));
  if (!match) throw new Error(`No run matching "${id}" in ${RUNS_DIR}`);
  return JSON.parse(await readFile(join(RUNS_DIR, match), "utf-8"));
}

// ─── runs (list) ────────────────────────────────────────────────────────────

async function cmdRuns(artifact?: string) {
  if (!existsSync(RUNS_DIR)) return console.log("no runs yet");
  const files = (await readdir(RUNS_DIR)).filter((f) => f.endsWith(".json"));
  const rows: Array<{ id: string; artifact: string; hash: string; agg: number; t: string }> = [];
  for (const f of files) {
    const r = JSON.parse(await readFile(join(RUNS_DIR, f), "utf-8")) as RunResult;
    if (artifact && r.artifact !== artifact) continue;
    rows.push({ id: r.run_id, artifact: r.artifact, hash: r.prompt_hash, agg: r.aggregate, t: r.created_at });
  }
  rows.sort((a, b) => a.t.localeCompare(b.t));
  for (const r of rows) {
    console.log(`${r.t}  ${r.artifact.padEnd(12)} prompt=${r.hash}  agg=${r.agg.toFixed(3)}  ${r.id}`);
  }
}

// ─── CLI ────────────────────────────────────────────────────────────────────

function parseFlag(args: string[], name: string): string | undefined {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
}

const [, , cmd, ...rest] = process.argv;

try {
  switch (cmd) {
    case "generate": {
      const artifact = rest[0];
      const n = Number(parseFlag(rest, "--n") ?? 100);
      if (!artifact) throw new Error("usage: generate <artifact> --n <count>");
      await cmdGenerate(artifact, n);
      break;
    }
    case "eval": {
      const artifact = rest[0];
      if (!artifact) throw new Error("usage: eval <artifact>");
      await cmdEval(artifact);
      break;
    }
    case "diff": {
      const [a, b] = rest;
      if (!a || !b) throw new Error("usage: diff <run_id_a> <run_id_b>");
      await cmdDiff(a, b);
      break;
    }
    case "runs": {
      await cmdRuns(rest[0]);
      break;
    }
    default:
      console.log(`PRDX evals (tools/)
usage:
  bun run.ts generate <artifact> --n <count>
  bun run.ts eval <artifact>
  bun run.ts diff <run_id_a> <run_id_b>
  bun run.ts runs [artifact]

artifacts: ${Object.keys(ARTIFACTS).join(", ")}`);
  }
} catch (e: any) {
  console.error(`error: ${e?.message ?? e}`);
  process.exit(1);
}
