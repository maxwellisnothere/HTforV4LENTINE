import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import worker, { UPSTREAM } from "./worker.mjs";

const originalFetch = globalThis.fetch;
let calls = 0;
globalThis.fetch = async (url) => {
  calls += 1;
  assert.equal(url, UPSTREAM);
  return new Response("-- test loader\n", { status: 200 });
};

try {
  let response = await worker.fetch(new Request("https://example.test/loader"));
  assert.equal(response.status, 200);
  assert.equal(await response.text(), "-- test loader\n");
  assert.match(response.headers.get("Content-Type"), /^text\/plain/);
  response = await worker.fetch(new Request("https://example.test/ht/loader", { method: "HEAD" }));
  assert.equal(response.status, 200);
  assert.equal(await response.text(), "");
  const before = calls;
  assert.equal((await worker.fetch(new Request("https://example.test/nope"))).status, 404);
  assert.equal((await worker.fetch(new Request("https://example.test/loader", { method: "POST" }))).status, 405);
  assert.equal(calls, before);
  globalThis.fetch = async () => new Response("missing", { status: 404 });
  assert.equal((await worker.fetch(new Request("https://example.test/loader"))).status, 502);
} finally {
  globalThis.fetch = originalFetch;
}

const manifest = JSON.parse(readFileSync(new URL("../assets/manifest.json", import.meta.url), "utf8"));
assert.equal(Object.keys(manifest.files).length, 9);
for (const [name, entry] of Object.entries(manifest.files)) {
  assert.match(name, /^[\w-]+\.png$/);
  const bytes = Buffer.from(entry.base64, "base64");
  assert.equal(bytes.length, entry.bytes, name);
  assert.equal(bytes.subarray(0, 8).toString("hex"), "89504e470d0a1a0a", name);
}
console.log("Worker routing/error handling and all 9 PNG assets passed");
