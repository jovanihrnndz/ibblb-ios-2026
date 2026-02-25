import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  schema: string;
  record: {
    id: string;
    title: string;
    speaker: string;
    [key: string]: unknown;
  };
  old_record: unknown;
}

interface DeviceToken {
  token: string;
}

interface ApnsResult {
  token: string;
  status: number;
  reason?: string;
}

// ---------------------------------------------------------------------------
// APNs JWT (ES256, no external dependencies — Deno crypto.subtle)
// ---------------------------------------------------------------------------

/** Convert a Base64URL string to a Uint8Array. */
function base64UrlToBytes(base64url: string): Uint8Array {
  const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/");
  const padded = base64.padEnd(base64.length + (4 - (base64.length % 4)) % 4, "=");
  return Uint8Array.from(atob(padded), (c) => c.charCodeAt(0));
}

/** Encode a Uint8Array to Base64URL (no padding). */
function bytesToBase64Url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");
}

/**
 * Strip the PEM headers/footers and whitespace from a .p8 private key,
 * then decode the PKCS#8 DER bytes.
 */
function pemToDer(pem: string): Uint8Array {
  const stripped = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  return base64UrlToBytes(stripped.replace(/\+/g, "-").replace(/\//g, "_"));
}

/** Generate a signed APNs JWT valid for one hour. */
async function generateApnsJwt(
  keyP8: string,
  keyId: string,
  teamId: string
): Promise<string> {
  const header = { alg: "ES256", kid: keyId };
  const now = Math.floor(Date.now() / 1000);
  const payload = { iss: teamId, iat: now };

  const encodedHeader = bytesToBase64Url(
    new TextEncoder().encode(JSON.stringify(header))
  );
  const encodedPayload = bytesToBase64Url(
    new TextEncoder().encode(JSON.stringify(payload))
  );
  const signingInput = `${encodedHeader}.${encodedPayload}`;

  const keyDer = pemToDer(keyP8);
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyDer,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    cryptoKey,
    new TextEncoder().encode(signingInput)
  );

  return `${signingInput}.${bytesToBase64Url(new Uint8Array(signature))}`;
}

// ---------------------------------------------------------------------------
// Send a single APNs push notification
// ---------------------------------------------------------------------------

async function sendApnsNotification(
  token: string,
  jwt: string,
  bundleId: string,
  title: string,
  body: string,
  sermonId: string
): Promise<ApnsResult> {
  const url = `https://api.push.apple.com/3/device/${token}`;

  const notificationPayload = {
    aps: {
      alert: { title, body },
      sound: "default",
    },
    sermon_id: sermonId,
    notification_type: "new_sermon",
  };

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "content-type": "application/json",
    },
    body: JSON.stringify(notificationPayload),
  });

  let reason: string | undefined;
  if (!response.ok) {
    try {
      const json = (await response.json()) as { reason?: string };
      reason = json.reason;
    } catch {
      // ignore parse errors
    }
  }

  return { token, status: response.status, reason };
}

// ---------------------------------------------------------------------------
// Edge Function entry point
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request): Promise<Response> => {
  try {
    // Only accept POST
    if (req.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    // Parse the webhook payload
    const payload = (await req.json()) as WebhookPayload;

    if (payload.type !== "INSERT" || !payload.record) {
      return new Response(
        JSON.stringify({ skipped: true, reason: "not an INSERT" }),
        { status: 200, headers: { "content-type": "application/json" } }
      );
    }

    const { id: sermonId, title, speaker } = payload.record;
    const notificationBody = `${title} — ${speaker}`;

    // Load secrets from environment
    const apnsKey = Deno.env.get("APNS_KEY");
    const apnsKeyId = Deno.env.get("APNS_KEY_ID");
    const apnsTeamId = Deno.env.get("APNS_TEAM_ID");
    const apnsBundleId = Deno.env.get("APNS_BUNDLE_ID");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!apnsKey || !apnsKeyId || !apnsTeamId || !apnsBundleId || !supabaseUrl || !serviceRoleKey) {
      console.error("Missing required environment variables");
      return new Response(
        JSON.stringify({ error: "Missing environment variables" }),
        { status: 500, headers: { "content-type": "application/json" } }
      );
    }

    // Fetch all iOS device tokens using service_role (bypasses RLS)
    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const { data: rows, error: dbError } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("platform", "ios");

    if (dbError) {
      console.error("Failed to fetch device tokens:", dbError.message);
      return new Response(
        JSON.stringify({ error: dbError.message }),
        { status: 500, headers: { "content-type": "application/json" } }
      );
    }

    const tokens = (rows as DeviceToken[]) ?? [];
    if (tokens.length === 0) {
      return new Response(
        JSON.stringify({ sent: 0, total: 0 }),
        { status: 200, headers: { "content-type": "application/json" } }
      );
    }

    // Generate APNs JWT once for all sends
    const jwt = await generateApnsJwt(apnsKey, apnsKeyId, apnsTeamId);

    // Send to all devices concurrently
    const results = await Promise.all(
      tokens.map((row) =>
        sendApnsNotification(
          row.token,
          jwt,
          apnsBundleId,
          "New Sermon",
          notificationBody,
          sermonId
        )
      )
    );

    // Clean up stale tokens (410 Gone or BadDeviceToken)
    const staleTokens = results
      .filter((r) => r.status === 410 || r.reason === "BadDeviceToken")
      .map((r) => r.token);

    if (staleTokens.length > 0) {
      const { error: deleteError } = await supabase
        .from("device_tokens")
        .delete()
        .in("token", staleTokens);

      if (deleteError) {
        console.error("Failed to delete stale tokens:", deleteError.message);
      } else {
        console.log(`Deleted ${staleTokens.length} stale token(s)`);
      }
    }

    const sent = results.filter((r) => r.status === 200).length;
    console.log(`Sent ${sent}/${tokens.length} notifications for sermon "${title}"`);

    return new Response(
      JSON.stringify({ sent, total: tokens.length }),
      { status: 200, headers: { "content-type": "application/json" } }
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("Unhandled error:", message);
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { "content-type": "application/json" } }
    );
  }
});
