-- Function to update user avatar by uploading to Supabase Storage
CREATE OR REPLACE FUNCTION public.update_user_avatar(
    p_user_id UUID,
    p_avatar_file BYTEA,
    p_file_extension TEXT DEFAULT 'jpg',
    p_content_type TEXT DEFAULT 'image/jpeg'
)
RETURNS JSONB AS $$
DECLARE
    v_file_path TEXT;
    v_file_name TEXT;
    v_public_url TEXT;
    v_username TEXT;
    v_old_avatar_url TEXT;
    v_bucket_name TEXT := 'avatars';
    v_storage_url TEXT;
    v_storage_key TEXT;
    v_storage_secret TEXT;
    v_jwt_secret TEXT;
    v_jwt_claims JSONB;
    v_jwt_token TEXT;
    v_http_response RECORD;
    v_http_status INT;
    v_response_body TEXT;
    v_public_url_result JSONB;
    v_error_message TEXT;
BEGIN
    -- Get user details
    SELECT username, avatar_url 
    INTO v_username, v_old_avatar_url
    FROM public.users 
    WHERE id = p_user_id;
    
    IF v_username IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'User not found'
        );
    END IF;
    
    -- Generate a unique file name
    v_file_name := p_user_id || '_' || floor(extract(epoch from now())) || '.' || p_file_extension;
    v_file_path := 'public/' || v_file_name;
    
    -- Get Supabase configuration
    SELECT current_setting('app.settings.storage_url', true) INTO v_storage_url;
    SELECT current_setting('app.settings.storage_key', true) INTO v_storage_key;
    SELECT current_setting('app.settings.storage_secret', true) INTO v_storage_secret;
    SELECT current_setting('app.settings.jwt_secret', true) INTO v_jwt_secret;
    
    -- Create JWT token for storage access
    v_jwt_claims := jsonb_build_object(
        'role', 'service_role',
        'exp', extract(epoch from now() + interval '15 minutes')::integer
    );
    
    -- In a real implementation, you would use the Supabase client SDK in your application
    -- The following is a simplified example using http extension
    -- Note: This is a conceptual example - in practice, you'd use the Supabase client
    
    -- 1. First, upload the file using Supabase Storage API
    -- (This would be done via the client SDK in your application)
    
    -- 2. Get public URL of the uploaded file
    -- (This would be returned by the storage.upload() method in the client SDK)
    
    -- For the purpose of this example, we'll assume we have the public URL
    -- In a real implementation, you would get this from the storage.upload() response
    v_public_url := 'https://' || v_storage_url || '/storage/v1/object/public/' || v_bucket_name || '/' || v_file_path;
    
    -- Update user's avatar URL in the database
    UPDATE public.users
    SET 
        avatar_url = v_public_url,
        updated_at = NOW()
    WHERE id = p_user_id
    RETURNING avatar_url INTO v_public_url;
    
    -- If there was a previous avatar, you might want to delete it
    -- This is a simplified example - in practice, you'd need to handle this carefully
    -- to avoid deleting avatars that might be in use by other users
    
    RETURN jsonb_build_object(
        'success', true,
        'avatar_url', v_public_url,
        'message', 'Avatar updated successfully'
    );
    
EXCEPTION WHEN OTHERS THEN
    -- Log the error
    GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
    
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Failed to update avatar: ' || v_error_message
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- You'll also need to create a storage bucket and set up appropriate policies
-- This should be done in your Supabase dashboard or via the management API

-- Example of storage policy (run this in your Supabase SQL editor):
/*
-- 1. Create a storage bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Set up storage policies
CREATE POLICY "Allow public read access to avatars"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

CREATE POLICY "Allow authenticated users to upload avatars"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Allow users to update their own avatars"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Allow users to delete their own avatars"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);
*/
