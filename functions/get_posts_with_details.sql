-- Function to get posts with author details, like count, and comment count
CREATE OR REPLACE FUNCTION public.get_posts_with_details(
    p_limit INT DEFAULT 10,
    p_offset INT DEFAULT 0,
    p_user_id UUID DEFAULT NULL,
    p_portfolio_id UUID DEFAULT NULL,
    p_author_id UUID DEFAULT NULL,
    p_post_type TEXT DEFAULT NULL,
    p_is_public BOOLEAN DEFAULT NULL,
    p_only_following BOOLEAN DEFAULT false,
    p_ticker TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    username TEXT,
    full_name TEXT,
    avatar_url TEXT,
    portfolio_id UUID,
    portfolio_name TEXT,
    content TEXT,
    post_type TEXT,
    is_public BOOLEAN,
    ticker TEXT,
    like_count BIGINT,
    comment_count BIGINT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    is_liked_by_me BOOLEAN
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        p.id,
        p.user_id,
        u.username,
        u.full_name,
        u.avatar_url,
        p.portfolio_id,
        pf.name as portfolio_name,
        p.content,
        p.post_type,
        p.is_public,
        p.ticker,
        COALESCE(pl.like_count, 0) as like_count,
        COALESCE(pc.comment_count, 0) as comment_count,
        p.created_at,
        p.updated_at,
        CASE 
            WHEN p_user_id IS NULL THEN FALSE
            ELSE EXISTS (
                SELECT 1 
                FROM public.post_likes pl2 
                WHERE pl2.post_id = p.id AND pl2.user_id = p_user_id
            )
        END as is_liked_by_me
    FROM 
        public.posts p
    JOIN 
        public.users u ON p.user_id = u.id
    LEFT JOIN 
        public.portfolios pf ON p.portfolio_id = pf.id
    LEFT JOIN (
        SELECT post_id, COUNT(*) as like_count
        FROM public.post_likes
        GROUP BY post_id
    ) pl ON p.id = pl.post_id
    LEFT JOIN (
        SELECT post_id, COUNT(*) as comment_count
        FROM public.post_comments
        GROUP BY post_id
    ) pc ON p.id = pc.post_id
    WHERE 
        (p_is_public IS NULL OR p.is_public = p_is_public)
        AND (p_portfolio_id IS NULL OR p.portfolio_id = p_portfolio_id)
        AND (p_author_id IS NULL OR p.user_id = p_author_id)
        AND (p_post_type IS NULL OR p.post_type = p_post_type)
        AND (p_ticker IS NULL OR p.ticker = p_ticker)
        AND (
            p_only_following = false 
            OR p_user_id IS NULL 
            OR p.user_id IN (
                SELECT following_id 
                FROM public.user_follows 
                WHERE follower_id = p_user_id
            )
        )
    ORDER BY 
        p.created_at DESC
    LIMIT 
        p_limit
    OFFSET 
        p_offset;
$$;
