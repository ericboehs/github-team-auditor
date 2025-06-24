# GitHub API Integration Guide

This document explains how the GitHub Team Auditor integrates with the GitHub API for team and member management.

## Overview

The application uses the Octokit Ruby gem to interact with GitHub's REST and GraphQL APIs, providing:

- Team member synchronization
- Organization and team data fetching
- Rate limiting and retry logic
- Background job processing for non-blocking operations

## Configuration

### Environment Variables

```bash
# Required: GitHub Personal Access Token
GHTA_GITHUB_TOKEN=ghp_your_token_here
```

### Token Permissions

The GitHub token requires the following scopes:
- `read:org` - Read organization membership and team data
- `read:user` - Read user profile information

## API Client Architecture

### Core Components

1. **Github::ApiClient** - Main API client with rate limiting
2. **Github::ApiConfiguration** - Configuration constants and thresholds
3. **Github::TeamSyncService** - High-level service for team synchronization

### Rate Limiting Strategy

The API client implements a sophisticated rate limiting strategy:

```ruby
# Rate limit thresholds
CRITICAL_RATE_LIMIT_THRESHOLD = 50    # requests remaining
WARNING_RATE_LIMIT_THRESHOLD = 200    # requests remaining
DEFAULT_RATE_LIMIT_DELAY = 0.1        # seconds
MIN_CRITICAL_DELAY = 1.0              # seconds minimum when critical
MAX_RETRY_DELAY = 60                  # seconds maximum retry delay
```

**Behavior:**
- **High limit (>200)**: No delay
- **Warning (50-200)**: 0.1 second delay between requests
- **Critical (<50)**: Delay based on reset time or minimum 1 second
- **Rate limited**: Exponential backoff with retries

### Error Handling

The client handles common GitHub API errors:

- `Octokit::NotFound` - Returns empty results gracefully
- `Octokit::TooManyRequests` - Implements retry logic with backoff
- `Octokit::ServerError` - Retries with exponential backoff

## Key API Operations

### Team Member Fetching

Uses GraphQL for efficient pagination:

```ruby
client = Github::ApiClient.new(organization)
members = client.fetch_team_members("platform-security")
```

**Returns:**
```ruby
[
  {
    github_login: "username",
    name: "Full Name",
    avatar_url: "https://github.com/username.png",
    maintainer_role: false
  }
]
```

### Team Information

Fetches team metadata:

```ruby
team_data = client.fetch_team_by_slug("platform-security")
```

**Returns:**
```ruby
{
  name: "Platform Security",
  github_slug: "platform-security",
  description: "Team description",
  members_count: 15,
  privacy: "closed"
}
```

### User Details

Enriches member data with profile information:

```ruby
user_data = client.user_details("username")
```

**Returns:**
```ruby
{
  github_login: "username",
  name: "Full Name",
  email: "user@example.com",
  avatar_url: "https://github.com/username.png",
  company: "Company Name",
  location: "City, State",
  bio: "User bio"
}
```

### Issue Search

Searches for issues across repositories:

```ruby
issues = client.search_issues("audit security", repository: "org/repo")
```

## Background Job Integration

### Team Sync Job

Synchronizes team data in the background:

```ruby
TeamSyncJob.perform_later(team_id)
```

**Process:**
1. Fetches current team data from GitHub
2. Updates team metadata
3. Syncs team members
4. Handles member additions/removals
5. Updates last sync timestamp

### Member Enrichment Job

Enriches member profiles with additional GitHub data:

```ruby
MemberEnrichmentJob.perform_later(audit_member_id)
```

**Process:**
1. Fetches detailed user information
2. Updates member profile data
3. Handles API rate limits gracefully

## Usage Examples

### Manual Team Sync

```ruby
# In Rails console or controller
team = Team.find_by(github_slug: "platform-security")
team.sync_from_github!
```

### Custom API Queries

```ruby
# Initialize client for organization
organization = Organization.find_by(github_login: "department-of-veterans-affairs")
client = Github::ApiClient.new(organization)

# Search for security-related issues
security_issues = client.search_issues("label:security is:open")

# Get user details for audit correlation
user_details = client.user_details("security-team-member")
```

### Batch Operations

```ruby
# Sync all teams for an organization
organization.teams.find_each do |team|
  TeamSyncJob.perform_later(team.id)
end

# Enrich all members in an audit session
audit_session.audit_members.find_each do |member|
  MemberEnrichmentJob.perform_later(member.id)
end
```

## Monitoring and Debugging

### Logging

The API client logs important events:

```ruby
# Rate limit warnings
Rails.logger.warn "Rate limited. Sleeping for 30s (attempt 1/3)"

# Critical rate limit notifications
Rails.logger.info "Rate limit critical (45 remaining). Sleeping for 15s"

# Server error retries
Rails.logger.warn "Server error (502 Bad Gateway). Retrying in 2s (attempt 1/3)"
```

### Testing API Integration

The test suite includes comprehensive API client testing:

```ruby
# Unit tests with mocked responses
test "should fetch team members with GraphQL successfully"

# Integration tests with real API calls (when token available)
test "should handle real GitHub API responses"

# Error scenario testing
test "should retry on Octokit::TooManyRequests"
```

## Best Practices

### 1. Rate Limit Awareness

- Monitor your API usage in production
- Use background jobs for bulk operations
- Implement graceful degradation when rate limited

### 2. Error Handling

- Always handle `Octokit::NotFound` gracefully
- Implement retry logic for transient errors
- Log errors for debugging and monitoring

### 3. Data Synchronization

- Use timestamps to track sync status
- Implement incremental sync where possible
- Handle member additions and removals properly

### 4. Security

- Store tokens securely in Rails credentials
- Use minimum required token permissions
- Rotate tokens regularly

## Troubleshooting

### Common Issues

**Token Permissions**
```
Error: Octokit::Forbidden
Solution: Ensure token has read:org and read:user scopes
```

**Rate Limiting**
```
Error: Octokit::TooManyRequests
Solution: Implemented automatically with exponential backoff
```

**Team Not Found**
```
Error: Octokit::NotFound
Solution: Verify team slug and organization access
```

### Configuration Verification

```ruby
# Test API connectivity
organization = Organization.first
client = Github::ApiClient.new(organization)
rate_limit = client.instance_variable_get(:@client).rate_limit
puts "Rate limit: #{rate_limit.remaining}/#{rate_limit.limit}"
```

This integration provides robust, rate-limited access to GitHub's API while gracefully handling errors and providing comprehensive team auditing capabilities.