-- Migration: Link Transactions to Holdings
-- This migration adds a holding_id foreign key to the transactions table
-- and updates the add_transaction function to maintain the relationship

-- Add holding_id column to transactions table
ALTER TABLE public.transactions
ADD COLUMN holding_id UUID REFERENCES public.holdings(id) ON DELETE SET NULL;

-- Create an index on the new foreign key
CREATE INDEX idx_transactions_holding_id ON public.transactions(holding_id);

-- Drop the existing function to recreate it with the new logic
DROP FUNCTION IF EXISTS public.add_transaction(
    portfolio_uuid UUID,
    ticker_param VARCHAR(20),
    transaction_type_param VARCHAR(20),
    quantity_param DECIMAL(15,6),
    price_per_share_param DECIMAL(10,2),
    transaction_date_param DATE,
    fees_param DECIMAL(10,2),
    notes_param TEXT
);

-- Recreate the add_transaction function to handle the holding relationship
CREATE OR REPLACE FUNCTION public.add_transaction(
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
    new_holding_id UUID;
BEGIN
    -- Check if holding exists
    SELECT id INTO existing_holding_id 
    FROM public.holdings 
    WHERE portfolio_id = portfolio_uuid AND ticker = ticker_param;
    
    -- Handle the holding first
    IF transaction_type_param = 'BUY' THEN
        IF existing_holding_id IS NOT NULL THEN
            -- Update existing holding
            UPDATE public.holdings 
            SET 
                quantity = quantity + quantity_param,
                average_price = ((quantity * average_price) + (quantity_param * price_per_share_param)) / (quantity + quantity_param),
                updated_at = NOW()
            WHERE id = existing_holding_id
            RETURNING id INTO new_holding_id;
        ELSE
            -- Create new holding and capture the new ID
            INSERT INTO public.holdings (
                portfolio_id, ticker, quantity, average_price, notes
            ) VALUES (
                portfolio_uuid, ticker_param, quantity_param, price_per_share_param, notes_param
            )
            RETURNING id INTO new_holding_id;
        END IF;
    ELSIF transaction_type_param = 'SELL' THEN
        IF existing_holding_id IS NOT NULL THEN
            -- Update existing holding
            UPDATE public.holdings 
            SET 
                quantity = quantity - quantity_param,
                updated_at = NOW()
            WHERE id = existing_holding_id
            RETURNING id INTO new_holding_id;
            
            -- Remove holding if quantity becomes 0 or negative
            DELETE FROM public.holdings 
            WHERE id = existing_holding_id AND quantity <= 0;
        ELSE
            -- For selling a non-existent holding, we'll still create the transaction
            -- but it won't be linked to any holding
            new_holding_id := NULL;
        END IF;
    ELSE
        -- For other transaction types (DIVIDEND, SPLIT), just get the holding ID if it exists
        new_holding_id := existing_holding_id;
    END IF;
    
    -- Insert the transaction with the holding_id
    -- Make sure to use COALESCE to handle the case where new_holding_id might be NULL
    INSERT INTO public.transactions (
        portfolio_id, 
        holding_id,
        ticker, 
        transaction_type, 
        quantity, 
        price_per_share, 
        transaction_date, 
        fees, 
        notes
    ) VALUES (
        portfolio_uuid, 
        COALESCE(new_holding_id, existing_holding_id),  -- Use either the new or existing holding ID
        ticker_param, 
        transaction_type_param, 
        quantity_param,
        price_per_share_param, 
        transaction_date_param, 
        fees_param, 
        notes_param
    ) RETURNING id INTO transaction_id;
    
    RETURN transaction_id;
END;
$$ LANGUAGE plpgsql;
