-- Stockfolio Database Schema
-- Investment Tracking and Social Platform

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Users table (extends Supabase auth.users)
CREATE TABLE public.users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255),
    bio TEXT,
    avatar_url TEXT,
    is_public BOOLEAN DEFAULT false,
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);


-- User portfolios table
CREATE TABLE public.portfolios (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    is_public BOOLEAN DEFAULT false,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, name)
);

-- Portfolio holdings table
CREATE TABLE public.holdings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    portfolio_id UUID REFERENCES public.portfolios(id) ON DELETE CASCADE NOT NULL,
    ticker VARCHAR(20) NOT NULL,
    quantity DECIMAL(15,6) NOT NULL,
    average_price DECIMAL(10,2) NOT NULL,
    total_invested DECIMAL(15,2) GENERATED ALWAYS AS (quantity * average_price) STORED,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(portfolio_id, ticker)
);

-- Transaction history table
CREATE TABLE public.transactions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    portfolio_id UUID REFERENCES public.portfolios(id) ON DELETE CASCADE NOT NULL,
    ticker VARCHAR(20) NOT NULL,
    transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN ('BUY', 'SELL', 'DIVIDEND', 'SPLIT')),
    quantity DECIMAL(15,6) NOT NULL,
    price_per_share DECIMAL(10,2) NOT NULL,
    total_amount DECIMAL(15,2) GENERATED ALWAYS AS (quantity * price_per_share) STORED,
    fees DECIMAL(10,2) DEFAULT 0,
    transaction_date DATE NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User follows table (social features)
CREATE TABLE public.user_follows (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    follower_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    following_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(follower_id, following_id),
    CHECK (follower_id != following_id)
);

-- Portfolio follows table
CREATE TABLE public.portfolio_follows (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    portfolio_id UUID REFERENCES public.portfolios(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, portfolio_id)
);

-- Posts/Updates table (social feed)
CREATE TABLE public.posts (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    portfolio_id UUID REFERENCES public.portfolios(id) ON DELETE CASCADE,
    ticker VARCHAR(20),
    content TEXT NOT NULL,
    post_type VARCHAR(20) DEFAULT 'UPDATE' CHECK (post_type IN ('UPDATE', 'TRADE', 'ANALYSIS', 'GENERAL')),
    is_public BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Post likes table
CREATE TABLE public.post_likes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);

-- Post comments table
CREATE TABLE public.post_comments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    parent_comment_id UUID REFERENCES public.post_comments(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Watchlists table
CREATE TABLE public.watchlists (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, name)
);

-- Watchlist items table
CREATE TABLE public.watchlist_items (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    watchlist_id UUID REFERENCES public.watchlists(id) ON DELETE CASCADE NOT NULL,
    ticker VARCHAR(20) NOT NULL,
    target_price DECIMAL(10,2),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(watchlist_id, ticker)
);

-- User notifications table
CREATE TABLE public.notifications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    data JSONB,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User settings table
CREATE TABLE public.user_settings (
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE PRIMARY KEY,
    email_notifications BOOLEAN DEFAULT true,
    push_notifications BOOLEAN DEFAULT true,
    portfolio_visibility VARCHAR(20) DEFAULT 'PRIVATE' CHECK (portfolio_visibility IN ('PRIVATE', 'FOLLOWERS', 'PUBLIC')),
    default_currency VARCHAR(3) DEFAULT 'USD',
    timezone VARCHAR(50) DEFAULT 'UTC',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- API credentials table
CREATE TABLE public.api_credentials (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    provider_name VARCHAR(100) NOT NULL,
    client_id TEXT NOT NULL,
    client_secret TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    expires_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(provider_name)
);

-- Create indexes for better performance
CREATE INDEX idx_holdings_portfolio_id ON public.holdings(portfolio_id);
CREATE INDEX idx_holdings_ticker ON public.holdings(ticker);
CREATE INDEX idx_transactions_portfolio_id ON public.transactions(portfolio_id);
CREATE INDEX idx_transactions_ticker ON public.transactions(ticker);
CREATE INDEX idx_transactions_date ON public.transactions(transaction_date);
CREATE INDEX idx_user_follows_follower_id ON public.user_follows(follower_id);
CREATE INDEX idx_user_follows_following_id ON public.user_follows(following_id);
CREATE INDEX idx_portfolio_follows_user_id ON public.portfolio_follows(user_id);
CREATE INDEX idx_portfolio_follows_portfolio_id ON public.portfolio_follows(portfolio_id);
CREATE INDEX idx_posts_user_id ON public.posts(user_id);
CREATE INDEX idx_posts_portfolio_id ON public.posts(portfolio_id);
CREATE INDEX idx_posts_created_at ON public.posts(created_at);
CREATE INDEX idx_posts_ticker ON public.posts(ticker) WHERE ticker IS NOT NULL;
CREATE INDEX idx_post_likes_post_id ON public.post_likes(post_id);
CREATE INDEX idx_post_comments_post_id ON public.post_comments(post_id);
CREATE INDEX idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX idx_notifications_is_read ON public.notifications(is_read);
CREATE INDEX idx_api_credentials_provider ON public.api_credentials(provider_name);
CREATE INDEX idx_api_credentials_active ON public.api_credentials(is_active) WHERE is_active = true;

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_securities_updated_at BEFORE UPDATE ON public.securities FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_portfolios_updated_at BEFORE UPDATE ON public.portfolios FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_holdings_updated_at BEFORE UPDATE ON public.holdings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_transactions_updated_at BEFORE UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_posts_updated_at BEFORE UPDATE ON public.posts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_post_comments_updated_at BEFORE UPDATE ON public.post_comments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_watchlists_updated_at BEFORE UPDATE ON public.watchlists FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_settings_updated_at BEFORE UPDATE ON public.user_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_api_credentials_updated_at BEFORE UPDATE ON public.api_credentials FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Row Level Security (RLS) policies
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.portfolios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.holdings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.portfolio_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.watchlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.watchlist_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

-- Users can view their own profile and public profiles
CREATE POLICY "Users can view own profile" ON public.users FOR SELECT USING (auth.uid() = id OR is_public = true);
CREATE POLICY "Authenticated users can view user details" ON public.users FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING (auth.uid() = id);

-- Portfolios policies
CREATE POLICY "Users can view own portfolios" ON public.portfolios FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can view public portfolios" ON public.portfolios FOR SELECT USING (is_public = true);
CREATE POLICY "Users can manage own portfolios" ON public.portfolios FOR ALL USING (auth.uid() = user_id);

-- Holdings policies
CREATE POLICY "Users can view own holdings" ON public.holdings FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.portfolios WHERE id = portfolio_id AND user_id = auth.uid())
);
CREATE POLICY "Users can manage own holdings" ON public.holdings FOR ALL USING (
    EXISTS (SELECT 1 FROM public.portfolios WHERE id = portfolio_id AND user_id = auth.uid())
);
-- Allow users to view holdings from followed users' public portfolios
CREATE POLICY "Users can view followed users' public holdings" ON public.holdings FOR SELECT USING (
    EXISTS (
        SELECT 1 
        FROM public.portfolios p
        JOIN public.user_follows uf ON p.user_id = uf.following_id
        WHERE p.id = portfolio_id 
        AND uf.follower_id = auth.uid()
        AND p.is_public = true
    )
);

-- Transactions policies
CREATE POLICY "Users can view own transactions" ON public.transactions FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.portfolios WHERE id = portfolio_id AND user_id = auth.uid())
);
CREATE POLICY "Users can manage own transactions" ON public.transactions FOR ALL USING (
    EXISTS (SELECT 1 FROM public.portfolios WHERE id = portfolio_id AND user_id = auth.uid())
);

-- Portfolio follows policies
CREATE POLICY "Users can view their own follows"
ON public.portfolio_follows
FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can follow public portfolios"
ON public.portfolio_follows
FOR INSERT
WITH CHECK (
  auth.role() = 'authenticated' AND
  auth.uid() = user_id AND
  portfolio_id IN (
    SELECT id FROM public.portfolios 
    WHERE is_public = true
  )
);

CREATE POLICY "Users can unfollow"
ON public.portfolio_follows
FOR DELETE
USING (auth.uid() = user_id);

-- Posts policies
CREATE POLICY "Users can view public posts" ON public.posts FOR SELECT USING (is_public = true);
CREATE POLICY "Users can view own posts" ON public.posts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own posts" ON public.posts FOR ALL USING (auth.uid() = user_id);

-- Articles policies
CREATE POLICY "Anyone can view published articles" ON public.articles FOR SELECT USING (status = 'published');
CREATE POLICY "Users can view their own draft articles" ON public.articles FOR SELECT USING (auth.uid() = metadata->>'author_id' OR status = 'published');
CREATE POLICY "Service role can manage all articles" ON public.articles FOR ALL USING (auth.role() = 'service_role');

-- Article sections policies (inherit from articles)
CREATE POLICY "Users can view article sections" ON public.article_sections FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.articles a WHERE a.id = article_id AND a.status = 'published')
);
CREATE POLICY "Service role can manage article sections" ON public.article_sections FOR ALL USING (auth.role() = 'service_role');

-- Article sources policies (inherit from articles)
CREATE POLICY "Users can view article sources" ON public.article_sources FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.articles a WHERE a.id = article_id AND a.status = 'published')
);
CREATE POLICY "Service role can manage article sources" ON public.article_sources FOR ALL USING (auth.role() = 'service_role');

-- Article engagement policies
CREATE POLICY "Users can view public article engagement" ON public.article_engagement FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.articles a WHERE a.id = article_id AND a.status = 'published')
);
CREATE POLICY "Users can manage their own engagement" ON public.article_engagement FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Service role can manage all engagement" ON public.article_engagement FOR ALL USING (auth.role() = 'service_role');

-- Apply updated_at triggers for articles
CREATE TRIGGER update_articles_updated_at BEFORE UPDATE ON public.articles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Articles policies
CREATE POLICY "Anyone can view published articles" ON public.articles FOR SELECT USING (status = 'published');
CREATE POLICY "Users can view their own draft articles" ON public.articles FOR SELECT USING (auth.uid() = metadata->>'author_id' OR status = 'published');
CREATE POLICY "Service role can manage all articles" ON public.articles FOR ALL USING (auth.role() = 'service_role');

-- Article sections policies (inherit from articles)
CREATE POLICY "Users can view article sections" ON public.article_sections FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.articles a WHERE a.id = article_id AND a.status = 'published')
);
CREATE POLICY "Service role can manage article sections" ON public.article_sections FOR ALL USING (auth.role() = 'service_role');

-- Article sources policies (inherit from articles)
CREATE POLICY "Users can view article sources" ON public.article_sources FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.articles a WHERE a.id = article_id AND a.status = 'published')
);
CREATE POLICY "Service role can manage article sources" ON public.article_sources FOR ALL USING (auth.role() = 'service_role');

-- Article engagement policies
CREATE POLICY "Users can view public article engagement" ON public.article_engagement FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.articles a WHERE a.id = article_id AND a.status = 'published')
);
CREATE POLICY "Users can manage their own engagement" ON public.article_engagement FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Service role can manage all engagement" ON public.article_engagement FOR ALL USING (auth.role() = 'service_role');

-- Users can view their own watchlist items
CREATE POLICY "Users can view own watchlist items" ON public.watchlist_items FOR SELECT USING (
    auth.role() = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM public.watchlists w
        WHERE w.id = watchlist_id
        AND w.user_id = auth.uid()
    )
);

-- Users can insert items into their own watchlists
CREATE POLICY "Users can insert own watchlist items" ON public.watchlist_items FOR INSERT WITH CHECK (
    auth.role() = 'authenticated' AND
    auth.uid() IS NOT NULL AND
    watchlist_id IS NOT NULL AND
    EXISTS (
        SELECT 1 FROM public.watchlists w
        WHERE w.id = watchlist_id
        AND w.user_id = auth.uid()
    )
);

-- Users can update their own watchlist items
CREATE POLICY "Users can update own watchlist items" ON public.watchlist_items FOR UPDATE USING (
    auth.role() = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM public.watchlists w
        WHERE w.id = watchlist_id
        AND w.user_id = auth.uid()
    )
) WITH CHECK (
    auth.role() = 'authenticated' AND
    watchlist_id IS NOT NULL AND
    EXISTS (
        SELECT 1 FROM public.watchlists w
        WHERE w.id = watchlist_id
        AND w.user_id = auth.uid()
    )
);

-- Users can delete their own watchlist items
CREATE POLICY "Users can delete own watchlist items" ON public.watchlist_items FOR DELETE USING (
    auth.role() = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM public.watchlists w
        WHERE w.id = watchlist_id
        AND w.user_id = auth.uid()
    )
);

-- User follows policies
CREATE POLICY "Users can view their follows and followers" ON public.user_follows
FOR SELECT
USING (
    auth.uid() = follower_id OR 
    auth.uid() = following_id OR
    EXISTS (
        SELECT 1 FROM public.users u 
        WHERE (u.id = follower_id OR u.id = following_id) 
        AND u.is_public = true
    )
);

CREATE POLICY "Users can follow other users" ON public.user_follows
FOR INSERT
WITH CHECK (
    auth.role() = 'authenticated' AND
    auth.uid() = follower_id AND
    follower_id != following_id AND
    EXISTS (SELECT 1 FROM public.users WHERE id = following_id)
);

CREATE POLICY "Users can unfollow" ON public.user_follows
FOR DELETE
USING (auth.uid() = follower_id);

-- Articles table for generated content
CREATE TABLE public.articles (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    slug VARCHAR(500) UNIQUE NOT NULL,
    summary TEXT,
    content JSONB NOT NULL, -- Structured content with sections, paragraphs, etc.
    article_type VARCHAR(50) NOT NULL CHECK (article_type IN ('TICKER_ANALYSIS', 'NEWS_SUMMARY', 'MARKET_OVERVIEW')),
    tickers TEXT[], -- Array of tickers this article relates to
    tags TEXT[], -- Array of tags for categorization
    author VARCHAR(255), -- Could be AI or user
    status VARCHAR(20) DEFAULT 'published' CHECK (status IN ('draft', 'published', 'archived')),
    view_count INTEGER DEFAULT 0,
    is_premium BOOLEAN DEFAULT false,
    metadata JSONB DEFAULT '{}', -- Additional metadata like sources, generated_at, etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Article sections for more granular content structure (optional)
CREATE TABLE public.article_sections (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    article_id UUID REFERENCES public.articles(id) ON DELETE CASCADE NOT NULL,
    section_title VARCHAR(255) NOT NULL,
    section_order INTEGER NOT NULL,
    content JSONB NOT NULL, -- Array of paragraphs or structured content
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(article_id, section_order)
);

-- Article sources/references
CREATE TABLE public.article_sources (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    article_id UUID REFERENCES public.articles(id) ON DELETE CASCADE NOT NULL,
    source_type VARCHAR(50) NOT NULL CHECK (source_type IN ('NEWS_API', 'FINANCIAL_DATA', 'USER_INPUT', 'AI_GENERATED')),
    source_url TEXT,
    source_title VARCHAR(500),
    source_date DATE,
    relevance_score DECIMAL(3,2), -- 0.00 to 1.00
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Article engagement metrics
CREATE TABLE public.article_engagement (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    article_id UUID REFERENCES public.articles(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    engagement_type VARCHAR(20) NOT NULL CHECK (engagement_type IN ('view', 'like', 'share', 'bookmark', 'comment')),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(article_id, user_id, engagement_type)
);

-- Create indexes for articles
CREATE INDEX idx_articles_type ON public.articles(article_type);
CREATE INDEX idx_articles_tickers ON public.articles USING GIN(tickers);
CREATE INDEX idx_articles_tags ON public.articles USING GIN(tags);
CREATE INDEX idx_articles_status ON public.articles(status);
CREATE INDEX idx_articles_created_at ON public.articles(created_at DESC);
CREATE INDEX idx_articles_slug ON public.articles(slug);

CREATE INDEX idx_article_sections_article_id ON public.article_sections(article_id);
CREATE INDEX idx_article_sections_order ON public.article_sections(article_id, section_order);

CREATE INDEX idx_article_sources_article_id ON public.article_sources(article_id);
CREATE INDEX idx_article_sources_type ON public.article_sources(source_type);

CREATE INDEX idx_article_engagement_article_id ON public.article_engagement(article_id);
CREATE INDEX idx_article_engagement_user_id ON public.article_engagement(user_id);
CREATE INDEX idx_article_engagement_type ON public.article_engagement(engagement_type);