-- Function to create a new post
CREATE OR REPLACE FUNCTION public.create_post(
    p_user_id UUID,
    p_content TEXT,
    p_post_type VARCHAR(20) DEFAULT 'UPDATE',
    p_is_public BOOLEAN DEFAULT true,
    p_portfolio_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_post_id UUID;
    v_mentioned_user_ids UUID[];
    v_mentioned_user_id UUID;
    v_mentioned_username TEXT;
    v_poster_username TEXT;
    v_poster_avatar_url TEXT;
    v_portfolio_name TEXT;
    v_notification_id UUID;
    v_mentioned_username_text TEXT;
    v_mentioned_user_public BOOLEAN;
    v_content_preview TEXT;
BEGIN
    -- Validate post type
    IF p_post_type NOT IN ('UPDATE', 'TRADE', 'ANALYSIS', 'GENERAL') THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid post type. Must be one of: UPDATE, TRADE, ANALYSIS, GENERAL'
        );
    END IF;
    
    -- Validate portfolio ownership if provided
    IF p_portfolio_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 
        FROM public.portfolios 
        WHERE id = p_portfolio_id AND user_id = p_user_id
    ) THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Portfolio not found or you do not have permission to post to it'
        );
    END IF;
    
    -- Get poster's details for notifications
    SELECT username, avatar_url 
    INTO v_poster_username, v_poster_avatar_url
    FROM public.users 
    WHERE id = p_user_id;
    
    -- Get portfolio name if provided
    IF p_portfolio_id IS NOT NULL THEN
        SELECT name INTO v_portfolio_name
        FROM public.portfolios
        WHERE id = p_portfolio_id;
    END IF;
    
    -- Create the post
    INSERT INTO public.posts (
        user_id,
        portfolio_id,
        content,
        post_type,
        is_public
    ) VALUES (
        p_user_id,
        p_portfolio_id,
        p_content,
        p_post_type,
        p_is_public
    )
    RETURNING id INTO v_post_id;
    
    -- Create a preview of the post content for notifications
    v_content_preview := 
        CASE 
            WHEN length(p_content) > 100 THEN substring(p_content from 1 for 100) || '...' 
            ELSE p_content 
        END;
    
    -- Check for @mentions in the post content (UUID format: @xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
    SELECT array_agg(matches[1]::uuid)
    INTO v_mentioned_user_ids
    FROM regexp_matches(p_content, '@([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})', 'g') AS matches;
    
    -- Create notifications for mentioned users
    IF v_mentioned_user_ids IS NOT NULL THEN
        FOREACH v_mentioned_user_id IN ARRAY v_mentioned_user_ids
        LOOP
            -- Skip if mentioning self
            IF v_mentioned_user_id != p_user_id THEN
                -- Get mentioned user's details
                SELECT username, is_public 
                INTO v_mentioned_username, v_mentioned_user_public
                FROM public.users
                WHERE id = v_mentioned_user_id;
                
                IF v_mentioned_username IS NOT NULL THEN
                    -- Notify the mentioned user
                    INSERT INTO public.notifications (
                        user_id,
                        type,
                        title,
                        message,
                        data
                    ) VALUES (
                        v_mentioned_user_id,
                        'mention',
                        'You were mentioned in a post',
                        v_poster_username || ' mentioned you in a post',
                        jsonb_build_object(
                            'post_id', v_post_id,
                            'poster_id', p_user_id,
                            'poster_username', v_poster_username,
                            'poster_avatar_url', v_poster_avatar_url,
                            'content_preview', v_content_preview,
                            'portfolio_id', p_portfolio_id,
                            'portfolio_name', v_portfolio_name,
                            'post_type', p_post_type,
                            'is_public', p_is_public
                        )
                    );
                END IF;
            END IF;
        END LOOP;
    END IF;
    
    -- Create a notification for portfolio followers if this is a portfolio post
    IF p_portfolio_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            user_id,
            type,
            title,
            message,
            data
        )
        SELECT 
            uf.user_id,
            'portfolio_update',
            'New update from ' || v_poster_username,
            v_poster_username || ' posted an update to ' || v_portfolio_name,
            jsonb_build_object(
                'post_id', v_post_id,
                'poster_id', p_user_id,
                'poster_username', v_poster_username,
                'poster_avatar_url', v_poster_avatar_url,
                'portfolio_id', p_portfolio_id,
                'portfolio_name', v_portfolio_name,
                'content_preview', v_content_preview,
                'post_type', p_post_type
            )
        FROM 
            public.portfolio_follows uf
        WHERE 
            uf.portfolio_id = p_portfolio_id
            AND uf.user_id != p_user_id;  -- Don't notify self
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'post_id', v_post_id,
        'message', 'Post created successfully'
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error creating post: ' || SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
