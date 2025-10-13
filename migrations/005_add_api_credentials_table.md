# Migration 005: API Credentials Table

## Overview
This migration adds a new table `api_credentials` for securely storing platform-wide API client credentials (client_id/client_secret) for external financial market data providers. These credentials are shared across the entire platform, not per-user.

## Table Structure

### `api_credentials`
Stores API authentication credentials for each provider at the platform level.

**Columns:**
- `id` (UUID): Primary key
- `provider_name` (VARCHAR): Name of the API provider (e.g., "polygon", "alpha_vantage", "finnhub")
- `client_id` (TEXT): API client ID or API key
- `client_secret` (TEXT): API client secret or token
- `is_active` (BOOLEAN): Whether these credentials are currently active
- `expires_at` (TIMESTAMP): Optional expiration timestamp for credentials
- `metadata` (JSONB): Additional provider-specific configuration
- `created_at` (TIMESTAMP): Record creation timestamp
- `updated_at` (TIMESTAMP): Last update timestamp

**Constraints:**
- Unique constraint on `provider_name` - one credential set per provider (platform-wide)

## Security Features

### Access Control
- Platform-wide credentials accessible by the application backend
- No Row Level Security (RLS) - managed at application level
- Should only be accessed by server-side code, not client-side

### Indexes
- `idx_api_credentials_provider`: Fast lookups by provider
- `idx_api_credentials_active`: Partial index for active credentials only

## Usage Examples

### Insert new credentials
```sql
INSERT INTO public.api_credentials (provider_name, client_id, client_secret)
VALUES (
    'polygon',
    'your_client_id',
    'your_client_secret'
);
```

### Update credentials
```sql
UPDATE public.api_credentials
SET client_secret = 'new_secret', updated_at = NOW()
WHERE provider_name = 'polygon';
```

### Retrieve active credentials
```sql
SELECT provider_name, client_id, client_secret, metadata
FROM public.api_credentials
WHERE is_active = true;
```

### Deactivate credentials
```sql
UPDATE public.api_credentials
SET is_active = false
WHERE provider_name = 'polygon';
```

## Security Best Practices

⚠️ **Important Security Notes:**

1. **Encryption at Application Level**: The `client_secret` field should be encrypted at the application level before storing in the database. Consider using:
   - Supabase Vault for secret management
   - Application-level encryption (AES-256)
   - Environment-specific encryption keys

2. **Never Log Secrets**: Ensure your application never logs the `client_secret` field

3. **Use HTTPS**: Always transmit credentials over secure connections

4. **Rotate Credentials**: Implement a credential rotation strategy using the `expires_at` field

5. **Audit Access**: Consider adding audit logging for credential access

## Supported Providers

Common financial data API providers you might use:
- **Polygon.io**: Real-time and historical market data
- **Alpha Vantage**: Stock market data and technical indicators
- **Finnhub**: Stock market data and news
- **IEX Cloud**: Financial data API
- **Twelve Data**: Real-time and historical market data

## Migration Rollback

To rollback this migration:
```sql
DROP TABLE IF EXISTS public.api_credentials CASCADE;
```
