

-- Function to calculate portfolio total value
CREATE OR REPLACE FUNCTION calculate_portfolio_value(portfolio_uuid UUID)
RETURNS DECIMAL(15,2) AS $$
DECLARE
    total_value DECIMAL(15,2) := 0;
BEGIN
    SELECT COALESCE(SUM(h.total_invested), 0)
    INTO total_value
    FROM public.holdings h
    WHERE h.portfolio_id = portfolio_uuid;
    
    RETURN total_value;
END;
$$ LANGUAGE plpgsql;

-- Function to get portfolio performance summary
CREATE OR REPLACE FUNCTION get_portfolio_summary(portfolio_uuid UUID)
RETURNS TABLE(
    total_holdings INTEGER,
    total_invested DECIMAL(15,2),
    total_transactions INTEGER,
    last_transaction_date DATE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(DISTINCT h.security_id)::INTEGER as total_holdings,
        COALESCE(SUM(h.total_invested), 0) as total_invested,
        COUNT(t.id)::INTEGER as total_transactions,
        MAX(t.transaction_date) as last_transaction_date
    FROM public.portfolios p
    LEFT JOIN public.holdings h ON p.id = h.portfolio_id
    LEFT JOIN public.transactions t ON p.id = t.portfolio_id
    WHERE p.id = portfolio_uuid
    GROUP BY p.id;
END;
$$ LANGUAGE plpgsql;

-- Function to get user's public portfolios
CREATE OR REPLACE FUNCTION get_public_portfolios()
RETURNS TABLE(
    portfolio_id UUID,
    user_id UUID,
    username VARCHAR(50),
    portfolio_name VARCHAR(255),
    portfolio_description TEXT,
    total_holdings INTEGER,
    total_invested DECIMAL(15,2),
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id as portfolio_id,
        p.user_id,
        u.username,
        p.name as portfolio_name,
        p.description as portfolio_description,
        COUNT(DISTINCT h.security_id)::INTEGER as total_holdings,
        COALESCE(SUM(h.total_invested), 0) as total_invested,
        p.created_at
    FROM public.portfolios p
    JOIN public.users u ON p.user_id = u.id
    LEFT JOIN public.holdings h ON p.id = h.portfolio_id
    WHERE p.is_public = true
    GROUP BY p.id, p.user_id, u.username, p.name, p.description, p.created_at
    ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get user's feed (posts from followed users and public posts)
CREATE OR REPLACE FUNCTION get_user_feed(user_uuid UUID, limit_count INTEGER DEFAULT 20)
RETURNS TABLE(
    post_id UUID,
    user_id UUID,
    username VARCHAR(50),
    full_name VARCHAR(255),
    avatar_url TEXT,
    portfolio_id UUID,
    portfolio_name VARCHAR(255),
    content TEXT,
    post_type VARCHAR(20),
    likes_count BIGINT,
    comments_count BIGINT,
    is_liked BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id as post_id,
        p.user_id,
        u.username,
        u.full_name,
        u.avatar_url,
        p.portfolio_id,
        port.name as portfolio_name,
        p.content,
        p.post_type,
        COUNT(pl.id) as likes_count,
        COUNT(pc.id) as comments_count,
        EXISTS(SELECT 1 FROM public.post_likes WHERE post_id = p.id AND user_id = user_uuid) as is_liked,
        p.created_at
    FROM public.posts p
    JOIN public.users u ON p.user_id = u.id
    LEFT JOIN public.portfolios port ON p.portfolio_id = port.id
    LEFT JOIN public.post_likes pl ON p.id = pl.post_id
    LEFT JOIN public.post_comments pc ON p.id = pc.post_id
    WHERE 
        p.is_public = true 
        OR p.user_id = user_uuid
        OR EXISTS(
            SELECT 1 FROM public.user_follows uf 
            WHERE uf.follower_id = user_uuid AND uf.following_id = p.user_id
        )
    GROUP BY p.id, p.user_id, u.username, u.full_name, u.avatar_url, p.portfolio_id, port.name, p.content, p.post_type, p.created_at
    ORDER BY p.created_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get portfolio holdings with current market data (placeholder for real-time data)
CREATE OR REPLACE FUNCTION get_portfolio_holdings(portfolio_uuid UUID)
RETURNS TABLE(
    ticker VARCHAR(20),
    quantity DECIMAL(15,6),
    average_price DECIMAL(10,2),
    total_invested DECIMAL(15,2),
    current_price DECIMAL(10,2), -- This would come from real-time API
    current_value DECIMAL(15,2), -- This would be calculated with real-time price
    gain_loss DECIMAL(15,2), -- This would be calculated with real-time price
    gain_loss_percentage DECIMAL(5,2), -- This would be calculated with real-time price
    notes TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        h.ticker,
        h.quantity,
        h.average_price,
        h.total_invested,
        0 as current_price, -- Placeholder for real-time price
        0 as current_value, -- Placeholder for calculated value
        0 as gain_loss, -- Placeholder for calculated gain/loss
        0 as gain_loss_percentage, -- Placeholder for calculated percentage
        h.notes
    FROM public.holdings h
    WHERE h.portfolio_id = portfolio_uuid
    ORDER BY h.total_invested DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to create a new transaction and update holdings
CREATE OR REPLACE FUNCTION add_transaction(
    portfolio_uuid UUID,
    ticker_param VARCHAR(20),
    transaction_type_param VARCHAR(20),
    quantity_param DECIMAL(15,6),
    price_per_share_param DECIMAL(10,2),
    transaction_date_param DATE,
    fees_param DECIMAL(10,2) DEFAULT 0,
    notes_param TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    transaction_id UUID;
    existing_holding_id UUID;
    new_quantity DECIMAL(15,6);
    new_average_price DECIMAL(10,2);
BEGIN
    -- Insert the transaction
    INSERT INTO public.transactions (
        portfolio_id, ticker, transaction_type, quantity, 
        price_per_share, transaction_date, fees, notes
    ) VALUES (
        portfolio_uuid, ticker_param, transaction_type_param, quantity_param,
        price_per_share_param, transaction_date_param, fees_param, notes_param
    ) RETURNING id INTO transaction_id;
    
    -- Check if holding exists
    SELECT id INTO existing_holding_id 
    FROM public.holdings 
    WHERE portfolio_id = portfolio_uuid AND ticker = ticker_param;
    
    -- Update or create holding based on transaction type
    IF transaction_type_param = 'BUY' THEN
        IF existing_holding_id IS NOT NULL THEN
            -- Update existing holding
            UPDATE public.holdings 
            SET 
                quantity = quantity + quantity_param,
                average_price = ((quantity * average_price) + (quantity_param * price_per_share_param)) / (quantity + quantity_param),
                updated_at = NOW()
            WHERE id = existing_holding_id;
        ELSE
            -- Create new holding
            INSERT INTO public.holdings (
                portfolio_id, ticker, quantity, average_price, notes
            ) VALUES (
                portfolio_uuid, ticker_param, quantity_param, price_per_share_param, notes_param
            );
        END IF;
    ELSIF transaction_type_param = 'SELL' THEN
        IF existing_holding_id IS NOT NULL THEN
            -- Update existing holding
            UPDATE public.holdings 
            SET 
                quantity = quantity - quantity_param,
                updated_at = NOW()
            WHERE id = existing_holding_id;
            
            -- Remove holding if quantity becomes 0 or negative
            DELETE FROM public.holdings 
            WHERE id = existing_holding_id AND quantity <= 0;
        END IF;
    END IF;
    
    RETURN transaction_id;
END;
$$ LANGUAGE plpgsql;

-- Function to get transaction history for a portfolio
CREATE OR REPLACE FUNCTION get_transaction_history(
    portfolio_uuid UUID, 
    limit_count INTEGER DEFAULT 50
)
RETURNS TABLE(
    transaction_id UUID,
    ticker VARCHAR(20),
    transaction_type VARCHAR(20),
    quantity DECIMAL(15,6),
    price_per_share DECIMAL(10,2),
    total_amount DECIMAL(15,2),
    fees DECIMAL(10,2),
    transaction_date DATE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id as transaction_id,
        t.ticker,
        t.transaction_type,
        t.quantity,
        t.price_per_share,
        t.total_amount,
        t.fees,
        t.transaction_date,
        t.notes,
        t.created_at
    FROM public.transactions t
    WHERE t.portfolio_id = portfolio_uuid
    ORDER BY t.transaction_date DESC, t.created_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql; 