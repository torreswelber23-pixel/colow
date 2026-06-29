// Edge Function: enviar-alerta
// Envia notificacoes push via Firebase Cloud Messaging (FCM HTTP v1).
// Substitui a versao antiga baseada em Expo Push (incompativel com tokens FCM).
//
// Secrets necessarios (Supabase Dashboard -> Edge Functions -> Secrets):
//   FIREBASE_SERVICE_ACCOUNT -> JSON completo da conta de servico do Firebase
//                               (projeto colow-app). Cole o conteudo do arquivo
//                               baixado em "Gerar nova chave privada".
//   SUPABASE_URL              -> ja existe
//   SUPABASE_SERVICE_ROLE_KEY -> ja existe
//
// Deploy:
//   supabase functions deploy enviar-alerta
//
// As mensagens sao DATA-ONLY de alta prioridade. Isso faz o handler do app
// (_handleBackgroundMessage em push_service.dart) rodar mesmo com o app
// fechado / tela bloqueada e montar a notificacao estilo chamada (fullScreen).

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
  token_uri?: string;
}

// ---------- OAuth2: gera access_token a partir da service account ----------

let cachedToken: { token: string; exp: number } | null = null;

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const raw = atob(b64);
  const buf = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) buf[i] = raw.charCodeAt(i);
  return buf.buffer;
}

function base64url(input: string | Uint8Array): string {
  let str: string;
  if (typeof input === "string") {
    str = btoa(input);
  } else {
    let s = "";
    for (const b of input) s += String.fromCharCode(b);
    str = btoa(s);
  }
  return str.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.exp - 60 > now) return cachedToken.token;

  const tokenUri = sa.token_uri ?? "https://oauth2.googleapis.com/token";
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = base64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: tokenUri,
      iat: now,
      exp: now + 3600,
    }),
  );
  const unsigned = `${header}.${claim}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64url(new Uint8Array(sig))}`;

  const resp = await fetch(tokenUri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const json = await resp.json();
  if (!json.access_token) {
    throw new Error("Falha ao obter access_token FCM: " + JSON.stringify(json));
  }
  cachedToken = { token: json.access_token, exp: now + 3600 };
  return json.access_token;
}

// ---------- Envio FCM (data-only, alta prioridade) ----------

function toStringMap(data: Record<string, unknown>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(data)) {
    if (v === null || v === undefined) continue;
    out[k] = typeof v === "string" ? v : String(v);
  }
  return out;
}

async function enviarPush(
  sa: ServiceAccount,
  tokens: string[],
  data: Record<string, unknown>,
): Promise<number> {
  if (!tokens.length) return 0;
  const accessToken = await getAccessToken(sa);
  const url =
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
  const payload = toStringMap(data);

  let enviados = 0;
  await Promise.all(
    tokens.map(async (t) => {
      try {
        const resp = await fetch(url, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: t,
              // DATA-ONLY: nada de "notification" aqui, pra o handler do app
              // construir a notificacao estilo chamada (fullScreenIntent).
              data: payload,
              android: { priority: "high" },
              apns: {
                headers: { "apns-priority": "10", "apns-push-type": "background" },
                payload: { aps: { "content-available": 1 } },
              },
            },
          }),
        });
        if (resp.ok) enviados++;
      } catch (_) {
        // ignora token invalido individual
      }
    }),
  );
  return enviados;
}

async function tokensFamilia(
  supabase: any,
  protegidoId: string,
): Promise<string[]> {
  const { data: vinc } = await supabase
    .from("vinculos")
    .select("acompanhante:acompanhante_id (push_token)")
    .eq("protegido_id", protegidoId);
  return (vinc ?? [])
    .map((v: any) => v.acompanhante?.push_token)
    .filter(Boolean);
}

// ---------- Handler ----------

Deno.serve(async (req: Request) => {
  try {
    const saRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!saRaw) {
      return new Response(
        JSON.stringify({ ok: false, error: "FIREBASE_SERVICE_ACCOUNT ausente" }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }
    const sa: ServiceAccount = JSON.parse(saRaw);

    const { lat, lng, nome, mensagem, raio_m, protegido_id, tipo } = await req
      .json();
    if (typeof lat !== "number" || typeof lng !== "number") {
      return new Response(
        JSON.stringify({ ok: false, error: "lat/lng obrigatorios" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const mapa = `https://maps.google.com/?q=${lat},${lng}`;

    // ===== AVISO LEVE: escuta ao vivo ativada pela pessoa =====
    if (tipo === "escuta") {
      let pushFamilia = 0;
      if (protegido_id) {
        const fTokens = await tokensFamilia(supabase, protegido_id);
        pushFamilia = await enviarPush(sa, fTokens, {
          lat, lng, mapa, protegido_id,
          nome_protegido: nome ?? "Alguem",
          tipo: "escuta_ativa",
          title: `🎧 ${nome ?? "Alguem"} quer que voce ouca ao vivo`,
          body: "Toque para ouvir o ambiente em tempo real.",
        });
      }
      return new Response(
        JSON.stringify({ ok: true, push_familia: pushFamilia, modo: "escuta" }),
        { headers: { "Content-Type": "application/json" } },
      );
    }

    // ===== AVISO LEVE: pessoa iniciou rota protegida =====
    if (tipo === "rota") {
      let pushFamilia = 0;
      if (protegido_id) {
        const fTokens = await tokensFamilia(supabase, protegido_id);
        pushFamilia = await enviarPush(sa, fTokens, {
          lat, lng, mapa, protegido_id,
          nome_protegido: nome ?? "Alguem",
          tipo: "rota_iniciada",
          title: `🛡️ ${nome ?? "Alguem"} iniciou uma rota protegida`,
          body: "Toque para acompanhar ao vivo ate a chegada.",
        });
      }
      return new Response(
        JSON.stringify({ ok: true, push_familia: pushFamilia, modo: "rota" }),
        { headers: { "Content-Type": "application/json" } },
      );
    }

    // ===== SOS (padrao): guardioes proximos + familia =====
    const { data: guardioes } = await supabase.rpc("guardioes_proximos", {
      p_lat: lat, p_lng: lng, p_raio_m: raio_m ?? 5000,
    });
    const gTokens = (guardioes ?? [])
      .map((g: any) => g.push_token)
      .filter(Boolean);
    const pushGuardioes = await enviarPush(sa, gTokens, {
      lat, lng, mapa, mensagem,
      protegido_id: protegido_id ?? null,
      nome_protegido: nome ?? "Vitima",
      tipo: "guardiao",
      title: "🚨 Alerta COLOW perto de voce",
      body: `${nome ?? "Alguem"} acionou um SOS. Toque para ver a rota ate a vitima.`,
    });

    let pushFamilia = 0;
    if (protegido_id) {
      const fTokens = await tokensFamilia(supabase, protegido_id);
      pushFamilia = await enviarPush(sa, fTokens, {
        lat, lng, mapa, protegido_id,
        nome_protegido: nome ?? "Alguem",
        tipo: "familia",
        title: `🆘 ${nome ?? "Alguem que voce ama"} PRECISA DE AJUDA`,
        body: "Tocou o SOS no COLOW agora. Toque para ver a localizacao ao vivo.",
      });
    }

    return new Response(
      JSON.stringify({
        ok: true,
        push_guardioes: pushGuardioes,
        push_familia: pushFamilia,
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }
});
