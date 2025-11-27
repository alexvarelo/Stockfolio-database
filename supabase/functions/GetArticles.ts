import { createClient } from "npm:@supabase/supabase-js@2.35.0";
const supabase = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'), {
  auth: {
    persistSession: false
  }
});

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

    const {
      page = 1,
      limit = 10,
      article_type,
      tickers,
      tags,
      status = 'published',
      sort_by = 'created_at',
      sort_order = 'desc'
    } = body;

    // Validate pagination parameters
    const pageNum = Math.max(1, parseInt(page));
    const limitNum = Math.min(50, Math.max(1, parseInt(limit))); // Max 50 per page
    const offset = (pageNum - 1) * limitNum;

    // Build query
    let query = supabase
      .from('articles')
      .select(`
        id,
        title,
        slug,
        summary,
        article_type,
        tickers,
        tags,
        status,
        view_count,
        is_premium,
        created_at,
        updated_at,
        metadata
      `)
      .eq('status', status)
      .range(offset, offset + limitNum - 1);

    // Apply filters
    if (article_type && ['TICKER_ANALYSIS', 'NEWS_SUMMARY', 'MARKET_OVERVIEW'].includes(article_type)) {
      query = query.eq('article_type', article_type);
    }

    if (tickers && Array.isArray(tickers) && tickers.length > 0) {
      query = query.overlaps('tickers', tickers);
    }

    if (tags && Array.isArray(tags) && tags.length > 0) {
      query = query.overlaps('tags', tags);
    }

    // Apply sorting
    const validSortFields = ['created_at', 'updated_at', 'title', 'view_count'];
    const sortField = validSortFields.includes(sort_by) ? sort_by : 'created_at';
    const sortDirection = sort_order === 'asc';

    query = query.order(sortField, { ascending: sortDirection });

    // Execute query
    const { data: articles, error: articlesError } = await query;

    if (articlesError) {
      console.error('Database query error:', articlesError);
      return new Response(JSON.stringify({
        error: 'Failed to fetch articles.',
        details: articlesError.message
      }), {
        status: 500,
        headers: HEADERS
      });
    }

    // Get total count for pagination (separate query for performance)
    let countQuery = supabase
      .from('articles')
      .select('id', { count: 'exact', head: true })
      .eq('status', status);

    if (article_type && ['TICKER_ANALYSIS', 'NEWS_SUMMARY', 'MARKET_OVERVIEW'].includes(article_type)) {
      countQuery = countQuery.eq('article_type', article_type);
    }

    if (tickers && Array.isArray(tickers) && tickers.length > 0) {
      countQuery = countQuery.overlaps('tickers', tickers);
    }

    if (tags && Array.isArray(tags) && tags.length > 0) {
      countQuery = countQuery.overlaps('tags', tags);
    }

    const { count, error: countError } = await countQuery;

    if (countError) {
      console.error('Count query error:', countError);
    }

    // Format response
    const totalPages = Math.ceil((count || 0) / limitNum);
    const hasNextPage = pageNum < totalPages;
    const hasPrevPage = pageNum > 1;

    const response = {
      success: true,
      articles: articles || [],
      pagination: {
        page: pageNum,
        limit: limitNum,
        total: count || 0,
        total_pages: totalPages,
        has_next: hasNextPage,
        has_prev: hasPrevPage
      },
      filters_applied: {
        article_type,
        tickers,
        tags,
        status,
        sort_by,
        sort_order
      }
    };

    return new Response(JSON.stringify(response), {
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
