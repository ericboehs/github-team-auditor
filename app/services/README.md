# Services

This directory contains service objects that encapsulate business logic and external API integrations.

## Service Architecture

Services follow the single responsibility principle and handle complex business operations that would otherwise clutter models or controllers.

### GitHub Integration Services

Located in the `github/` subdirectory:

- **`Github::ApiClient`** - GitHub API client with rate limiting and error handling
- **`Github::TeamSyncService`** - High-level team synchronization orchestration
- **`Github::ApiConfiguration`** - Configuration constants and API thresholds

### Business Logic Services

- **`IssueCorrelationService`** - Handles GitHub issue searching, filtering, and correlation with team members

## Design Patterns

### Service Object Pattern

```ruby
class MyService
  def initialize(dependencies...)
    # Setup dependencies
  end
  
  def call
    # Main service logic
  end
  
  private
  
  # Private implementation methods
end
```

### API Client Pattern

The GitHub API client provides:
- Automatic rate limiting with intelligent delays
- Exponential backoff retry logic
- Structured error handling
- GraphQL and REST API support

## Rate Limiting Strategy

GitHub API integration implements sophisticated rate limiting:

- **High limit (>200 requests)**: No delay
- **Warning (50-200 requests)**: 0.1 second delay between requests  
- **Critical (<50 requests)**: Delay based on reset time or minimum 1 second
- **Rate limited**: Exponential backoff with retries

## Error Handling

Services handle common scenarios gracefully:
- `Octokit::NotFound` - Returns empty results
- `Octokit::TooManyRequests` - Implements retry logic
- `Octokit::ServerError` - Retries with exponential backoff
- Configuration errors - Clear error messages

## Usage Examples

### API Client

```ruby
organization = Organization.find_by(github_login: "department-of-veterans-affairs")
client = Github::ApiClient.new(organization)
members = client.fetch_team_members("platform-security")
```

### Issue Correlation

```ruby
service = IssueCorrelationService.new(
  team,
  api_client: client,
  search_terms: "access security",
  exclusion_terms: "test duplicate",
  repository: "department-of-veterans-affairs/va.gov-team"
)

correlations = service.find_correlations_for_team
```

## Testing

Service tests focus on:
- Business logic correctness
- Error handling scenarios
- API integration mocking
- Edge case handling

See [GitHub API Integration Guide](../../docs/api_integration.md) for detailed API documentation and [Development Guide](../../docs/development.md) for testing patterns.
