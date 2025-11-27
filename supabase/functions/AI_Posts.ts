import { createClient } from "npm:@supabase/supabase-js@2.34.0";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
);

const USER_ID = Deno.env.get("DAILY_POSTS_USER_ID") ?? "<YOUR_USER_ID>";

console.info('daily-stock-posts function starting');

Deno.serve(async () => {
  try {
    // 1. Call OpenRouter Grok-4 Fast
    const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${Deno.env.get("OPENROUTER_API_KEY")}`,
        "Content-Type": "application/json",
        "HTTP-Referer": Deno.env.get("SITE_URL") ?? "",
        "X-Title": "Daily Stock Posts"
      },
      body: JSON.stringify({
        model: Deno.env.get("LLM_MODEL") ?? "x-ai/grok-4-fast:free",
        messages: [
          {
            role: "system",
            content: "You are a financial assistant. Always respond in JSON array format only."
          },
          {
            role: "user",
            content: `
Generate 10 stock news updates. 
Each item must strictly follow this schema:

[
  {
    "ticker": "AAPL",
    "content": "Apple announced a new iPhone today...",
    "post_type": "UPDATE"
  }
]

Rules:
- Return ONLY valid JSON, no explanations.
- Return EXACTLY 10 objects in the array, no more, no less.
- Tickers must be real (AAPL, TSLA, MSFT, AMZN, NVDA, etc).
- Each content must be 1 to 3 sentences max.
- Do not include markdown fences (like \`\` \`json).
`
          }
        ]
      })
    });

    const data = await response.json();
    const content = data.choices?.[0]?.message?.content ?? "[]";

    // 2. Parse JSON from model
    let posts;
    try {
      posts = JSON.parse(content);
    } catch (e) {
      console.error("Failed to parse LLM JSON:", content);
      return new Response("Invalid JSON from LLM", {
        status: 500
      });
    }

    if (!Array.isArray(posts) || posts.length !== 10) {
      console.error("LLM did not return exactly 10 items", posts);
      return new Response("Unexpected LLM output length", {
        status: 500
      });
    }

    // 3. Prepare rows for insertion
    const rows = posts.map((p) => ({
      user_id: USER_ID,
      content: (p.content ?? '').slice(0, 1000),
      post_type: p.post_type || "UPDATE",
      ticker: p.ticker || null,
      is_public: true
    }));

    // 4. Insert into Supabase (service role key required)
    const { error } = await supabase.from("posts").insert(rows);

    if (error) {
      console.error("Insert error:", error);
      return new Response("Database insert failed", {
        status: 500
      });
    }

    return new Response("Inserted daily posts successfully", {
      status: 200
    });
  } catch (err) {
    console.error("Edge Function error:", err);
    return new Response("Internal error", {
      status: 500
    });
  }
});
