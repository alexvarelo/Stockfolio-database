-- Function to get a summary of a portfolio including total value and other metrics
CREATE OR REPLACE FUNCTION public.get_portfolio_summary(portfolio_uuid UUID)
RETURNS TABLE (
    portfolio_id UUID,
    portfolio_name VARCHAR(255),
    user_id UUID,
    username VARCHAR(50),
    total_holdings INTEGER,
    total_value DECIMAL(15,2),
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id as portfolio_id,
        p.name as portfolio_name,
        p.user_id,
        u.username,
        (SELECT COUNT(*) FROM public.holdings h WHERE h.portfolio_id = p.id) as total_holdings,
        public.calculate_portfolio_value(p.id) as total_value,
        p.created_at,
        p.updated_at
    FROM 
        public.portfolios p
    JOIN 
        public.users u ON p.user_id = u.id
    WHERE 
        p.id = portfolio_uuid;
END;
$$ LANGUAGE plpgsql;
