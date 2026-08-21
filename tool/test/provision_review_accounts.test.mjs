import assert from "node:assert/strict";
import test from "node:test";

import { reviewAccountDefinitions } from "../provision_review_accounts.mjs";

const valid = {
  SUPABASE_URL: "https://example-ref.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "service-role-test-value",
  APP_REVIEW_PRIMARY_EMAIL: "primary@example.com",
  APP_REVIEW_PRIMARY_PASSWORD: "Primary-Review-42!",
  APP_REVIEW_SECONDARY_EMAIL: "secondary@example.com",
  APP_REVIEW_SECONDARY_PASSWORD: "Secondary-Review-42!",
};

test("defines two distinct production review scenarios without exposing passwords", () => {
  const result = reviewAccountDefinitions(valid);
  assert.deepEqual(
    result.accounts.map(({ label, username, isPrivate }) => ({
      label,
      username,
      isPrivate,
    })),
    [
      { label: "primary", username: "review.primary", isPrivate: false },
      { label: "secondary", username: "review.secondary", isPrivate: true },
    ],
  );
});

test("rejects missing secrets, weak passwords and duplicate accounts", () => {
  assert.throws(() => reviewAccountDefinitions({}), /Missing required/);
  assert.throws(
    () =>
      reviewAccountDefinitions({
        ...valid,
        APP_REVIEW_PRIMARY_PASSWORD: "weak",
      }),
    /at least 14/,
  );
  assert.throws(
    () =>
      reviewAccountDefinitions({
        ...valid,
        APP_REVIEW_SECONDARY_EMAIL: valid.APP_REVIEW_PRIMARY_EMAIL,
      }),
    /must be different/,
  );
});
