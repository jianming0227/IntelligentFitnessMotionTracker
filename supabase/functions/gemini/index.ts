// Gemini proxy: the app sends a prompt, this function calls Gemini with the
// server-side key. GEMINI_API_KEY lives in Supabase secrets and never ships
// in the APK.
//
// Secrets (supabase secrets set ...):
//   GEMINI_API_KEY      required
//   GEMINI_MODEL_TEXT   optional, coaching tips   (default gemini-3.1-flash-lite)
//   GEMINI_MODEL_JSON   optional, plan generation (default gemini-3.1-flash-lite)
//
// Deploy: supabase functions deploy gemini

import { createClient } from 'npm:@supabase/supabase-js@2';

const DEFAULT_MODEL = 'gemini-3.1-flash-lite';
const MAX_PROMPT_CHARS = 8000;

const reply = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

Deno.serve(async (req) => {
  if (req.method !== 'POST') return reply(405, { error: 'POST only' });

  // The gateway also accepts the anon key (it ships in the APK), so ask Auth
  // for a real signed-in user.
  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
  );
  const { data: { user }, error: authError } = await supabase.auth.getUser(token);
  if (authError || !user) return reply(401, { error: 'Sign in required' });

  let prompt: unknown;
  let json = false;
  try {
    const body = await req.json();
    prompt = body.prompt;
    json = body.json === true;
  } catch {
    return reply(400, { error: 'Invalid JSON body' });
  }
  if (typeof prompt !== 'string' || prompt.trim() === '') {
    return reply(400, { error: 'Missing prompt' });
  }
  if (prompt.length > MAX_PROMPT_CHARS) {
    return reply(400, { error: 'Prompt too long' });
  }

  const apiKey = Deno.env.get('GEMINI_API_KEY');
  if (!apiKey) {
    console.error('GEMINI_API_KEY secret is not set');
    return reply(500, { error: 'AI not configured' });
  }
  const model =
    Deno.env.get(json ? 'GEMINI_MODEL_JSON' : 'GEMINI_MODEL_TEXT') ?? DEFAULT_MODEL;

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
      body: JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        ...(json && { generationConfig: { responseMimeType: 'application/json' } }),
      }),
    },
  );

  if (!res.ok) {
    // Full Gemini error stays in the function logs; the app gets a short one.
    console.error(`Gemini ${model} failed ${res.status}: ${await res.text()}`);
    return reply(502, { error: 'AI request failed' });
  }

  const data = await res.json();
  const text: string = (data.candidates?.[0]?.content?.parts ?? [])
    .map((p: { text?: string }) => p.text ?? '')
    .join('');
  if (!text) {
    console.error(`Gemini ${model} returned no text: ${JSON.stringify(data)}`);
    return reply(502, { error: 'Empty AI response' });
  }

  console.log(`user ${user.id} ${json ? 'json' : 'text'} ${model} ok (${text.length} chars)`);
  return reply(200, { text });
});
