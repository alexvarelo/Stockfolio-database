import { createClient } from "npm:@supabase/supabase-js@2.35.0";
const supabase = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'), {
  auth: {
    persistSession: false
  }
});

// Helper function to generate slug from title
function generateSlug(title: string): string {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .trim();
}

// Helper function to build prompt for article generation
function buildArticlePrompt(type: string, tickers?: string[], newsData?: any[]): any[] {
  let userMessage = '';

  if (type === 'TICKER_ANALYSIS' && tickers?.length) {
    userMessage = `Generate a comprehensive financial analysis article for these tickers: ${tickers.join(', ')}.

Requirements:
1. Create an engaging title that captures the investment opportunity or analysis focus
2. Write a compelling summary (2-3 sentences) highlighting key insights
3. Structure the article with these sections:
   - Market Overview (current market conditions affecting these stocks)
   - Company Analysis (fundamental analysis for each ticker)
   - Technical Analysis (price trends, support/resistance levels)
   - Investment Thesis (why invest/don't invest)
   - Risk Factors (key risks to consider)
   - Conclusion (final recommendation)

4. Use professional financial language but make it accessible
5. Include specific data points, metrics, and recent developments
6. Keep each section concise but informative (200-400 words per major section)`;
  } else if (type === 'NEWS_SUMMARY' && newsData?.length) {
    const newsSummary = newsData.slice(0, 5).map((item, i) =>
      `${i+1}. ${item.title} (${item.source}) - ${item.summary || 'No summary available'}`
    ).join('\n');

    userMessage = `Generate a market news summary article based on these recent financial news items:

${newsSummary}

Requirements:
1. Create a title that captures the main themes from today's financial news
2. Write a 2-3 sentence summary of the key market developments
3. Structure with these sections:
   - Market Headlines (top 3-4 most important stories)
   - Sector Impact (how different sectors are affected)
   - Economic Indicators (any economic data or policy news)
   - Market Sentiment (overall investor mood and implications)
   - Looking Ahead (what to watch for in coming days)

4. Focus on actionable insights for investors
5. Highlight both opportunities and risks emerging from the news`;
  } else {
    userMessage = `Generate a general market overview article covering current market conditions, trends, and investment opportunities.

Requirements:
1. Create an engaging title about current market conditions
2. Write a 2-3 sentence summary of current market state
3. Structure with these sections:
   - Market Performance (major indices and recent performance)
   - Sector Rotation (which sectors are leading/lagging)
   - Economic Backdrop (key economic indicators and Fed policy)
   - Investment Themes (emerging trends and opportunities)
   - Risk Assessment (current market risks and concerns)

4. Provide balanced, evidence-based analysis`;
  }

  return [
    {
      role: 'system',
      content: 'You are a professional financial analyst and writer. Generate comprehensive, well-structured articles with proper formatting. Return only valid JSON.'
    },
    {
      role: 'user',
      content: `${userMessage}

Return the article in this exact JSON format:
{
  "title": "Compelling article title",
  "summary": "2-3 sentence summary of key insights",
  "content": {
    "sections": [
      {
        "title": "Section Title",
        "content": "Detailed section content with multiple paragraphs..."
      }
    ]
  },
  "article_type": "${type}",
  "tickers": ${tickers ? JSON.stringify(tickers) : '[]'},
  "tags": ["relevant", "tags", "for", "categorization"],
  "metadata": {
    "generated_at": "${new Date().toISOString()}",
    "article_version": "1.0",
    "ai_model": ${Deno.env.get('LLM_MODEL')}
  }
}

Ensure the content is professional, insightful, and provides genuine value to investors.`
    }
  ];
}

// CORS headers helper
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
    // Handle preflight requests
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
    if (!body) {
      return new Response(JSON.stringify({
        error: 'Missing JSON body.'
      }), {
        status: 400,
        headers: HEADERS
      });
    }

    const { type, tickers, newsData, customPrompt } = body;

    // Validate required fields
    if (!type || !['TICKER_ANALYSIS', 'NEWS_SUMMARY', 'MARKET_OVERVIEW'].includes(type)) {
      return new Response(JSON.stringify({
        error: 'Valid type is required: TICKER_ANALYSIS, NEWS_SUMMARY, or MARKET_OVERVIEW.'
      }), {
        status: 400,
        headers: HEADERS
      });
    }

    // Validate tickers for TICKER_ANALYSIS
    if (type === 'TICKER_ANALYSIS' && (!tickers || !Array.isArray(tickers) || tickers.length === 0)) {
      return new Response(JSON.stringify({
        error: 'Tickers array is required for TICKER_ANALYSIS type.'
      }), {
        status: 400,
        headers: HEADERS
      });
    }

    // Generate article using LLM
    const messages = customPrompt ? [
      {
        role: 'system',
        content: 'You are a professional financial analyst. Return only valid JSON.'
      },
      {
        role: 'user',
        content: customPrompt
      }
    ] : buildArticlePrompt(type, tickers, newsData);

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
        model: Deno.env.get('LLM_MODEL'),
        messages,
        max_tokens: 4000,
        temperature: 0.7
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
    let assistantContent: string | null = null;

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

    // Debug logging - log the raw response for troubleshooting
    console.log('LLM Raw Response:', JSON.stringify(llmJson, null, 2));
    console.log('Extracted Content:', assistantContent);

    // Parse and validate the article content
    let articleData;
    try {
      if (!assistantContent) {
        throw new Error('No content received from LLM');
      }

      // Clean the content - remove markdown code blocks if present
      let cleanedContent = assistantContent.trim();

      // Remove markdown code block markers if present
      if (cleanedContent.startsWith('```json')) {
        cleanedContent = cleanedContent.replace(/^```json\s*/, '').replace(/```\s*$/, '');
      } else if (cleanedContent.startsWith('```')) {
        cleanedContent = cleanedContent.replace(/^```\s*/, '').replace(/```\s*$/, '');
      }

      // Try to extract JSON if there's other text around it
      const jsonMatch = cleanedContent.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        cleanedContent = jsonMatch[0];
      }

      console.log('Cleaned Content for parsing:', cleanedContent);

      articleData = JSON.parse(cleanedContent);
    } catch (e) {
      console.error('JSON Parse Error:', e.message);
      console.error('Content that failed to parse:', assistantContent);

      return new Response(JSON.stringify({
        error: 'Failed to parse LLM response as JSON.',
        debug: {
          raw_response: JSON.stringify(llmJson, null, 2),
          extracted_content: assistantContent,
          parse_error: e.message
        }
      }), {
        status: 502,
        headers: HEADERS
      });
    }

    // Validate required fields in article data
    if (!articleData.title || !articleData.content) {
      return new Response(JSON.stringify({
        error: 'Invalid article format: missing title or content.',
        raw: assistantContent
      }), {
        status: 502,
        headers: HEADERS
      });
    }

    // Generate slug and prepare article for database
    const slug = generateSlug(articleData.title);
    const articleRecord = {
      title: articleData.title,
      slug,
      summary: articleData.summary || null,
      content: articleData.content,
      article_type: type,
      tickers: tickers || [],
      tags: articleData.tags || [],
      author: 'AI Assistant',
      status: 'published',
      metadata: {
        ...articleData.metadata,
        generated_at: new Date().toISOString(),
        source: 'supabase_function'
      }
    };

    // Save article to database
    const { data: savedArticle, error: saveError } = await supabase
      .from('articles')
      .insert(articleRecord)
      .select()
      .single();

    if (saveError) {
      console.error('Database save error:', saveError);
      return new Response(JSON.stringify({
        error: 'Failed to save article to database.',
        details: saveError.message
      }), {
        status: 500,
        headers: HEADERS
      });
    }

    // Return the generated article
    return new Response(JSON.stringify({
      success: true,
      article: savedArticle,
      metadata: {
        generated_at: new Date().toISOString(),
        tokens_used: llmJson?.usage?.total_tokens || null
      }
    }), {
      status: 200,
      headers: HEADERS
    });

  } catch (err) {
    console.error('Unexpected error:', err);
    return new Response(JSON.stringify({
      error: 'Unexpected server error.',
      details: err.message
    }), {
      status: 500,
      headers: HEADERS
    });
  }
});
