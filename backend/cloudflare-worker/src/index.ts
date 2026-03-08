interface Env {
  DOUBAO_API_KEY: string;
  DOUBAO_ENDPOINT_ID: string;
  JUHE_LUNAR_API_KEY: string;
  JUHE_CONSTELLATION_API_KEY: string;
  APP_PROXY_TOKEN?: string;
}

interface FortuneGenerationRequest {
  systemPrompt: string;
  userPrompt: string;
}

interface DailyFoodFortune {
  fortune_stars: number;
  analysis: string;
  yi_highlight: string;
  yi_sub: string;
  ji_highlight: string;
  ji_sub: string;
  luck_food: string;
}

interface DoubaoResponse {
  choices?: Array<{
    message?: {
      content?: string;
    };
  }>;
}

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store"
};

const UPSTREAM_TIMEOUT_MS = 12_000;

export default {
  async fetch(request, env, ctx): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/") {
      return healthPage(url);
    }

    if (request.method === "GET" && url.pathname === "/healthz") {
      return healthJSON(url);
    }

    const authError = authorizeRequest(request, env);
    if (authError) {
      return authError;
    }

    if (request.method === "GET" && url.pathname === "/v1/fortune/lunar") {
      return handleCachedGet(request, ctx, 60 * 60 * 12, () => proxyJuheLunar(url, env));
    }

    if (request.method === "GET" && url.pathname === "/v1/fortune/constellation") {
      return handleCachedGet(request, ctx, 60 * 60 * 6, () => proxyJuheConstellation(url, env));
    }

    if (request.method === "POST" && url.pathname === "/v1/food-fortune/generate") {
      return proxyDoubaoFortune(request, env);
    }

    return json(
      {
        error: "not_found",
        message: "Unsupported route"
      },
      404
    );
  }
} satisfies ExportedHandler<Env>;

async function handleCachedGet(
  request: Request,
  ctx: ExecutionContext,
  ttlSeconds: number,
  loader: () => Promise<Response>
): Promise<Response> {
  const cache = (caches as CacheStorage & { default: Cache }).default;
  const cacheKey = new Request(request.url, request);
  const cached = await cache.match(cacheKey);
  if (cached) {
    return cached;
  }

  const response = await loader();
  if (response.ok) {
    const cloned = new Response(response.body, response);
    cloned.headers.set("cache-control", `public, max-age=${ttlSeconds}`);
    ctx.waitUntil(cache.put(cacheKey, cloned.clone()));
    return cloned;
  }

  return response;
}

async function proxyJuheLunar(url: URL, env: Env): Promise<Response> {
  const date = url.searchParams.get("date");
  if (!date) {
    return json({ error: "bad_request", message: "Missing query parameter: date" }, 400);
  }

  if (!env.JUHE_LUNAR_API_KEY) {
    return json({ error: "misconfigured", message: "Missing JUHE_LUNAR_API_KEY" }, 500);
  }

  const upstreamURL = new URL("https://v.juhe.cn/laohuangli/d");
  upstreamURL.searchParams.set("key", env.JUHE_LUNAR_API_KEY);
  upstreamURL.searchParams.set("date", date);

  return proxyJSON(upstreamURL);
}

async function proxyJuheConstellation(url: URL, env: Env): Promise<Response> {
  const consName = url.searchParams.get("consName");
  const type = url.searchParams.get("type") ?? "today";

  if (!consName) {
    return json({ error: "bad_request", message: "Missing query parameter: consName" }, 400);
  }

  if (!env.JUHE_CONSTELLATION_API_KEY) {
    return json({ error: "misconfigured", message: "Missing JUHE_CONSTELLATION_API_KEY" }, 500);
  }

  const upstreamURL = new URL("https://web.juhe.cn/constellation/getAll");
  upstreamURL.searchParams.set("key", env.JUHE_CONSTELLATION_API_KEY);
  upstreamURL.searchParams.set("consName", consName);
  upstreamURL.searchParams.set("type", type);

  return proxyJSON(upstreamURL);
}

async function proxyDoubaoFortune(request: Request, env: Env): Promise<Response> {
  if (!env.DOUBAO_API_KEY || !env.DOUBAO_ENDPOINT_ID) {
    return json({ error: "misconfigured", message: "Missing Doubao secrets" }, 500);
  }

  let payload: FortuneGenerationRequest;
  try {
    payload = await request.json<FortuneGenerationRequest>();
  } catch {
    return json({ error: "bad_request", message: "Invalid JSON body" }, 400);
  }

  if (!payload.systemPrompt || !payload.userPrompt) {
    return json({ error: "bad_request", message: "systemPrompt and userPrompt are required" }, 400);
  }

  let upstreamResponse: Response;
  try {
    upstreamResponse = await fetchWithTimeout("https://ark.cn-beijing.volces.com/api/v3/chat/completions", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${env.DOUBAO_API_KEY}`
      },
      body: JSON.stringify({
        model: env.DOUBAO_ENDPOINT_ID,
        messages: [
          { role: "system", content: payload.systemPrompt },
          { role: "user", content: payload.userPrompt }
        ]
      })
    });
  } catch (error) {
    return upstreamErrorResponse(error, "Doubao");
  }

  if (!upstreamResponse.ok) {
    return json(
      {
        error: "upstream_failed",
        message: "Doubao request failed",
        status: upstreamResponse.status
      },
      502
    );
  }

  const data = await upstreamResponse.json<DoubaoResponse>();
  const rawContent = data.choices?.[0]?.message?.content;
  if (!rawContent) {
    return json({ error: "invalid_upstream_response", message: "Missing Doubao content" }, 502);
  }

  const cleanedJSON = cleanJSONString(rawContent);
  let parsed: DailyFoodFortune;
  try {
    parsed = JSON.parse(cleanedJSON) as DailyFoodFortune;
  } catch {
    return json({ error: "invalid_upstream_response", message: "Doubao returned invalid JSON payload" }, 502);
  }

  if (!isValidFortune(parsed)) {
    return json({ error: "invalid_upstream_response", message: "Doubao payload shape mismatch" }, 502);
  }

  return json(parsed, 200);
}

async function proxyJSON(upstreamURL: URL): Promise<Response> {
  let upstreamResponse: Response;
  try {
    upstreamResponse = await fetchWithTimeout(upstreamURL.toString(), {
      method: "GET",
      headers: {
        accept: "application/json"
      }
    });
  } catch (error) {
    return upstreamErrorResponse(error, upstreamURL.hostname);
  }

  const text = await upstreamResponse.text();
  return new Response(text, {
    status: upstreamResponse.status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": upstreamResponse.ok ? "public, max-age=300" : "no-store"
    }
  });
}

function authorizeRequest(request: Request, env: Env): Response | null {
  const expectedToken = normalizeToken(env.APP_PROXY_TOKEN);
  if (!expectedToken) {
    return null;
  }

  const bearerToken = extractBearerToken(request.headers.get("authorization"));
  const fallbackToken = normalizeToken(request.headers.get("x-whattoeat-token"));
  if (bearerToken === expectedToken || fallbackToken === expectedToken) {
    return null;
  }

  return json(
    {
      error: "unauthorized",
      message: "Missing or invalid proxy token"
    },
    401
  );
}

function extractBearerToken(headerValue: string | null): string | null {
  if (!headerValue) {
    return null;
  }

  const trimmed = headerValue.trim();
  if (!trimmed.toLowerCase().startsWith("bearer ")) {
    return null;
  }

  return normalizeToken(trimmed.slice(7));
}

function normalizeToken(value: string | null | undefined): string | null {
  const trimmed = value?.trim();
  return trimmed ? trimmed : null;
}

async function fetchWithTimeout(input: RequestInfo | URL, init: RequestInit): Promise<Response> {
  const signal = AbortSignal.timeout(UPSTREAM_TIMEOUT_MS);
  return fetch(input, {
    ...init,
    signal
  });
}

function upstreamErrorResponse(error: unknown, provider: string): Response {
  if (isTimeoutError(error)) {
    return json(
      {
        error: "upstream_timeout",
        message: `${provider} request timed out`
      },
      504
    );
  }

  return json(
    {
      error: "upstream_failed",
      message: `${provider} request failed`
    },
    502
  );
}

function isTimeoutError(error: unknown): boolean {
  return error instanceof DOMException && error.name === "TimeoutError";
}

function cleanJSONString(rawString: string): string {
  let cleaned = rawString;

  const jsonMarkerIndex = cleaned.indexOf("```json");
  const codeMarkerIndex = cleaned.indexOf("```");
  if (jsonMarkerIndex >= 0) {
    cleaned = cleaned.slice(jsonMarkerIndex + 7);
  } else if (codeMarkerIndex >= 0) {
    cleaned = cleaned.slice(codeMarkerIndex + 3);
  }

  const trailingMarkerIndex = cleaned.lastIndexOf("```");
  if (trailingMarkerIndex >= 0) {
    cleaned = cleaned.slice(0, trailingMarkerIndex);
  }

  cleaned = cleaned.trim();

  const firstBrace = cleaned.indexOf("{");
  const lastBrace = cleaned.lastIndexOf("}");
  if (firstBrace >= 0 && lastBrace > firstBrace) {
    cleaned = cleaned.slice(firstBrace, lastBrace + 1);
  }

  return cleaned;
}

function isValidFortune(value: unknown): value is DailyFoodFortune {
  if (!value || typeof value !== "object") {
    return false;
  }

  const record = value as Record<string, unknown>;
  return typeof record.fortune_stars === "number" &&
    typeof record.analysis === "string" &&
    typeof record.yi_highlight === "string" &&
    typeof record.yi_sub === "string" &&
    typeof record.ji_highlight === "string" &&
    typeof record.ji_sub === "string" &&
    typeof record.luck_food === "string";
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: JSON_HEADERS
  });
}

function healthPage(url: URL): Response {
  const html = `<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>WhatToEat API</title>
    <style>
      :root {
        color-scheme: light;
        --bg: #f6f3ee;
        --card: #fffdf8;
        --text: #1f1b16;
        --muted: #6f655b;
        --accent: #d86f45;
        --line: #eadfd3;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        font-family: ui-rounded, "SF Pro Rounded", "PingFang SC", "Hiragino Sans GB", sans-serif;
        background:
          radial-gradient(circle at top left, rgba(216,111,69,0.14), transparent 28%),
          radial-gradient(circle at bottom right, rgba(145,187,158,0.18), transparent 24%),
          var(--bg);
        color: var(--text);
      }
      main {
        min-height: 100vh;
        display: grid;
        place-items: center;
        padding: 24px;
      }
      .card {
        width: min(720px, 100%);
        background: rgba(255,253,248,0.88);
        backdrop-filter: blur(18px);
        border: 1px solid var(--line);
        border-radius: 28px;
        padding: 28px;
        box-shadow: 0 18px 60px rgba(31,27,22,0.08);
      }
      .badge {
        display: inline-flex;
        align-items: center;
        gap: 8px;
        padding: 8px 12px;
        border-radius: 999px;
        background: rgba(216,111,69,0.1);
        color: var(--accent);
        font-size: 13px;
        font-weight: 700;
      }
      h1 {
        margin: 18px 0 8px;
        font-size: clamp(28px, 4vw, 42px);
        line-height: 1.05;
      }
      p {
        margin: 0;
        color: var(--muted);
        line-height: 1.7;
        font-size: 15px;
      }
      ul {
        margin: 22px 0 0;
        padding: 0;
        list-style: none;
        display: grid;
        gap: 12px;
      }
      li {
        padding: 14px 16px;
        border-radius: 18px;
        border: 1px solid var(--line);
        background: rgba(255,255,255,0.7);
      }
      code {
        font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
        font-size: 13px;
        word-break: break-all;
      }
      .meta {
        margin-top: 22px;
        padding-top: 18px;
        border-top: 1px solid var(--line);
        color: var(--muted);
        font-size: 13px;
      }
    </style>
  </head>
  <body>
    <main>
      <section class="card">
        <div class="badge">WhatToEat API · HEALTHY</div>
        <h1>后端代理已在线</h1>
        <p>这个 Worker 正在为 WhatToEat App 提供 AI 食签、黄历和星座运势代理服务。根路径用于健康检查，实际业务请访问以下接口。</p>
        <ul>
          <li><code>GET ${url.origin}/v1/fortune/lunar?date=2026-03-08</code></li>
          <li><code>GET ${url.origin}/v1/fortune/constellation?consName=射手座&type=today</code></li>
          <li><code>POST ${url.origin}/v1/food-fortune/generate</code></li>
        </ul>
        <div class="meta">status: ok · deployed on Cloudflare Workers</div>
      </section>
    </main>
  </body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "no-store"
    }
  });
}

function healthJSON(url: URL): Response {
  return json({
    status: "ok",
    service: "whattoeat-api",
    version: "2026-03-08",
    routes: {
      root: `${url.origin}/`,
      healthz: `${url.origin}/healthz`,
      lunar: `${url.origin}/v1/fortune/lunar?date=2026-03-08`,
      constellation: `${url.origin}/v1/fortune/constellation?consName=射手座&type=today`,
      fortune: `${url.origin}/v1/food-fortune/generate`
    }
  });
}
