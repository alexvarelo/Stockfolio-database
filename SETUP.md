# Quick Setup Guide

## Deploy to Supabase

### Step 1: Create Supabase Project
1. Go to [supabase.com](https://supabase.com)
2. Click "New Project"
3. Choose your organization
4. Enter project name (e.g., "stockfolio")
5. Enter database password
6. Choose region closest to your users
7. Click "Create new project"

### Step 2: Run Database Migration
1. In your Supabase dashboard, go to **SQL Editor**
2. Click **New Query**
3. Copy and paste the entire contents of `migrations/001_initial_schema.sql`
4. Click **Run** to execute the migration

### Step 3: Verify Setup
Run these test queries in the SQL Editor:

```sql
-- Check if tables were created
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- Check if sample securities were inserted
SELECT symbol, name FROM public.securities LIMIT 5;

-- Test portfolio value function
SELECT calculate_portfolio_value('00000000-0000-0000-0000-000000000000');
```

### Step 4: Configure Authentication
1. Go to **Authentication > Settings**
2. Configure your site URL
3. Set up email templates if needed
4. Configure OAuth providers (Google, GitHub, etc.)

### Step 5: Get API Keys
1. Go to **Settings > API**
2. Copy your:
   - Project URL
   - Anon key
   - Service role key (keep this secret!)

## Environment Variables

Add these to your frontend app:

```env
NEXT_PUBLIC_SUPABASE_URL=your_project_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

## Next Steps

1. **Frontend Setup**: Initialize your React/Next.js app with Supabase client
2. **Authentication**: Set up user sign-up/sign-in flows
3. **Database Functions**: Use the provided functions for portfolio operations
4. **Real-time Data**: Integrate with market data APIs
5. **Deploy**: Deploy your frontend to Vercel/Netlify

## Common Issues

### RLS Policies
If you get permission errors, check that RLS policies are working:
```sql
-- Test RLS on portfolios table
SELECT * FROM public.portfolios LIMIT 1;
```

### Functions Not Found
If functions aren't working, make sure the migration ran completely:
```sql
-- Check if functions exist
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public';
```

### Authentication Issues
Make sure your auth is properly configured:
1. Check **Authentication > Settings**
2. Verify your site URL is correct
3. Test sign-up/sign-in flows

## Support

- [Supabase Documentation](https://supabase.com/docs)
- [Supabase Discord](https://discord.supabase.com)
- [GitHub Issues](https://github.com/supabase/supabase/issues) 