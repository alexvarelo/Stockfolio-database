-- Function to get a user's feed with posts from users they follow
CREATE OR REPLACE FUNCTION public.get_user_feed(
    user_uuid UUID, 
    limit_count INTEGER DEFAULT 20
)
RETURNS TABLE (
    post_id UUID,
    user_id UUID,
    username VARCHAR(50),
    full_name VARCHAR(255),
    avatar_url TEXT,
    content TEXT,
    post_type VARCHAR(20),
    created_at TIMESTAMPTZ,
    like_count BIGINT,
    comment_count BIGINT,
    is_liked BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id as post_id,
        p.user_id,
        u.username,
        u.full_name,
        u.avatar_url,
        p.content,
        p.post_type,
        p.created_at,
        (SELECT COUNT(*) FROM public.post_likes pl WHERE pl.post_id = p.id) as like_count,
        (SELECT COUNT(*) FROM public.post_comments pc WHERE pc.post_id = p.id) as comment_count,
        EXISTS (
            SELECT 1 
            FROM public.post_likes pl 
            WHERE pl.post_id = p.id AND pl.user_id = user_uuid
        ) as is_liked
    FROM 
        public.posts p
    JOIN 
        public.users u ON p.user_id = u.id
    WHERE 
        p.is_public = true
        AND (
            p.user_id = user_uuid
            OR p.user_id IN (
                SELECT following_id 
                FROM public.user_follows 
                WHERE follower_id = user_uuid
            )
        )
    ORDER BY 
        p.created_at DESC
    LIMIT 
        limit_count;
END;
$$ LANGUAGE plpgsql;
