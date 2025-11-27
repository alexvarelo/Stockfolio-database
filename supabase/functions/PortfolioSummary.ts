import { createClient } from "npm:@supabase/supabase-js@2.35.0";
const supabase = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'), {
  auth: {
    persistSession: false
  }
});
function buildPrompt(holdings, portfolioId) {
  const lines = holdings.map((h) => {
    const qty = Number(h.quantity ?? 0);
    const avg = Number(h.average_price ?? 0);
    const invested = Number(h.total_invested ?? qty * avg);
    const ticker = h.ticker ?? 'UNKNOWN';
    const notes = h.notes ? `notes=${h.notes}` : '';
    return `- ${ticker}: quantity=${qty}, average_price=${avg.toFixed(2)}, total_invested=${invested.toFixed(2)} ${notes}`;
  });
  const totalValue = holdings.reduce((s, h) => s + Number(h.total_invested ?? Number(h.quantity ?? 0) * Number(h.average_price ?? 0)), 0);
  const userMessage = `You are a financial assistant. Return ONLY JSON (application/json).

Portfolio id: ${portfolioId}
Total market value (estimated from total_invested): ${totalValue.toFixed(2)}
Number of holdings: ${holdings.length}
Holdings:
${lines.join('\n')}

Task:
- Provide an overall sentiment for this portfolio ("bullish", "neutral", or "bearish") and a 1-2 sentence justification.
- List the top 3 risks affecting this portfolio and why (each with a short explanation).
- Offer 3 concise, actionable recommendations (no marketing language).

Output only a single JSON object with these keys:
{
  "sentiment": "string",
  "justification": "string",
  "risks": [{"title":"string","explanation":"string"}],
  "recommendations": [{"title":"string","action":"string"}],
  "assumptions": ["string"]
}

Do not output any text outside the JSON object. Use short, factual sentences.`;
  return [
    {
      role: 'system',
      content: 'You are a financial assistant. Return only JSON.'
    },
    {
      role: 'user',
      content: userMessage
    }
  ];
}
// Helper to build consistent CORS headers
function corsHeaders() {
  const origin = Deno.env.get('ALLOWED_ORIGIN') || '*';
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Vary': 'Origin',
    'Content-Type': 'application/json'
  };
}
Deno.serve(async (req) => {
  const HEADERS = corsHeaders();
  try {
    // Preflight
    if (req.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: HEADERS
      });
    }
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({
        error: 'Method not allowed. Use POST.'
      }), {
        status: 405,
        headers: HEADERS
      });
    }
    const body = await req.json().catch(() => null);
    if (!body || !body.portfolioId) {
      return new Response(JSON.stringify({
        error: 'Missing portfolioId in JSON body.'
      }), {
        status: 400,
        headers: HEADERS
      });
    }
    const portfolioId = String(body.portfolioId);
    const { data, error } = await supabase.from('holdings').select('id, portfolio_id, ticker, quantity, average_price, total_invested, notes, created_at, updated_at').eq('portfolio_id', portfolioId);
    if (error) {
      console.error('Supabase fetch error', error);
      return new Response(JSON.stringify({
        error: 'Failed to fetch holdings from database.'
      }), {
        status: 500,
        headers: HEADERS
      });
    }
    const holdings = Array.isArray(data) ? data : [];
    if (holdings.length === 0) {
      return new Response(JSON.stringify({
        error: 'No holdings found for the given portfolioId.'
      }), {
        status: 404,
        headers: HEADERS
      });
    }
    const messages = buildPrompt(holdings, portfolioId);
    const openrouterKey = Deno.env.get('OPENROUTER_API_KEY');
    if (!openrouterKey) {
      return new Response(JSON.stringify({
        error: 'OPENROUTER_API_KEY is not configured.'
      }), {
        status: 500,
        headers: HEADERS
      });
    }
    const llmResponse = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${openrouterKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: Deno.env.get('LLM_MODEL') ?? 'x-ai/grok-4-fast:free',
        messages
      })
    });
    if (!llmResponse.ok) {
      const text = await llmResponse.text().catch(() => '');
      console.error('LLM error', llmResponse.status, text);
      return new Response(JSON.stringify({
        error: 'LLM provider returned an error.',
        details: text
      }), {
        status: 502,
        headers: HEADERS
      });
    }
    const llmJson = await llmResponse.json().catch(() => null);
    let assistantContent = null;
    try {
      if (llmJson?.choices && Array.isArray(llmJson.choices) && llmJson.choices[0]?.message?.content) {
        assistantContent = llmJson.choices[0].message.content;
      } else if (llmJson?.output) {
        assistantContent = typeof llmJson.output === 'string' ? llmJson.output : JSON.stringify(llmJson.output);
      } else {
        assistantContent = JSON.stringify(llmJson);
      }
    } catch (e) {
      assistantContent = JSON.stringify(llmJson);
    }
    try {
      const parsed = JSON.parse(assistantContent);
      return new Response(JSON.stringify({
        result: parsed
      }), {
        status: 200,
        headers: HEADERS
      });
    } catch (e) {
      return new Response(JSON.stringify({
        warning: 'LLM output was not valid JSON.',
        raw: assistantContent
      }), {
        status: 200,
        headers: HEADERS
      });
    }
  } catch (err) {
    console.error('Unexpected error', err);
    const H = corsHeaders();
    return new Response(JSON.stringify({
      error: 'Unexpected server error.'
    }), {
      status: 500,
      headers: H
    });
  }
});
