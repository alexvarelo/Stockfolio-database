/**
 * Type definitions for API Credentials table
 * Used for storing platform-wide external API authentication credentials
 */

export interface ApiCredentials {
  id: string;
  provider_name: string;
  client_id: string;
  client_secret: string;
  is_active: boolean;
  expires_at: string | null;
  metadata: Record<string, any>;
  created_at: string;
  updated_at: string;
}

export interface ApiCredentialsInsert {
  provider_name: string;
  client_id: string;
  client_secret: string;
  is_active?: boolean;
  expires_at?: string | null;
  metadata?: Record<string, any>;
}

export interface ApiCredentialsUpdate {
  provider_name?: string;
  client_id?: string;
  client_secret?: string;
  is_active?: boolean;
  expires_at?: string | null;
  metadata?: Record<string, any>;
}

/**
 * Supported API providers for financial market data
 */
export enum ApiProvider {
  POLYGON = 'polygon',
  ALPHA_VANTAGE = 'alpha_vantage',
  FINNHUB = 'finnhub',
  IEX_CLOUD = 'iex_cloud',
  TWELVE_DATA = 'twelve_data',
  YAHOO_FINANCE = 'yahoo_finance',
}

/**
 * Helper type for provider-specific metadata
 */
export interface ProviderMetadata {
  api_version?: string;
  rate_limit?: number;
  base_url?: string;
  additional_headers?: Record<string, string>;
  [key: string]: any;
}
