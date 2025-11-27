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

    const { article_id, slug, increment_views = true } = body;

    // Validate that we have either article_id or slug
    if (!article_id && !slug) {
      return new Response(JSON.stringify({
        error: 'Either article_id or slug is required.'
      }), {
        status: 400,
        headers: HEADERS
      });
    }

    // Fetch main article data
    let query = supabase
      .from('articles')
      .select(`
        id,
        title,
        slug,
        summary,
        content,
        article_type,
        tickers,
        tags,
        author,
        status,
        view_count,
        is_premium,
        created_at,
        updated_at,
        metadata
      `);

    if (article_id) {
      query = query.eq('id', article_id);
    } else {
      query = query.eq('slug', slug);
    }

    const { data: article, error: articleError } = await query.single();

    if (articleError) {
      console.error('Article fetch error:', articleError);
      return new Response(JSON.stringify({
        error: 'Article not found.',
        details: articleError.message
      }), {
        status: 404,
        headers: HEADERS
      });
    }

    // Check if article is published (unless it's a draft and user owns it)
    if (article.status !== 'published') {
      return new Response(JSON.stringify({
        error: 'Article not available.',
        details: 'This article is not published yet.'
      }), {
        status: 404,
        headers: HEADERS
      });
    }

    // Increment view count if requested (and user is not the author)
    if (increment_views && article.status === 'published') {
      try {
        await supabase
          .from('articles')
          .update({ view_count: (article.view_count || 0) + 1 })
          .eq('id', article.id);
      } catch (viewError) {
        console.error('Failed to increment view count:', viewError);
        // Don't fail the request if view count increment fails
      }
    }

    // Fetch article sections if they exist
    const { data: sections, error: sectionsError } = await supabase
      .from('article_sections')
      .select('id, section_title, section_order, content, created_at')
      .eq('article_id', article.id)
      .order('section_order', { ascending: true });

    // Fetch article sources/references
    const { data: sources, error: sourcesError } = await supabase
      .from('article_sources')
      .select('id, source_type, source_url, source_title, source_date, relevance_score, metadata, created_at')
      .eq('article_id', article.id)
      .order('created_at', { ascending: false });

    // Get engagement stats (likes, bookmarks, etc.)
    const { data: engagement, error: engagementError } = await supabase
      .from('article_engagement')
      .select(`
        engagement_type,
        count:engagement_type(count)
      `)
      .eq('article_id', article.id)
      .in('engagement_type', ['like', 'bookmark', 'share']);

    // Format engagement data
    const engagementStats = {};
    if (engagement && !engagementError) {
      engagement.forEach(item => {
        engagementStats[item.engagement_type] = parseInt(item.count) || 0;
      });
    }

    // Prepare comprehensive response
    const articleDetails = {
      ...article,
      sections: sections || [],
      sources: sources || [],
      engagement: {
        likes: engagementStats.like || 0,
        bookmarks: engagementStats.bookmark || 0,
        shares: engagementStats.share || 0,
        total_views: article.view_count || 0
      }
    };

    return new Response(JSON.stringify({
      success: true,
      article: articleDetails
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
