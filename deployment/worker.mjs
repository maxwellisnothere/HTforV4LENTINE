// Optional standalone Cloudflare Worker for a DEDICATED HT loader endpoint.
// Existing api.dukehub.lol/loader has another live loader; use loader-dispatch.luau
// in that service to preserve its existing behavior instead of replacing it.
export const UPSTREAM = "https://raw.githubusercontent.com/maxwellisnothere/HTforV4LENTINE/main/loader.luau";

export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname !== "/loader" && url.pathname !== "/ht/loader") {
      return new Response("Not found", { status: 404 });
    }
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method not allowed", { status: 405, headers: { Allow: "GET, HEAD" } });
    }
    const upstream = await fetch(UPSTREAM, {
      headers: { Accept: "text/plain" },
      cf: { cacheTtl: 30, cacheEverything: true },
    });
    if (!upstream.ok) return new Response("Loader unavailable", { status: 502 });
    return new Response(request.method === "HEAD" ? null : upstream.body, {
      headers: {
        "Content-Type": "text/plain; charset=utf-8",
        "Cache-Control": "public, max-age=30",
        "X-Content-Type-Options": "nosniff",
      },
    });
  },
};
