# API Credentials Table Setup

## Overview
A new table has been created to securely store platform-wide API client credentials (client_id/client_secret combinations) for external financial market data providers. These credentials are shared across the entire platform and managed at the application level.

## Files Created/Modified

### New Files
1. **`migrations/005_add_api_credentials_table.sql`** - Migration script to create the table
2. **`migrations/005_add_api_credentials_table.md`** - Detailed documentation
3. **`types/api_credentials.ts`** - TypeScript type definitions

### Modified Files
1. **`schema.sql`** - Updated with the new table definition, indexes, and triggers

## Quick Start

### 1. Apply the Migration
Run the migration file to create the table in your database:
```bash
# If using Supabase CLI
supabase db push

# Or apply manually
psql -d your_database -f migrations/005_add_api_credentials_table.sql
```

### 2. Store API Credentials (Server-Side Only)
```typescript
// In a Supabase Edge Function or backend service
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  SUPABASE_URL, 
  SUPABASE_SERVICE_ROLE_KEY // Use service role key for backend
);

// Insert credentials
const { data, error } = await supabase
  .from('api_credentials')
  .insert({
    provider_name: 'polygon',
    client_id: 'your_client_id',
    client_secret: 'your_client_secret', // Should be encrypted!
    is_active: true,
    metadata: {
      api_version: 'v2',
      rate_limit: 5
    }
  });
```

### 3. Retrieve Credentials (Server-Side Only)
```typescript
// Get active credentials for a specific provider
const { data, error } = await supabase
  .from('api_credentials')
  .select('*')
  .eq('provider_name', 'polygon')
  .eq('is_active', true)
  .single();
```

## Table Schema

```sql
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
```

## Security Features

✅ **Platform-Wide Credentials** - Shared across all users, managed by backend  
✅ **Unique Constraint** - One credential set per provider (platform-wide)  
✅ **Automatic Timestamps** - `updated_at` automatically maintained  
✅ **Server-Side Only** - Should only be accessed by backend services, not client-side  

## ⚠️ Security Recommendations

1. **Encrypt Secrets**: Always encrypt `client_secret` at the application level before storing
2. **Use Supabase Vault**: Consider using Supabase Vault for additional secret management
3. **Backend Only**: Only access this table from server-side code (Supabase Edge Functions, backend APIs)
4. **Never Expose to Client**: Do not expose these credentials to client-side code
5. **HTTPS Only**: Always use secure connections
6. **Rotate Regularly**: Implement credential rotation using the `expires_at` field

## Supported Providers

The table supports any API provider. Common examples:
- **polygon** - Polygon.io
- **alpha_vantage** - Alpha Vantage
- **finnhub** - Finnhub
- **iex_cloud** - IEX Cloud
- **twelve_data** - Twelve Data

## Example: Complete Integration

```typescript
import { ApiProvider } from './types/api_credentials';

class ApiCredentialsService {
  constructor(private supabase: SupabaseClient) {}

  async storeCredentials(
    provider: ApiProvider,
    clientId: string,
    clientSecret: string,
    metadata?: Record<string, any>
  ) {
    // Encrypt the secret before storing
    const encryptedSecret = await this.encrypt(clientSecret);
    
    const { data, error } = await this.supabase
      .from('api_credentials')
      .upsert({
        provider_name: provider,
        client_id: clientId,
        client_secret: encryptedSecret,
        is_active: true,
        metadata: metadata || {}
      }, {
        onConflict: 'user_id,provider_name'
      });
    
    if (error) throw error;
    return data;
  }

  async getCredentials(provider: ApiProvider) {
    const { data, error } = await this.supabase
      .from('api_credentials')
      .select('*')
      .eq('provider_name', provider)
      .eq('is_active', true)
      .single();
    
    if (error) throw error;
    
    // Decrypt the secret before returning
    if (data) {
      data.client_secret = await this.decrypt(data.client_secret);
    }
    
    return data;
  }

  async deactivateCredentials(provider: ApiProvider) {
    const { error } = await this.supabase
      .from('api_credentials')
      .update({ is_active: false })
      .eq('provider_name', provider);
    
    if (error) throw error;
  }

  private async encrypt(value: string): Promise<string> {
    // Implement your encryption logic here
    // Example: Use Web Crypto API or a library like crypto-js
    return value; // Replace with actual encryption
  }

  private async decrypt(value: string): Promise<string> {
    // Implement your decryption logic here
    return value; // Replace with actual decryption
  }
}
```

## Testing

```sql
-- Test insert
INSERT INTO public.api_credentials (provider_name, client_id, client_secret)
VALUES ('polygon', 'test_client_id', 'test_secret');

-- Test select
SELECT * FROM public.api_credentials WHERE provider_name = 'polygon';

-- Test update
UPDATE public.api_credentials 
SET is_active = false 
WHERE provider_name = 'polygon';

-- Test delete
DELETE FROM public.api_credentials WHERE provider_name = 'polygon';
```

## Rollback

If you need to remove this table:
```sql
DROP TABLE IF EXISTS public.api_credentials CASCADE;
```

## Next Steps

1. Apply the migration to your database
2. Implement encryption/decryption in your application layer
3. Update your API service to use stored credentials
4. Add UI for users to manage their API credentials
5. Implement credential rotation logic
