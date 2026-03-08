interface Env {
  DOUBAO_API_KEY: string;
  DOUBAO_ENDPOINT_ID: string;
  JUHE_LUNAR_API_KEY: string;
  JUHE_CONSTELLATION_API_KEY: string;
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

export default {
  async fetch(request, env, ctx): Promise<Response> {
    const url = new URL(request.url);

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

  const upstreamResponse = await fetch("https://ark.cn-beijing.volces.com/api/v3/chat/completions", {
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
  const upstreamResponse = await fetch(upstreamURL.toString(), {
    method: "GET",
    headers: {
      accept: "application/json"
    }
  });

  const text = await upstreamResponse.text();
  return new Response(text, {
    status: upstreamResponse.status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": upstreamResponse.ok ? "public, max-age=300" : "no-store"
    }
  });
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
