// Backend that shells out to `claude -p` instead of hitting the API.
// Uses your Claude Code OAuth/subscription auth — no per-call billing,
// but counts against your plan quota and is slower than the API path.

import type { CallOpts } from "./api.ts";

interface CliResult {
  type: string;
  subtype?: string;
  is_error?: boolean;
  result?: string;
  total_cost_usd?: number;
  duration_ms?: number;
}

let totalCost = 0;
let totalCalls = 0;

export function getCliStats() {
  return { totalCost, totalCalls };
}

export function resetCliStats() {
  totalCost = 0;
  totalCalls = 0;
}

// Map our model strings to Claude Code's --model flag aliases.
function mapModel(m?: string): string {
  if (!m) return "sonnet";
  const lower = m.toLowerCase();
  if (lower.includes("haiku")) return "haiku";
  if (lower.includes("opus")) return "opus";
  return "sonnet";
}

export async function callViaCLI(opts: CallOpts): Promise<string> {
  // Concatenate messages into a single prompt. Our harness only sends a
  // single user turn, so this is loss-free in practice.
  const userText = opts.messages.map((m) => m.content).join("\n\n");

  const args = [
    "-p",
    "--output-format", "json",
    "--no-session-persistence",
    "--disable-slash-commands",
    "--tools", "",
    "--model", mapModel(opts.model),
    "--exclude-dynamic-system-prompt-sections",
    "--setting-sources", "",
  ];
  if (opts.system) args.push("--system-prompt", opts.system);
  args.push(userText);

  // Strip ANTHROPIC_API_KEY so claude uses OAuth/subscription auth instead of
  // any (possibly bad) key inherited from .env or the parent shell.
  const env = { ...process.env };
  delete env.ANTHROPIC_API_KEY;
  delete env.ANTHROPIC_AUTH_TOKEN;

  const proc = Bun.spawn(["claude", ...args], {
    stdin: "ignore",
    stdout: "pipe",
    stderr: "pipe",
    // Run from a neutral cwd so project CLAUDE.md isn't auto-loaded.
    cwd: "/tmp",
    env,
  });

  const stdout = await new Response(proc.stdout).text();
  const stderr = await new Response(proc.stderr).text();
  const exitCode = await proc.exited;

  if (exitCode !== 0) {
    throw new Error(
      `claude CLI exited ${exitCode}\nstderr: ${stderr.slice(0, 500)}\nstdout: ${stdout.slice(0, 500)}`,
    );
  }

  let parsed: CliResult;
  try {
    parsed = JSON.parse(stdout);
  } catch {
    throw new Error(`claude CLI returned non-JSON: ${stdout.slice(0, 500)}`);
  }

  if (parsed.is_error || parsed.subtype !== "success") {
    throw new Error(`claude CLI error: ${JSON.stringify(parsed).slice(0, 500)}`);
  }

  totalCalls++;
  totalCost += parsed.total_cost_usd ?? 0;

  return parsed.result ?? "";
}
