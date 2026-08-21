const requiredNames = [
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "APP_REVIEW_PRIMARY_EMAIL",
  "APP_REVIEW_PRIMARY_PASSWORD",
  "APP_REVIEW_SECONDARY_EMAIL",
  "APP_REVIEW_SECONDARY_PASSWORD",
];

export function reviewAccountDefinitions(env) {
  const missing = requiredNames.filter((name) => !env[name]?.trim());
  if (missing.length > 0) {
    throw new Error(
      `Missing required review-account variables: ${missing.join(", ")}`,
    );
  }
  const baseUrl = env.SUPABASE_URL.replace(/\/$/, "");
  if (!/^https:\/\/[a-z0-9-]+\.supabase\.co$/i.test(baseUrl)) {
    throw new Error("SUPABASE_URL must be an HTTPS Supabase project URL.");
  }

  const accounts = [
    {
      label: "primary",
      email: env.APP_REVIEW_PRIMARY_EMAIL.trim().toLowerCase(),
      password: env.APP_REVIEW_PRIMARY_PASSWORD,
      username: "review.primary",
      displayName: "Review Primary",
      countryCode: "CH",
      isPrivate: false,
    },
    {
      label: "secondary",
      email: env.APP_REVIEW_SECONDARY_EMAIL.trim().toLowerCase(),
      password: env.APP_REVIEW_SECONDARY_PASSWORD,
      username: "review.secondary",
      displayName: "Review Secondary",
      countryCode: "US",
      isPrivate: true,
    },
  ];
  for (const account of accounts) {
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(account.email)) {
      throw new Error(
        `APP_REVIEW_${account.label.toUpperCase()}_EMAIL is invalid.`,
      );
    }
    if (account.password.length < 14) {
      throw new Error(
        `APP_REVIEW_${account.label.toUpperCase()}_PASSWORD must have at least 14 characters.`,
      );
    }
  }
  if (accounts[0].email === accounts[1].email) {
    throw new Error("The two App Review email addresses must be different.");
  }
  return { baseUrl, serviceKey: env.SUPABASE_SERVICE_ROLE_KEY, accounts };
}

async function request(fetchImpl, url, serviceKey, init = {}) {
  const response = await fetchImpl(url, {
    ...init,
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });
  const body = await response.text();
  if (!response.ok) {
    throw new Error(
      `Supabase request failed (${response.status}) at ${new URL(url).pathname}: ${body.slice(0, 300)}`,
    );
  }
  return body ? JSON.parse(body) : null;
}

async function ensureAuthUser(fetchImpl, config, account) {
  const users = await request(
    fetchImpl,
    `${config.baseUrl}/auth/v1/admin/users?page=1&per_page=1000`,
    config.serviceKey,
  );
  const existing = users.users?.find(
    (user) => user.email?.toLowerCase() === account.email,
  );
  const payload = {
    email: account.email,
    password: account.password,
    email_confirm: true,
    app_metadata: { review_account: true, review_scenario: account.label },
    user_metadata: { display_name: account.displayName },
  };
  if (existing) {
    const updated = await request(
      fetchImpl,
      `${config.baseUrl}/auth/v1/admin/users/${existing.id}`,
      config.serviceKey,
      { method: "PUT", body: JSON.stringify(payload) },
    );
    return updated.user ?? updated;
  }
  const created = await request(
    fetchImpl,
    `${config.baseUrl}/auth/v1/admin/users`,
    config.serviceKey,
    { method: "POST", body: JSON.stringify(payload) },
  );
  return created.user ?? created;
}

async function upsert(fetchImpl, config, table, conflict, rows) {
  await request(
    fetchImpl,
    `${config.baseUrl}/rest/v1/${table}?on_conflict=${encodeURIComponent(conflict)}`,
    config.serviceKey,
    {
      method: "POST",
      headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
      body: JSON.stringify(rows),
    },
  );
}

export async function provisionReviewAccounts(
  env,
  fetchImpl = globalThis.fetch,
) {
  const config = reviewAccountDefinitions(env);
  const users = [];
  for (const account of config.accounts) {
    const user = await ensureAuthUser(fetchImpl, config, account);
    if (!user?.id)
      throw new Error(`Supabase did not return an id for ${account.label}.`);
    users.push({ ...account, id: user.id });
  }

  await upsert(
    fetchImpl,
    config,
    "profiles",
    "id",
    users.map((user) => ({
      id: user.id,
      username: user.username,
      display_name: user.displayName,
      country_code: user.countryCode,
      is_private: user.isPrivate,
      bio: "App Review test profile",
      status: "active",
    })),
  );
  await upsert(
    fetchImpl,
    config,
    "user_private",
    "user_id",
    users.map((user) => ({
      user_id: user.id,
      date_of_birth: "1990-01-01",
      age_verified_at: new Date().toISOString(),
    })),
  );
  await upsert(
    fetchImpl,
    config,
    "user_settings",
    "user_id",
    users.map((user) => ({
      user_id: user.id,
      language_code: "en",
      timezone: "UTC",
    })),
  );
  await upsert(
    fetchImpl,
    config,
    "terms_acceptances",
    "user_id,document_type,version",
    users.flatMap((user) =>
      ["terms", "privacy", "guidelines"].map((documentType) => ({
        user_id: user.id,
        document_type: documentType,
        version: "1.0",
      })),
    ),
  );
  await upsert(fetchImpl, config, "follows", "follower_id,followed_id", [
    {
      follower_id: users[0].id,
      followed_id: users[1].id,
      status: "accepted",
    },
    {
      follower_id: users[1].id,
      followed_id: users[0].id,
      status: "accepted",
    },
  ]);

  const ids = users.map((user) => user.id).join(",");
  const profiles = await request(
    fetchImpl,
    `${config.baseUrl}/rest/v1/profiles?select=id,username,is_private&id=in.(${ids})`,
    config.serviceKey,
  );
  if (!Array.isArray(profiles) || profiles.length !== 2) {
    throw new Error("Review-account verification did not find both profiles.");
  }
  return profiles;
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  try {
    if (process.argv.includes("--validate-only")) {
      reviewAccountDefinitions(process.env);
      console.log("Review-account configuration is valid.");
    } else {
      const profiles = await provisionReviewAccounts(process.env);
      console.log(
        `Provisioned and verified ${profiles.length} App Review accounts.`,
      );
    }
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
import { pathToFileURL } from "node:url";
