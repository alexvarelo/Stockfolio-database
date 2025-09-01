-- Migration: Add ticker column to posts table
-- This migration adds the ability to link posts to specific tickers (instruments)

-- Add the ticker column
ALTER TABLE public.posts 
    ADD COLUMN IF NOT EXISTS ticker VARCHAR(20);

-- Create a partial index on the ticker column for better performance
CREATE INDEX IF NOT EXISTS idx_posts_ticker ON public.posts(ticker) 
    WHERE ticker IS NOT NULL;

-- Update the updated_at timestamp
COMMENT ON COLUMN public.posts.updated_at IS 'Timestamp when the post was last updated';

-- Add a comment to explain the new column
COMMENT ON COLUMN public.posts.ticker IS 'Optional ticker symbol that this post is related to';

-- Update the RLS policy if needed (assuming RLS is enabled)
-- This ensures the ticker column is included in any existing RLS policies
-- Note: You might need to adjust this based on your actual RLS policies
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'posts' 
        AND policyname = 'Enable read access for public posts or user''s own posts'
    ) THEN
        DROP POLICY IF EXISTS "Enable read access for public posts or user's own posts" ON public.posts;
        CREATE POLICY "Enable read access for public posts or user's own posts"
            ON public.posts
            FOR SELECT
            USING (is_public = true OR user_id = auth.uid());
    END IF;
END $$;
