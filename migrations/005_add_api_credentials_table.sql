-- Migration: Add API Credentials Table
-- This migration creates a table for storing API client credentials for financial market data

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

-- Create index for better performance
CREATE INDEX idx_api_credentials_provider ON public.api_credentials(provider_name);
CREATE INDEX idx_api_credentials_active ON public.api_credentials(is_active) WHERE is_active = true;

-- Apply updated_at trigger
CREATE TRIGGER update_api_credentials_updated_at 
BEFORE UPDATE ON public.api_credentials 
FOR EACH ROW 
EXECUTE FUNCTION update_updated_at_column();

-- Add comment for documentation
COMMENT ON TABLE public.api_credentials IS 'Stores API client credentials for external financial data providers';
COMMENT ON COLUMN public.api_credentials.provider_name IS 'Name of the API provider (e.g., "polygon", "alpha_vantage", "finnhub")';
COMMENT ON COLUMN public.api_credentials.client_id IS 'API client ID or API key';
COMMENT ON COLUMN public.api_credentials.client_secret IS 'API client secret or token (encrypted at application level)';
COMMENT ON COLUMN public.api_credentials.metadata IS 'Additional provider-specific configuration (JSON)';
