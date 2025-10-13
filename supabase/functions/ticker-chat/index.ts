import { createClient } from "npm:@supabase/supabase-js@2.35.0";

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? "",
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? "",
  { auth: { persistSession: false } }
);

// Helper to build system prompt based on available data
function buildSystemPrompt(ticker: string, portfolioId?: string) {
  return `You are a concise financial assistant. Be brief and to the point. Use bullet points when possible.
  
Ticker: ${ticker}
${portfolioId ? `Portfolio: ${portfolioId}` : ''}

Guidelines:
- Keep responses under 3 sentences when possible
- Use bullet points for multiple items
- Skip unnecessary introductions
- Focus on key metrics and actions`;
}

// Helper for CORS headers
function corsHeaders() {
  const origin = Deno.env.get('ALLOWED_ORIGIN') || '*';
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Content-Type': 'application/json'
  };
}

// Function to handle portfolio operations
async function handlePortfolioOperation(operation: string, ticker: string, portfolioId: string, quantity: number = 1) {
  // In a real implementation, you would add/remove from the portfolio here
  // For now, we'll just return a success message
  return { success: true, message: `Successfully ${operation} ${quantity} share(s) of ${ticker} ${operation === 'added' ? 'to' : 'from'} portfolio ${portfolioId}` };
}

Deno.serve(async (req) => {
  const headers = corsHeaders();
  
  // Handle preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers });
  }

  try {
    // Only allow POST requests
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers
      });
    }

    // Parse request body
    const { message, ticker, portfolioId, history = [] } = await req.json();
    
    if (!ticker) {
      return new Response(JSON.stringify({ error: 'Ticker symbol is required' }), {
        status: 400,
        headers
      });
    }

    // Check for portfolio operations
    const addToPortfolio = message.toLowerCase().includes('add to portfolio');
    const removeFromPortfolio = message.toLowerCase().includes('remove from portfolio');
    
    if ((addToPortfolio || removeFromPortfolio) && !portfolioId) {
      return new Response(JSON.stringify({ 
        error: 'Portfolio ID is required for this operation' 
      }), { status: 400, headers });
    }

    // Handle portfolio operations
    if (addToPortfolio || removeFromPortfolio) {
      const operation = addToPortfolio ? 'added' : 'removed';
      const result = await handlePortfolioOperation(operation, ticker, portfolioId);
      return new Response(JSON.stringify(result), { headers });
    }

    // Prepare messages for LLM
    const messages = [
      { role: 'system', content: buildSystemPrompt(ticker, portfolioId) },
      ...history,
      { role: 'user', content: message }
    ];

    // Call OpenRouter API
    const openrouterKey = Deno.env.get('OPENROUTER_API_KEY');
    if (!openrouterKey) {
      return new Response(JSON.stringify({ error: 'OpenRouter API key not configured' }), {
        status: 500,
        headers
      });
    }

    // Determine max tokens based on message type
    const isSimpleQuery = message.trim().length < 50 && 
                         !message.toLowerCase().includes('analyze') &&
                         !message.toLowerCase().includes('compare');
    
    const maxTokens = isSimpleQuery ? 150 : 350;
    
    const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openrouterKey}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': Deno.env.get('SITE_URL') || '',
        'X-Title': 'Ticker Chat'
      },
      body: JSON.stringify({
        model: 'x-ai/grok-4-fast:free',
        messages,
        temperature: isSimpleQuery ? 0.3 : 0.7, // Lower temp for simpler responses
        max_tokens: maxTokens,
        stop: ['\n\n', '  '] // Stop on double newlines or double spaces to prevent rambling
      })
    });

    if (!response.ok) {
      const error = await response.text();
      console.error('OpenRouter API error:', error);
      return new Response(JSON.stringify({ 
        error: 'Failed to get response from AI service',
        details: error 
      }), { status: 500, headers });
    }

    const data = await response.json();
    let content = data.choices?.[0]?.message?.content || 'Sorry, I could not process your request.';
    
    // Post-process response to make it more concise
    content = content
      .replace(/\s+/g, ' ') // Replace multiple spaces with single space
      .replace(/\.\s+\./g, '.') // Fix double periods
      .replace(/\s+([.,;:!?])/g, '$1') // Remove space before punctuation
      .trim();

    // If response is still long, try to truncate at the last sentence
    if (content.length > 300) {
      const lastPeriod = content.lastIndexOf('. ', 300);
      if (lastPeriod > 0) {
        content = content.substring(0, lastPeriod + 1);
      }
    }

    return new Response(JSON.stringify({ 
      response: content,
      ticker,
      timestamp: new Date().toISOString(),
      isTruncated: content.endsWith('...') || content.length >= 290
    }), { 
      headers: {
        ...headers,
        'Content-Encoding': 'gzip',
        'Vary': 'Accept-Encoding',
        'Content-Type': 'application/json'
      }
    });

  } catch (error) {
    console.error('Error in ticker-chat function:', error);
    return new Response(JSON.stringify({ 
      error: 'An unexpected error occurred',
      details: error.message 
    }), { 
      status: 500, 
      headers: corsHeaders() 
    });
  }
});
