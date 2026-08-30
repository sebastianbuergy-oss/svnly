import assert from "node:assert/strict";
import test from "node:test";

const workerUrl = new URL("../dist/server/index.js", import.meta.url);

async function render(pathname) {
  const versionedWorkerUrl = new URL(workerUrl);
  versionedWorkerUrl.searchParams.set(
    "test",
    `${process.pid}-${pathname}-${Date.now()}`,
  );
  const { default: worker } = await import(versionedWorkerUrl.href);
  return worker.fetch(
    new Request(`http://localhost${pathname}`, {
      headers: { accept: "text/html" },
      redirect: "manual",
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

const publicRoutes = [
  ["/privacy", "Privacy Policy", "Datenschutzerklärung"],
  ["/support", "How can we help?", "Support"],
  ["/terms", "Terms of Use", "Nutzungsbedingungen"],
  ["/community", "Community Guidelines", "Community-Richtlinien"],
  ["/account-deletion", "Delete your account", "Konto löschen"],
];

for (const [pathname, english, german] of publicRoutes) {
  test(`${pathname} server-renders publicly without authentication`, async () => {
    const response = await render(pathname);
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("location"), null);
    assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

    const html = await response.text();
    assert.match(html, new RegExp(english, "i"));
    assert.match(html, new RegExp(german, "i"));
    assert.match(html, /<nav aria-label="Legal">/i);
    assert.doesNotMatch(html, /sign[ -]?in|log[ -]?in|authentication required/i);
  });
}

test("landing page links every public policy and support route", async () => {
  const response = await render("/");
  assert.equal(response.status, 200);
  const html = await response.text();
  for (const [pathname] of publicRoutes) {
    assert.match(html, new RegExp(`href="${pathname}"`));
  }
  assert.match(html, /SVNLY — 7 seconds\. One take\. Be real\./);
});

test("device installer identifies Codemagic build 12 and its commit", async () => {
  const response = await render("/install/device");
  assert.equal(response.status, 200);
  const html = await response.text();
  assert.match(html, /Codemagic build 12/);
  assert.match(html, /commit 6baff65/);
  assert.match(html, /itms-services:\/\/\?action=download-manifest/);
});

test("OTA manifest targets the signed build 12 IPA", async () => {
  const response = await render("/install/device/manifest.plist");
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^application\/xml\b/i);

  const manifest = await response.text();
  assert.match(
    manifest,
    /https:\/\/svnly\.sebastian-buergy\.chatgpt\.site\/install\/SVNLY-build-12\.ipa/,
  );
  assert.match(manifest, /<key>bundle-identifier<\/key>\s*<string>ch\.sebastianbuergy\.svnly<\/string>/);
  assert.match(manifest, /<key>bundle-version<\/key>\s*<string>12<\/string>/);
});
