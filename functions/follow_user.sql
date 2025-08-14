-- Function to follow another user
CREATE OR REPLACE FUNCTION public.follow_user(
    p_follower_id UUID,
    p_following_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_follow_id UUID;
    v_following_username TEXT;
    v_follower_username TEXT;
    v_follower_avatar_url TEXT;
    v_notification_id UUID;
    v_following_is_public BOOLEAN;
BEGIN
    -- Check if trying to follow self
    IF p_follower_id = p_following_id THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Cannot follow yourself'
        );
    END IF;
    
    -- Check if the target user exists and get their username and privacy setting
    SELECT username, is_public 
    INTO v_following_username, v_following_is_public
    FROM public.users
    WHERE id = p_following_id
    FOR UPDATE; -- Lock the row to prevent race conditions
    
    IF v_following_username IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'User not found'
        );
    END IF;
    
    -- Check if already following
    IF EXISTS (
        SELECT 1 
        FROM public.user_follows 
        WHERE follower_id = p_follower_id AND following_id = p_following_id
    ) THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Already following this user'
        );
    END IF;
    
    -- Get follower's details for notification
    SELECT username, avatar_url 
    INTO v_follower_username, v_follower_avatar_url
    FROM public.users 
    WHERE id = p_follower_id;
    
    -- Create the follow relationship
    INSERT INTO public.user_follows (follower_id, following_id)
    VALUES (p_follower_id, p_following_id)
    RETURNING id INTO v_follow_id;
    
    -- Send notification to the user being followed (if they have public profile or not)
    -- We'll still notify even if the profile is public to let them know about new followers
    INSERT INTO public.notifications (
        user_id,
        type,
        title,
        message,
        data
    ) VALUES (
        p_following_id,
        'new_follower',
        'New follower',
        v_follower_username || ' started following you',
        jsonb_build_object(
            'follower_id', p_follower_id,
            'follower_username', v_follower_username,
            'follower_avatar_url', v_follower_avatar_url,
            'is_public', v_following_is_public
        )
    )
    RETURNING id INTO v_notification_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'follow_id', v_follow_id,
        'is_public', v_following_is_public,
        'message', 'Successfully followed user'
    );
    
EXCEPTION 
    WHEN unique_violation THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Already following this user'
        );
    WHEN foreign_key_violation THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'User not found'
        );
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Error: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
