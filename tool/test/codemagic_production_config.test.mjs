import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const yaml = await readFile(new URL("../../codemagic.yaml", import.meta.url), "utf8");

function workflow(name, nextName) {
  const start = yaml.indexOf(`  ${name}:`);
  assert.notEqual(start, -1, `missing workflow ${name}`);
  const end = nextName ? yaml.indexOf(`  ${nextName}:`, start + 1) : yaml.length;
  assert.notEqual(end, -1, `missing workflow boundary ${nextName}`);
  return yaml.slice(start, end);
}

test("device and release builds import production config and fail closed", () => {
  assert.match(yaml, /groups:\s*\n\s*- svnly_production/);
  assert.match(yaml, /production_config_gate: &production_config_gate/);
  assert.match(yaml, /for name in SUPABASE_URL SUPABASE_PUBLISHABLE_KEY/);
  assert.match(yaml, /SUPABASE_PUBLISHABLE_KEY.*sb_publishable_/s);
  assert.match(yaml, /release_identity_gate: &release_identity_gate/);

  const device = workflow("svnly-ios-device", "svnly-testflight-internal");
  const simulator = workflow("svnly-ios-simulator", "svnly-tests");
  const release = workflow("svnly-ios-release", null);

  assert.doesNotMatch(simulator, /production_config_gate/);

  for (const [name, config] of [["device", device], ["release", release]]) {
    const gate = config.indexOf("- *production_config_gate");
    const build = config.indexOf("flutter build ipa --release");
    assert.ok(gate >= 0, `${name} workflow is missing the production config gate`);
    assert.ok(build > gate, `${name} workflow must validate config before building`);
    assert.match(config, /--dart-define=SUPABASE_URL="\$SUPABASE_URL"/);
    assert.match(config, /--dart-define=SUPABASE_PUBLISHABLE_KEY="\$SUPABASE_PUBLISHABLE_KEY"/);
    assert.match(config, /--dart-define=GIT_COMMIT_SHA="\$CM_COMMIT"/);
    assert.match(config, /--dart-define=APP_BUILD_NUMBER=/);
    assert.doesNotMatch(config, /--dart-define=SUPABASE_SERVICE_ROLE_KEY/);
  }

  assert.match(yaml, /CM_BRANCH.*main/);
  assert.match(yaml, /CM_COMMIT/);
  assert.match(yaml, /com\.apple\.developer\.applesignin/);
  assert.match(yaml, /auth_google/);
  assert.match(device, /Enable Sign in with Apple before Ad Hoc provisioning/);
  assert.ok(
    device.indexOf("enable_apple_sign_in.py") < device.indexOf("--type IOS_APP_ADHOC"),
    "Apple capability must be enabled before the Ad Hoc profile is generated",
  );
  assert.match(device, /build\/release-identity\.txt/);
  assert.match(device, /--build-number="\$BUILD_NUMBER"/);
  assert.match(device, /--dart-define=APP_BUILD_NUMBER="\$BUILD_NUMBER"/);
  assert.doesNotMatch(device, /CM_BUILD_NUMBER/);
});
