-- Function to get all holdings for a portfolio
CREATE OR REPLACE FUNCTION public.get_portfolio_holdings(portfolio_uuid UUID)
RETURNS TABLE (
    id UUID,
    ticker VARCHAR(20),
    quantity DECIMAL(15,6),
    average_price DECIMAL(10,2),
    total_invested DECIMAL(15,2),
    current_price DECIMAL(10,2),
    current_value DECIMAL(15,2),
    profit_loss DECIMAL(15,2),
    profit_loss_pct DECIMAL(10,2),
    notes TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        h.id,
        h.ticker,
        h.quantity,
        h.average_price,
        h.total_invested,
        h.average_price as current_price, -- In a real app, this would come from a market data API
        h.quantity * h.average_price as current_value, -- Using average price as a placeholder
        (h.quantity * h.average_price) - h.total_invested as profit_loss,
        CASE 
            WHEN h.total_invested > 0 
            THEN ((h.quantity * h.average_price) - h.total_invested) / h.total_invested * 100 
            ELSE 0 
        END as profit_loss_pct,
        h.notes,
        h.created_at,
        h.updated_at
    FROM 
        public.holdings h
    WHERE 
        h.portfolio_id = portfolio_uuid
    ORDER BY 
        h.ticker;
END;
$$ LANGUAGE plpgsql;
