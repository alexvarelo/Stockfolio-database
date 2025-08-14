-- Function to add a like to a post
CREATE OR REPLACE FUNCTION public.add_post_like(
    p_post_id UUID,
    p_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_like_id UUID;
    v_like_count BIGINT;
    v_post_owner_id UUID;
    v_notification_id UUID;
BEGIN
    -- Check if the post exists and get the owner
    SELECT user_id INTO v_post_owner_id
    FROM public.posts
    WHERE id = p_post_id
    FOR UPDATE; -- Lock the row to prevent race conditions
    
    IF v_post_owner_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Post not found'
        );
    END IF;
    
    -- Check if the user has already liked the post
    IF EXISTS (
        SELECT 1 
        FROM public.post_likes 
        WHERE post_id = p_post_id AND user_id = p_user_id
    ) THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Post already liked by this user'
        );
    END IF;
    
    -- Add the like
    INSERT INTO public.post_likes (post_id, user_id)
    VALUES (p_post_id, p_user_id)
    RETURNING id INTO v_like_id;
    
    -- Get the updated like count
    SELECT COUNT(*) INTO v_like_count
    FROM public.post_likes
    WHERE post_id = p_post_id;
    
    -- Create a notification for the post owner (if it's not their own like)
    IF v_post_owner_id != p_user_id THEN
        INSERT INTO public.notifications (
            user_id,
            type,
            title,
            message,
            data
        ) VALUES (
            v_post_owner_id,
            'post_like',
            'New like on your post',
            (SELECT username FROM public.users WHERE id = p_user_id) || ' liked your post',
            jsonb_build_object(
                'post_id', p_post_id,
                'liked_by', p_user_id
            )
        )
        RETURNING id INTO v_notification_id;
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'like_id', v_like_id,
        'like_count', v_like_count,
        'message', 'Post liked successfully'
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error: ' || SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
