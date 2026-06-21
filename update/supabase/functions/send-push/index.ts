// Supabase Edge Function: send-push
//
// Triggered by the `trg_notify_push_on_alert` Postgres trigger whenever a
// new row is inserted into `alerts`. Looks up every device token for that
// alert's company and sends each one a push via Firebase Cloud Messaging's
// HTTP v1 API.
//
// WHY THIS LIVES HERE AND NOT IN THE FLUTTER APP:
// FCM's send API requires a service-account credential that must never
// ship inside a mobile app binary (anyone could extract it and send
// arbitrary pushes as you). Edge Functions run server-side with secrets
// kept in Supabase's vault, which is the only safe place for this to live.
//
// DEPLOY:
//   supabase functions deploy send-push
//   supabase secrets set FCM_PROJECT_ID=your-firebase-project-id
//   supabase secrets set FCM_SERVICE_ACCOUNT_JSON='{...contents of your
//     Firebase service account JSON file, as a single-line string...}'
//
// Get the service account JSON from:
//   Firebase Console → Project Settings → Service Accounts →
//   Generate new private key

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const FCM_PROJECT_ID = Deno.env.get('FCM_PROJECT_ID')!;
const FCM_SERVICE_ACCOUNT_JSON = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// ── OAuth2 token for FCM HTTP v1, minted from the service account ─────────
let cachedAccessToken: { token: string; expiresAt: number } | null = null;

async function getAccessToken(): Promise<string> {
  if (cachedAccessToken && cachedAccessToken.expiresAt > Date.now() + 60_000) {
    return cachedAccessToken.token;
  }

  const serviceAccount = JSON.parse(FCM_SERVICE_ACCOUNT_JSON);
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: 'RS256', typ: 'JWT' };
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const encode = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

  const unsignedJwt = `${encode(header)}.${encode(claimSet)}`;

  const keyData = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const binaryKey = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(unsignedJwt),
  );

  const encodedSignature = btoa(
    String.fromCharCode(...new Uint8Array(signature)),
  ).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

  const jwt = `${unsignedJwt}.${encodedSignature}`;

  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenResponse.json();
  if (!tokenData.access_token) {
    throw new Error(`Failed to mint FCM access token: ${JSON.stringify(tokenData)}`);
  }

  cachedAccessToken = {
    token: tokenData.access_token,
    expiresAt: Date.now() + tokenData.expires_in * 1000,
  };
  return cachedAccessToken.token;
}

async function sendToToken(
  accessToken: string,
  token: string,
  title: string,
  body: string,
  severity: string,
  recruitId: string | null,
): Promise<{ ok: boolean; shouldRemoveToken: boolean }> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data: {
            severity,
            recruit_id: recruitId ?? '',
          },
          android: { priority: 'high' },
          apns: { payload: { aps: { sound: 'default' } } },
        },
      }),
    },
  );

  if (res.ok) return { ok: true, shouldRemoveToken: false };

  const errBody = await res.json().catch(() => ({}));
  const errorCode = errBody?.error?.details?.[0]?.errorCode;
  // UNREGISTERED means the token is dead (app uninstalled, etc) — clean it
  // up so future sends don't keep retrying a token that will never work.
  const shouldRemoveToken = errorCode === 'UNREGISTERED' || res.status === 404;
  return { ok: false, shouldRemoveToken };
}

Deno.serve(async (req) => {
  try {
    const { alert_id } = await req.json();
    if (!alert_id) {
      return new Response(JSON.stringify({ error: 'alert_id required' }), {
        status: 400,
      });
    }

    const { data: alert, error: alertError } = await supabase
      .from('alerts')
      .select('*')
      .eq('id', alert_id)
      .single();

    if (alertError || !alert) {
      return new Response(JSON.stringify({ error: 'alert not found' }), {
        status: 404,
      });
    }

    const { data: tokens, error: tokenError } = await supabase
      .from('device_tokens')
      .select('token')
      .eq('company_id', alert.company_id);

    if (tokenError) throw tokenError;
    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: 'no device tokens' }), {
        status: 200,
      });
    }

    const accessToken = await getAccessToken();
    const tokensToRemove: string[] = [];
    let sentCount = 0;

    for (const { token } of tokens) {
      const result = await sendToToken(
        accessToken,
        token,
        alert.title,
        alert.body,
        alert.severity,
        alert.recruit_id,
      );
      if (result.ok) sentCount++;
      if (result.shouldRemoveToken) tokensToRemove.push(token);
    }

    if (tokensToRemove.length > 0) {
      await supabase.from('device_tokens').delete().in('token', tokensToRemove);
    }

    return new Response(
      JSON.stringify({ sent: sentCount, removed: tokensToRemove.length }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    console.error('send-push error:', e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
