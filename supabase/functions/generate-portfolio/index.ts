import { createClient } from "npm:@supabase/supabase-js@2.34.0";

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Helper to fetch price from Yahoo Finance
async function fetchPrice(ticker: string): Promise<number | null> {
    try {
        const response = await fetch(`https://query1.finance.yahoo.com/v8/finance/chart/${ticker}?interval=1d&range=1d`);
        if (!response.ok) return null;
        const data = await response.json();
        const price = data.chart?.result?.[0]?.meta?.regularMarketPrice;
        return price || null;
    } catch (e) {
        console.error(`Failed to fetch price for ${ticker}:`, e);
        return null;
    }
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

        console.log("Auth Header received:", authHeader.substring(0, 20) + "...");

        const supabaseUrl = Deno.env.get('SUPABASE_URL');
        const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');

        if (!supabaseUrl || !supabaseAnonKey) {
            console.error("Missing Supabase env vars");
            return new Response(
                JSON.stringify({ error: 'Server configuration error' }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
            )
        }

        const supabaseClient = createClient(
            supabaseUrl,
            supabaseAnonKey,
            {
                global: { headers: { Authorization: authHeader } },
                auth: { persistSession: false }
            }
        )

        // Get the user from the token
        const token = authHeader.replace('Bearer ', '');
        const { data: { user }, error: userError } = await supabaseClient.auth.getUser(token)

        if (userError || !user) {
            console.error("Auth error:", userError);
            return new Response(
                JSON.stringify({ error: 'Invalid user token', details: userError?.message }),
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
              "total_investment": 10000, // Optional, required for percentage requests
              "holdings": [
                { 
                  "ticker": "AAPL", 
                  "quantity": 10, // Optional if allocation_percentage is provided
                  "allocation_percentage": 0, // Optional, 0-100
                  "average_price": 150.00 // Optional, will be fetched if missing
                }
              ],
              "missing_info": []
            }

            Rules:
            1. "name" is REQUIRED. If missing, add "Portfolio name" to "missing_info".
            2. If the user provides explicit holdings (e.g., "10 shares of Apple"), extract "ticker" and "quantity".
            3. If the user provides THEMATIC or PERCENTAGE-based requests (e.g., "20% AI stocks"):
               a. You MUST have a "Total Investment Amount" (budget). Extract it to "total_investment".
               b. If the budget is missing, add "Total investment amount" to "missing_info".
               c. Select 3-5 representative tickers for each theme.
               d. Set "allocation_percentage" for each ticker based on the user's request.
            4. If a holding is mentioned but lacks quantity/price AND it's not a percentage request, add specific missing info.
            5. If the user provides a company name, convert it to the ticker.
            6. "description" is optional.
            7. Return ONLY valid JSON. No markdown formatting.`
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

        // Process holdings to calculate quantities and prices
        const processedHoldings = [];
        if (parsedData.holdings && parsedData.holdings.length > 0) {
            for (const h of parsedData.holdings) {
                let quantity = h.quantity;
                let price = h.average_price;

                // Fetch real-time price if missing or needed for calculation
                if (!price || (h.allocation_percentage && parsedData.total_investment)) {
                    const fetchedPrice = await fetchPrice(h.ticker);
                    if (fetchedPrice) {
                        price = fetchedPrice;
                    } else if (!price) {
                        // If we can't fetch and AI didn't provide, default to 0 (or handle error)
                        console.warn(`Could not fetch price for ${h.ticker}`);
                        price = 0;
                    }
                }

                // Calculate quantity from allocation if needed
                if (!quantity && h.allocation_percentage && parsedData.total_investment && price > 0) {
                    const allocationAmount = (parsedData.total_investment * h.allocation_percentage) / 100;
                    quantity = allocationAmount / price;
                }

                if (quantity > 0) {
                    processedHoldings.push({
                        ticker: h.ticker.toUpperCase(),
                        quantity: quantity,
                        average_price: price
                    });
                }
            }
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

        // Insert Holdings
        if (processedHoldings.length > 0) {
            const holdingsToInsert = processedHoldings.map(h => ({
                portfolio_id: portfolio.id,
                ticker: h.ticker,
                quantity: h.quantity,
                average_price: h.average_price
            }));

            const { error: holdingsError } = await supabaseClient
                .from('holdings')
                .insert(holdingsToInsert);

            if (holdingsError) {
                console.error("Holdings insert error:", holdingsError);
                return new Response(
                    JSON.stringify({
                        success: true,
                        portfolio_id: portfolio.id,
                        warning: 'Portfolio created but holdings failed: ' + holdingsError.message
                    }),
                    { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
                )
            }
        }

        return new Response(
            JSON.stringify({
                success: true,
                portfolio_id: portfolio.id,
                message: 'Portfolio created successfully',
                holdings_count: processedHoldings.length
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
