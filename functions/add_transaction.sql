-- Function to add a new transaction and update the corresponding holding
CREATE OR REPLACE FUNCTION public.add_transaction(
    p_portfolio_id UUID,
    p_ticker VARCHAR(20),
    p_transaction_type VARCHAR(20),
    p_quantity DECIMAL(15,6),
    p_price_per_share DECIMAL(10,2),
    p_fees DECIMAL(10,2) DEFAULT 0,
    p_transaction_date DATE DEFAULT CURRENT_DATE,
    p_notes TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_transaction_id UUID;
    v_holding_id UUID;
    v_existing_quantity DECIMAL(15,6);
    v_existing_avg_price DECIMAL(10,2);
    v_new_quantity DECIMAL(15,6);
    v_new_avg_price DECIMAL(10,2);
BEGIN
    -- Insert the new transaction
    INSERT INTO public.transactions (
        portfolio_id,
        ticker,
        transaction_type,
        quantity,
        price_per_share,
        fees,
        transaction_date,
        notes
    ) VALUES (
        p_portfolio_id,
        p_ticker,
        p_transaction_type,
        p_quantity,
        p_price_per_share,
        p_fees,
        p_transaction_date,
        p_notes
    )
    RETURNING id INTO v_transaction_id;

    -- Check if holding exists
    SELECT id, quantity, average_price 
    INTO v_holding_id, v_existing_quantity, v_existing_avg_price
    FROM public.holdings
    WHERE portfolio_id = p_portfolio_id AND ticker = p_ticker;

    IF p_transaction_type = 'BUY' THEN
        IF v_holding_id IS NULL THEN
            -- Create new holding
            INSERT INTO public.holdings (
                portfolio_id,
                ticker,
                quantity,
                average_price,
                notes
            ) VALUES (
                p_portfolio_id,
                p_ticker,
                p_quantity,
                p_price_per_share,
                'Initial purchase: ' || p_quantity || ' shares at ' || p_price_per_share
            )
            RETURNING id INTO v_holding_id;
        ELSE
            -- Update existing holding (calculate new average price)
            v_new_quantity := v_existing_quantity + p_quantity;
            v_new_avg_price := ((v_existing_quantity * v_existing_avg_price) + (p_quantity * p_price_per_share)) / v_new_quantity;
            
            UPDATE public.holdings
            SET 
                quantity = v_new_quantity,
                average_price = v_new_avg_price,
                updated_at = NOW()
            WHERE id = v_holding_id;
        END IF;
    ELSIF p_transaction_type = 'SELL' THEN
        IF v_holding_id IS NULL OR v_existing_quantity < p_quantity THEN
            RAISE EXCEPTION 'Insufficient shares to sell';
        END IF;
        
        v_new_quantity := v_existing_quantity - p_quantity;
        
        IF v_new_quantity = 0 THEN
            -- Delete the holding if quantity reaches zero
            DELETE FROM public.holdings WHERE id = v_holding_id;
        ELSE
            -- Update holding with reduced quantity (keep the same average price)
            UPDATE public.holdings
            SET 
                quantity = v_new_quantity,
                updated_at = NOW()
            WHERE id = v_holding_id;
        END IF;
    END IF;

    -- Update the portfolio's updated_at timestamp
    UPDATE public.portfolios
    SET updated_at = NOW()
    WHERE id = p_portfolio_id;

    RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql;
