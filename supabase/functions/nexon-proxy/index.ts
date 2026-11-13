// 넥슨 Open API 중계 (웹 브라우저에서 넥슨 API를 직접 부를 수 없는 문제 해결)
// - 로그인한 사용자만 (verify_jwt + role 'authenticated' 확인)
// - 메이플스토리 경로(/maplestory/v1/...) GET만 중계
// - API 키는 요청마다 받아서 넥슨에 그대로 전달하고 저장하지 않는다
// 응답은 항상 200 + { status, body } (앱이 넥슨 오류 코드를 그대로 해석하도록)

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (status: number, body: string) =>
  new Response(JSON.stringify({ status, body }), {
    headers: { ...cors, "Content-Type": "application/json" },
  });

const error = (status: number, name: string, message: string) =>
  json(status, JSON.stringify({ error: { name, message } }));

/** 서명은 verify_jwt가 이미 확인했다. 여기서는 로그인 사용자 토큰인지(role)만 본다. */
function isSignedIn(req: Request): boolean {
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const part = token.split(".")[1];
  if (!part) return false;
  try {
    const payload = JSON.parse(atob(part.replace(/-/g, "+").replace(/_/g, "/")));
    return payload.role === "authenticated";
  } catch {
    return false;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return error(405, "METHOD", "POST only");
  if (!isSignedIn(req)) return error(401, "AUTH", "로그인이 필요해요");

  let input: { path?: unknown; query?: unknown; key?: unknown };
  try {
    input = await req.json();
  } catch {
    return error(400, "BAD_REQUEST", "invalid json");
  }
  const { path, query, key } = input;
  if (typeof path !== "string" || !/^\/maplestory\/v1\/[a-z0-9\-\/]+$/.test(path)) {
    return error(400, "BAD_REQUEST", "invalid path");
  }
  if (typeof key !== "string" || key.length < 10 || key.length > 300) {
    return error(400, "BAD_REQUEST", "invalid key");
  }

  const url = new URL("https://open.api.nexon.com" + path);
  if (query && typeof query === "object") {
    for (const [k, v] of Object.entries(query as Record<string, unknown>)) {
      if (typeof v === "string" && /^[a-z_]+$/.test(k)) url.searchParams.set(k, v);
    }
  }

  try {
    const res = await fetch(url, { headers: { "x-nxopen-api-key": key } });
    return json(res.status, await res.text());
  } catch (e) {
    return error(502, "UPSTREAM", `넥슨 API 연결 실패: ${e}`);
  }
});
