-- Add RLS policies for post_likes table

-- Allow authenticated users to view likes on public posts or posts they can see
CREATE POLICY "Allow reading likes on visible posts" 
ON public.post_likes
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.posts p
        WHERE p.id = post_likes.post_id 
        AND (
            p.is_public = true 
            OR p.user_id = auth.uid()
            OR EXISTS (
                SELECT 1 FROM public.user_follows uf
                WHERE uf.following_id = p.user_id 
                AND uf.follower_id = auth.uid()
            )
        )
    )
);

-- Allow users to like their own posts or public posts from others
CREATE POLICY "Allow inserting likes" 
ON public.post_likes
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.posts p
        WHERE p.id = post_likes.post_id 
        AND (
            p.is_public = true 
            OR p.user_id = auth.uid()
        )
    )
    AND user_id = auth.uid()
);

-- Allow users to remove their own likes
CREATE POLICY "Allow deleting own likes" 
ON public.post_likes
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- Add RLS policies for post_comments table

-- Allow authenticated users to view comments on visible posts
CREATE POLICY "Allow reading comments on visible posts" 
ON public.post_comments
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.posts p
        WHERE p.id = post_comments.post_id 
        AND (
            p.is_public = true 
            OR p.user_id = auth.uid()
            OR EXISTS (
                SELECT 1 FROM public.user_follows uf
                WHERE uf.following_id = p.user_id 
                AND uf.follower_id = auth.uid()
            )
        )
    )
);

-- Allow users to comment on their own posts or public posts from others
CREATE POLICY "Allow inserting comments" 
ON public.post_comments
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.posts p
        WHERE p.id = post_comments.post_id 
        AND (
            p.is_public = true 
            OR p.user_id = auth.uid()
        )
    )
    AND user_id = auth.uid()
);

-- Allow users to update their own comments
CREATE POLICY "Allow updating own comments" 
ON public.post_comments
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Allow users to delete their own comments
CREATE POLICY "Allow deleting own comments" 
ON public.post_comments
FOR DELETE
TO authenticated
USING (user_id = auth.uid());
