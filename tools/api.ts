// Thin Anthropic wrapper with two backends:
//   - "cli"  → shells out to `claude -p` (uses OAuth/subscription, $0 marginal)
//   - "api"  → direct fetch to api.anthropic.com (needs ANTHROPIC_API_KEY)
// Select via env: PRDX_EVAL_BACKEND=cli|api  (default: cli)

import { callViaCLI } from "./claude-cli.ts";

const API_URL = "https://api.anthropic.com/v1/messages";
const API_VERSION = "2023-06-01";

export type Msg = { role: "user" | "assistant"; content: string };

export interface CallOpts {
  system?: string;
  messages: Msg[];
  model?: string;
  maxTokens?: number;
  temperature?: number;
}

export type Backend = "api" | "cli";

export function getBackend(): Backend {
  const b = (process.env.PRDX_EVAL_BACKEND ?? "cli").toLowerCase();
  if (b !== "api" && b !== "cli") {
    throw new Error(`PRDX_EVAL_BACKEND must be "api" or "cli", got "${b}"`);
  }
  return b as Backend;
}

export async function call(opts: CallOpts): Promise<string> {
  return getBackend() === "cli" ? callViaCLI(opts) : callViaAPI(opts);
}

async function callViaAPI(opts: CallOpts): Promise<string> {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) throw new Error("ANTHROPIC_API_KEY not set (or set PRDX_EVAL_BACKEND=cli)");

  const body = {
    model: opts.model ?? "claude-sonnet-4-6",
    max_tokens: opts.maxTokens ?? 4096,
    temperature: opts.temperature ?? 0,
    ...(opts.system ? { system: opts.system } : {}),
    messages: opts.messages,
  };

  const res = await fetch(API_URL, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": key,
      "anthropic-version": API_VERSION,
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const txt = await res.text();
    throw new Error(`Anthropic API ${res.status}: ${txt}`);
  }

  const json = (await res.json()) as {
    content: Array<{ type: string; text?: string }>;
  };
  return json.content
    .filter((b) => b.type === "text")
    .map((b) => b.text ?? "")
    .join("");
}

// Run an array of async tasks with bounded concurrency.
export async function pool<T, R>(
  items: T[],
  limit: number,
  fn: (item: T, i: number) => Promise<R>,
): Promise<R[]> {
  const out: R[] = new Array(items.length);
  let next = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (true) {
      const i = next++;
      if (i >= items.length) return;
      out[i] = await fn(items[i], i);
    }
  });
  await Promise.all(workers);
  return out;
}
