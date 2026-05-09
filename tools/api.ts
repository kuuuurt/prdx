// Thin Anthropic API wrapper. No SDK dep — just fetch.

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

export async function call(opts: CallOpts): Promise<string> {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) throw new Error("ANTHROPIC_API_KEY not set");

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
