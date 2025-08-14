-- Function to add a comment to a post
CREATE OR REPLACE FUNCTION public.add_post_comment(
    p_post_id UUID,
    p_user_id UUID,
    p_content TEXT,
    p_parent_comment_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_comment_id UUID;
    v_comment_count BIGINT;
    v_post_owner_id UUID;
    v_notification_id UUID;
    v_mentioned_user_ids UUID[];
    v_mentioned_user_id UUID;
    v_mentioned_username TEXT;
    v_commenter_username TEXT;
    v_commenter_avatar_url TEXT;
    v_post_content TEXT;
    v_post_content_preview TEXT;
BEGIN
    -- Get commenter's username and avatar for the notification
    SELECT username, avatar_url 
    INTO v_commenter_username, v_commenter_avatar_url
    FROM public.users 
    WHERE id = p_user_id;
    
    -- Get post owner and content
    SELECT user_id, content, 
           CASE 
               WHEN length(content) > 50 THEN substring(content from 1 for 50) || '...'
               ELSE content
           END
    INTO v_post_owner_id, v_post_content, v_post_content_preview
    FROM public.posts
    WHERE id = p_post_id
    FOR UPDATE; -- Lock the row to prevent race conditions
    
    IF v_post_owner_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Post not found'
        );
    END IF;
    
    -- Add the comment
    INSERT INTO public.post_comments (
        post_id, 
        user_id, 
        content, 
        parent_comment_id
    ) VALUES (
        p_post_id, 
        p_user_id, 
        p_content,
        p_parent_comment_id
    )
    RETURNING id INTO v_comment_id;
    
    -- Get the updated comment count
    SELECT COUNT(*) INTO v_comment_count
    FROM public.post_comments
    WHERE post_id = p_post_id;
    
    -- Create a notification for the post owner (if it's not their own comment)
    IF v_post_owner_id != p_user_id THEN
        INSERT INTO public.notifications (
            user_id,
            type,
            title,
            message,
            data
        ) VALUES (
            v_post_owner_id,
            'post_comment',
            'New comment on your post',
            v_commenter_username || ' commented on your post: ' || 
                CASE 
                    WHEN length(p_content) > 50 THEN substring(p_content from 1 for 50) || '...' 
                    ELSE p_content 
                END,
            jsonb_build_object(
                'post_id', p_post_id,
                'comment_id', v_comment_id,
                'commenter_id', p_user_id,
                'commenter_username', v_commenter_username,
                'commenter_avatar_url', v_commenter_avatar_url,
                'post_content_preview', v_post_content_preview,
                'is_reply', (p_parent_comment_id IS NOT NULL)
            )
        )
        RETURNING id INTO v_notification_id;
    END IF;
    
    -- If this is a reply to a comment, notify the parent comment's author
    IF p_parent_comment_id IS NOT NULL THEN
        DECLARE
            v_parent_comment_author_id UUID;
        BEGIN
            SELECT user_id INTO v_parent_comment_author_id
            FROM public.post_comments
            WHERE id = p_parent_comment_id;
            
            IF v_parent_comment_author_id IS NOT NULL AND v_parent_comment_author_id != p_user_id AND v_parent_comment_author_id != v_post_owner_id THEN
                INSERT INTO public.notifications (
                    user_id,
                    type,
                    title,
                    message,
                    data
                ) VALUES (
                    v_parent_comment_author_id,
                    'comment_reply',
                    'New reply to your comment',
                    v_commenter_username || ' replied to your comment',
                    jsonb_build_object(
                        'post_id', p_post_id,
                        'comment_id', v_comment_id,
                        'parent_comment_id', p_parent_comment_id,
                        'commenter_id', p_user_id,
                        'commenter_username', v_commenter_username,
                        'commenter_avatar_url', v_commenter_avatar_url,
                        'post_content_preview', v_post_content_preview
                    )
                );
            END IF;
        EXCEPTION WHEN OTHERS THEN
            -- Log the error but don't fail the whole operation
            RAISE NOTICE 'Error notifying parent comment author: %', SQLERRM;
        END;
    END IF;
    
    -- Check for @mentions in the comment
    SELECT array_agg(matches[1]::uuid)
    INTO v_mentioned_user_ids
    FROM regexp_matches(p_content, '@([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})', 'g') AS matches;
    
    -- Create notifications for mentioned users
    IF v_mentioned_user_ids IS NOT NULL THEN
        FOREACH v_mentioned_user_id IN ARRAY v_mentioned_user_ids
        LOOP
            -- Skip if mentioning self or post owner (they already get a notification)
            IF v_mentioned_user_id != p_user_id AND 
               (v_mentioned_user_id != v_post_owner_id OR p_parent_comment_id IS NOT NULL) THEN
                
                -- Get the mentioned user's username
                SELECT username INTO v_mentioned_username
                FROM public.users
                WHERE id = v_mentioned_user_id;
                
                IF v_mentioned_username IS NOT NULL THEN
                    INSERT INTO public.notifications (
                        user_id,
                        type,
                        title,
                        message,
                        data
                    ) VALUES (
                        v_mentioned_user_id,
                        'mention',
                        'You were mentioned in a comment',
                        v_commenter_username || ' mentioned you in a comment',
                        jsonb_build_object(
                            'post_id', p_post_id,
                            'comment_id', v_comment_id,
                            'commenter_id', p_user_id,
                            'commenter_username', v_commenter_username,
                            'commenter_avatar_url', v_commenter_avatar_url,
                            'post_content_preview', v_post_content_preview,
                            'is_reply', (p_parent_comment_id IS NOT NULL)
                        )
                    );
                END IF;
            END IF;
        END LOOP;
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'comment_id', v_comment_id,
        'comment_count', v_comment_count,
        'message', 'Comment added successfully'
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error: ' || SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
