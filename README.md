# Stockfolio Database Schema

A comprehensive database design for an investment tracking and social platform built on Supabase.

## Overview

This database schema supports:
- **Investment Tracking**: Users can track their portfolio holdings, transactions, and performance
- **Social Features**: Users can follow each other, share portfolios, and post updates
- **Watchlists**: Users can create watchlists for securities they're interested in
- **Notifications**: Built-in notification system for various events
- **Privacy Controls**: Granular privacy settings for portfolios and user profiles

## Database Structure

### Core Tables

#### Users (`public.users`)
- Extends Supabase auth.users
- Stores user profile information
- Privacy controls for public profiles

#### Securities (`public.securities`)
- Minimal table storing only ticker symbols
- Instrument details come from external API
- Supports any security type (stocks, ETFs, etc.)

#### Portfolios (`public.portfolios`)
- Users can have multiple portfolios
- Each portfolio can be public or private
- Supports default portfolio designation

#### Holdings (`public.holdings`)
- Current positions in each portfolio
- Uses ticker symbols as identifiers
- Tracks quantity and average price
- Auto-calculates total invested amount

#### Transactions (`public.transactions`)
- Complete transaction history
- Uses ticker symbols as identifiers
- Supports BUY, SELL, DIVIDEND, SPLIT transactions
- Includes fees and notes

### Social Features

#### User Follows (`public.user_follows`)
- Users can follow other users
- Prevents self-following

#### Portfolio Follows (`public.portfolio_follows`)
- Users can follow specific portfolios
- Independent of user follows

#### Posts (`public.posts`)
- Social feed posts
- Can be linked to specific portfolios
- Supports different post types (UPDATE, TRADE, ANALYSIS, GENERAL)

#### Post Interactions (`public.post_likes`, `public.post_comments`)
- Like and comment functionality
- Nested comments support

### Additional Features

#### Watchlists (`public.watchlists`, `public.watchlist_items`)
- Users can create multiple watchlists
- Track securities by ticker with target prices

#### Notifications (`public.notifications`)
- System notifications for various events
- JSONB data field for flexible notification content

#### User Settings (`public.user_settings`)
- User preferences and privacy settings
- Notification preferences

## Setup Instructions

### 1. Create Supabase Project
1. Go to [supabase.com](https://supabase.com)
2. Create a new project
3. Note your project URL and anon key

### 2. Run Database Schema
1. Go to your Supabase dashboard
2. Navigate to SQL Editor
3. Run the contents of `schema.sql` first
4. Then run the contents of `sample_data.sql`

### 3. Configure Authentication
1. In Supabase dashboard, go to Authentication > Settings
2. Configure your authentication providers (Google, GitHub, etc.)
3. Set up email templates if needed

### 4. Set up Row Level Security (RLS)
The schema includes RLS policies, but you may want to customize them based on your specific requirements.

## Key Features

### Investment Tracking
- **Portfolio Management**: Users can create multiple portfolios
- **Transaction History**: Complete audit trail of all trades
- **Holdings Tracking**: Real-time position tracking with average cost basis
- **Performance Calculation**: Built-in functions for portfolio analysis

### Social Features
- **User Following**: Follow other investors
- **Portfolio Sharing**: Share portfolios publicly or with followers
- **Social Feed**: Post updates about trades and analysis
- **Interactions**: Like and comment on posts

### Privacy & Security
- **Row Level Security**: Data access controlled by user permissions
- **Privacy Settings**: Granular control over what's public
- **Secure Authentication**: Built on Supabase Auth

## Database Functions

### Portfolio Functions
- `calculate_portfolio_value(portfolio_uuid)`: Calculate total portfolio value
- `get_portfolio_summary(portfolio_uuid)`: Get portfolio performance summary
- `get_portfolio_holdings(portfolio_uuid)`: Get current holdings with performance data
- `add_transaction(...)`: Add transaction and update holdings automatically
- `get_transaction_history(portfolio_uuid)`: Get transaction history

### Social Functions
- `get_public_portfolios()`: Get all public portfolios
- `get_user_feed(user_uuid)`: Get personalized social feed

## API Integration

### Real-time Data
The schema is designed to integrate with real-time market data APIs:
- Current prices can be fetched using ticker symbols
- Performance calculations can be updated in real-time
- Watchlist alerts can be triggered
- Instrument details come from external API

### External APIs
Consider integrating with:
- **Market Data**: Alpha Vantage, IEX Cloud, Yahoo Finance
- **News**: NewsAPI, Financial Times API
- **Charts**: TradingView, Chart.js

## Security Considerations

### Row Level Security (RLS)
All tables have RLS enabled with appropriate policies:
- Users can only access their own data
- Public data is accessible to all authenticated users
- Follow relationships control access to private content

### Data Validation
- Check constraints ensure data integrity
- Foreign key relationships prevent orphaned data
- Generated columns ensure calculated fields are always accurate

## Performance Optimizations

### Indexes
Strategic indexes on:
- Foreign key columns
- Frequently queried columns
- Date ranges for historical data

### Partitioning
Consider partitioning large tables:
- `transactions` by date
- `posts` by date
- `notifications` by date

## Sample Data

The `sample_data.sql` file includes:
- 15 popular US stocks
- Useful database functions
- Sample queries for common operations

## Next Steps

1. **Frontend Development**: Build your React/Vue/Angular frontend
2. **API Integration**: Connect to market data providers
3. **Real-time Features**: Implement WebSocket connections
4. **Mobile App**: Consider React Native or Flutter
5. **Advanced Features**: 
   - Portfolio rebalancing
   - Tax loss harvesting
   - Dividend tracking
   - Options trading

## Support

For questions or issues:
1. Check Supabase documentation
2. Review the SQL comments in the schema files
3. Test functions in the Supabase SQL editor

## License

This database schema is provided as-is for educational and development purposes. 