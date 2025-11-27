import { createClient } from "npm:@supabase/supabase-js@2.34.0";

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { prompt } = await req.json()

        if (!prompt) {
            return new Response(
                JSON.stringify({ error: 'Prompt is required' }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
            )
        }

        // Create Supabase client with the user's auth token
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            return new Response(
                JSON.stringify({ error: 'Authorization header missing' }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 401 }
            )
        }

        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: authHeader } } }
        )

        // Get the user from the token
        const { data: { user }, error: userError } = await supabaseClient.auth.getUser()

        if (userError || !user) {
            return new Response(
                JSON.stringify({ error: 'Invalid user token' }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 401 }
            )
        }

        // Call OpenRouter AI
        const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
            method: "POST",
            headers: {
                Authorization: `Bearer ${Deno.env.get("OPENROUTER_API_KEY")}`,
                "Content-Type": "application/json",
                "HTTP-Referer": Deno.env.get("SITE_URL") ?? "",
                "X-Title": "Stockfolio Portfolio Generator"
            },
            body: JSON.stringify({
                model: Deno.env.get("LLM_MODEL") ?? "x-ai/grok-4-fast:free",
                messages: [
                    {
                        role: "system",
                        content: `You are a financial portfolio assistant. Your goal is to extract portfolio details from a user prompt.
            
            Return a JSON object with the following structure:
            {
              "name": "Portfolio Name",
              "description": "Portfolio Description",
              "holdings": [
                { "ticker": "AAPL", "quantity": 10, "average_price": 150.00 }
              ],
              "missing_info": []
            }

            Rules:
            1. "name" is REQUIRED. If missing, add "Portfolio name" to "missing_info".
            2. "holdings" are optional. If present, each holding MUST have "ticker", "quantity", and "average_price".
            3. If a holding is mentioned but lacks quantity or price, add a specific message to "missing_info" like "Quantity for Apple" or "Average price for Tesla".
            4. If the user provides a company name (e.g., "Apple"), convert it to the ticker ("AAPL").
            5. "description" is optional. If not provided, generate a brief one based on the holdings or name.
            6. Return ONLY valid JSON. No markdown formatting.`
                    },
                    {
                        role: "user",
                        content: prompt
                    }
                ]
            })
        });

        const aiData = await response.json();
        const content = aiData.choices?.[0]?.message?.content;

        if (!content) {
            console.error("AI returned no content", aiData);
            return new Response(
                JSON.stringify({ error: 'Failed to generate portfolio from AI' }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
            )
        }

        let parsedData;
        try {
            parsedData = JSON.parse(content);
        } catch (e) {
            console.error("Failed to parse AI JSON:", content);
            return new Response(
                JSON.stringify({ error: 'Invalid response from AI' }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
            )
        }

        // Check for missing info
        if (parsedData.missing_info && parsedData.missing_info.length > 0) {
            return new Response(
                JSON.stringify({
                    success: false,
                    message: "Missing information",
                    missing_info: parsedData.missing_info
                }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
            )
        }

        // Insert Portfolio
        const { data: portfolio, error: portfolioError } = await supabaseClient
            .from('portfolios')
            .insert({
                user_id: user.id,
                name: parsedData.name,
                description: parsedData.description,
                is_public: false
            })
            .select()
            .single();

        if (portfolioError) {
            console.error("Portfolio insert error:", portfolioError);
            return new Response(
                JSON.stringify({ error: 'Failed to create portfolio: ' + portfolioError.message }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
            )
        }

        // Insert Holdings if any
        if (parsedData.holdings && parsedData.holdings.length > 0) {
            const holdingsToInsert = parsedData.holdings.map((h: any) => ({
                portfolio_id: portfolio.id,
                ticker: h.ticker.toUpperCase(),
                quantity: h.quantity,
                average_price: h.average_price
            }));

            const { error: holdingsError } = await supabaseClient
                .from('holdings')
                .insert(holdingsToInsert);

            if (holdingsError) {
                console.error("Holdings insert error:", holdingsError);
                // Note: Portfolio was created, but holdings failed. 
                // We might want to delete the portfolio or just warn. 
                // For now, returning error but portfolio exists.
                return new Response(
                    JSON.stringify({
                        success: true,
                        portfolio_id: portfolio.id,
                        warning: 'Portfolio created but holdings failed: ' + holdingsError.message
                    }),
                    { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 } // Returning 200 because partial success
                )
            }
        }

        return new Response(
            JSON.stringify({
                success: true,
                portfolio_id: portfolio.id,
                message: 'Portfolio created successfully'
            }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        )

    } catch (err) {
        console.error("Edge Function error:", err);
        return new Response(
            JSON.stringify({ error: 'Internal Server Error' }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
        )
    }
});
