# Background Jobs

This directory contains the background job classes that handle asynchronous operations for GitHub team auditing.

## Job Architecture

All jobs follow a consistent orchestration pattern with shared concerns for maintainability and real-time UI updates. See [Job Architecture Guide](../../docs/job_architecture.md) for detailed information.

### Core Jobs

- **`TeamSyncJob`** - Synchronizes team member data from GitHub API with full profile enrichment using GraphQL
- **`IssueCorrelationFinderJob`** - Finds GitHub issues related to team members using configurable search terms via GraphQL batch processing

### Shared Concerns

- **`TurboBroadcasting`** - Centralizes Turbo Stream broadcasting logic for real-time UI updates

## Job Pattern

All jobs follow this consistent structure:

```ruby
def perform(...)
  setup_job(...)
  start_job_processing
  process_main_logic
  complete_job_processing
rescue StandardError => e
  handle_job_error(e)
  raise
end
```

## Real-time Features

Jobs provide live UI updates through:
- Progress indicators with spinners
- Rate limit countdown timers
- Success/error flash messages
- Dynamic button state management
- Live data table updates

## Error Handling

Standardized error handling includes:
- User-friendly error messages
- Automatic retries with exponential backoff
- Graceful API rate limit handling
- Accessibility announcements

## Testing

Job tests focus on:
- Orchestration logic rather than business logic
- Status management and error handling
- Integration with shared concerns
- Real-time broadcasting behavior

See the [Development Guide](../../docs/development.md) for testing examples and best practices.
