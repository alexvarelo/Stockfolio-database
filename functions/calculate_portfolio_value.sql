-- Function to calculate the total value of a portfolio
CREATE OR REPLACE FUNCTION public.calculate_portfolio_value(portfolio_uuid UUID)
RETURNS DECIMAL(15,2) AS $$
DECLARE
    total_value DECIMAL(15,2);
BEGIN
    SELECT COALESCE(SUM(h.quantity * h.average_price), 0)
    INTO total_value
    FROM public.holdings h
    WHERE h.portfolio_id = portfolio_uuid;
    
    RETURN total_value;
END;
$$ LANGUAGE plpgsql;
