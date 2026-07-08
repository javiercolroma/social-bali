// Forgey en la nube: proxy seguro a la API de Claude (modelo barato) para los
// dispositivos SIN Apple Intelligence. El cliente manda el prompt YA construido
// (la lógica de prompts es compartida con el motor on-device: ForgeyPrompts.swift).
//
// Seguridad:
//  - JWT de Supabase obligatorio (usuario autenticado).
//  - Topes de longitud también AQUÍ (el cliente ya capa, pero el server manda).
//  - Tope duro de peticiones/día por usuario (100) + registro persistente en ai_usage.
//  - La clave de Anthropic vive SOLO en los secretos del proyecto (ANTHROPIC_API_KEY);
//    si no está configurada, la función responde 503 y la nube queda "apagada".
import { createClient } from "npm:@supabase/supabase-js@2";

const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method" }, 405);
  const supa = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
  );
  const { data: { user } } = await supa.auth.getUser();
  if (!user) return json({ error: "unauthorized" }, 401);

  const key = Deno.env.get("ANTHROPIC_API_KEY");
  if (!key) return json({ error: "cloud-ai-not-configured" }, 503);

  let body: { system?: unknown; prompt?: unknown; maxTokens?: unknown; image?: unknown };
  try { body = await req.json(); } catch { return json({ error: "bad-json" }, 400); }
  const system = String(body.system ?? "").slice(0, 8000);
  const prompt = String(body.prompt ?? "").trim().slice(0, 1200);
  const maxTokens = Math.min(900, Math.max(100, Number(body.maxTokens ?? 600)));
  if (!prompt) return json({ error: "empty-prompt" }, 400);

  // Adjunto de imagen OPCIONAL (análisis del físico). Cinturón anti-adjuntos: solo imágenes
  // reales, tipo permitido y tamaño acotado (nada de .ejecutables ni ficheros enormes).
  const imgObj = body.image && typeof body.image === "object"
    ? (body.image as { media_type?: unknown; data?: unknown }) : null;
  let content: unknown = prompt;
  if (imgObj) {
    const mt = String(imgObj.media_type ?? "");
    const b64 = String(imgObj.data ?? "");
    if (!/^image\/(jpeg|png|webp)$/.test(mt)) return json({ error: "bad-image-type" }, 400);
    if (b64.length < 100 || b64.length > 7_000_000) return json({ error: "image-size" }, 413);
    content = [
      { type: "image", source: { type: "base64", media_type: mt, data: b64 } },
      { type: "text", text: prompt },
    ];
  }

  // Tope duro diario, con contadores SEPARADOS: la visión (con imagen) es más cara y tiene su
  // propio cupo (30), independiente del texto (100). Así el chat no agota el cupo de la foto.
  const today = new Date().toISOString().slice(0, 10);
  const { data: usage } = await supa.from("ai_usage").select("cloud, cloud_vision")
    .eq("user_id", user.id).eq("day", today).maybeSingle();
  const used = imgObj ? (usage?.cloud_vision ?? 0) : (usage?.cloud ?? 0);
  const cap = imgObj ? 30 : 100;
  if (used >= cap) return json({ error: "daily-limit" }, 429);

  const resp = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json" },
    body: JSON.stringify({
      model: "claude-haiku-4-5",
      max_tokens: maxTokens,
      system,
      messages: [{ role: "user", content }],
    }),
  });
  if (!resp.ok) return json({ error: "upstream", status: resp.status }, 502);
  const data = await resp.json();
  const text = (data.content ?? []).filter((b: { type: string }) => b.type === "text")
    .map((b: { text: string }) => b.text).join("");

  await supa.rpc("bump_ai_usage", {
    p_kind: imgObj ? "cloud_vision" : "cloud",
    p_in: data.usage?.input_tokens ?? 0,
    p_out: data.usage?.output_tokens ?? 0,
  });
  return json({ text });
});
