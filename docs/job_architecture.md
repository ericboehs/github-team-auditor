# Job Architecture Guide

This document explains the background job architecture, including the new refactored job structure and shared concerns.

## Overview

The application uses Rails Active Job with Solid Queue for background processing. Jobs handle GitHub API operations, team synchronization, and issue correlation finding.

## Job Structure

### Core Jobs

**TeamSyncJob** - Synchronizes team member data from GitHub
- Fetches current team members from GitHub API
- Updates team member records in database
- Handles member additions and removals
- Broadcasts real-time updates to UI

**IssueCorrelationFinderJob** - Finds GitHub issues related to team members
- Searches GitHub for issues mentioning team members
- Correlates issues with team members based on configurable search terms
- Updates issue correlation records
- Broadcasts progress and completion status

**MemberEnrichmentJob** - Enriches member profiles with additional data
- Fetches detailed user information from GitHub
- Updates member profile data
- Handles API rate limits gracefully

## Refactored Architecture

### Job Orchestration Pattern

Both major jobs follow a clean orchestration pattern:

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

### Shared Concerns

**TurboBroadcasting** (`app/jobs/concerns/turbo_broadcasting.rb`)
- Centralizes all Turbo Stream broadcasting logic
- Provides consistent error messaging and UI updates
- Handles job start, completion, and error states
- Manages real-time progress updates

Key methods:
- `broadcast_job_started(team, message_key, announcement_key)`
- `broadcast_job_completed(team, message, type: :success)`
- `broadcast_job_error(team, error)`
- `translate_error_message(error)`

### Service Layer

**IssueCorrelationService** (`app/services/issue_correlation_service.rb`)
- Extracts business logic from IssueCorrelationFinderJob
- Handles GitHub issue searching and filtering
- Manages database operations for issue correlations
- Provides clean separation of concerns

Key responsibilities:
- Search query building and sanitization
- Issue filtering based on exclusion terms
- Database upsert operations for correlations
- Real-time UI broadcasting

## Job Flow Examples

### Team Sync Flow

```ruby
# 1. Job Setup
setup_job(team_id)
  └── Load team and create API client

# 2. Start Processing
start_sync_processing
  └── Update job status and broadcast start

# 3. Core Logic
perform_team_sync
  └── Delegate to Github::TeamSyncService

# 4. Completion
complete_sync_processing(results)
  └── Broadcast completion and update UI
  └── Update team stats and member table
```

### Issue Correlation Flow

```ruby
# 1. Job Setup
setup_job(team_id, search_terms, exclusion_terms, repository)
  └── Load team, create API client, set configuration

# 2. Start Processing
start_job_processing
  └── Update job status and broadcast start

# 3. Core Logic
process_correlations
  └── Create IssueCorrelationService
  └── Delegate to find_correlations_for_team

# 4. Completion
complete_job_processing
  └── Count results and broadcast completion
```

## Error Handling

### Standardized Error Broadcasting

All jobs use the shared `broadcast_job_error` method which:
- Translates technical errors to user-friendly messages
- Broadcasts error messages to the UI via Turbo Streams
- Updates job status appropriately
- Provides accessibility announcements

### Error Types

- `Github::ApiClient::ConfigurationError` - GitHub token/permissions issues
- `Octokit::Unauthorized` - Authentication failures  
- `Octokit::TooManyRequests` - Rate limit exceeded
- `Octokit::NetworkError` - Network connectivity issues
- `StandardError` - General unexpected errors

### Retry Strategy

```ruby
retry_on StandardError, wait: :polynomially_longer, attempts: 3
discard_on Github::ApiClient::ConfigurationError
```

Configuration errors are not retried since they require manual intervention.

## Real-time UI Updates

### Broadcasting Targets

Jobs broadcast to multiple UI targets:
- **Status banners** - Show current job progress with spinners
- **Flash messages** - Display completion/error messages
- **Team cards** - Update job status badges on index page
- **Action dropdowns** - Enable/disable buttons based on job state
- **Data tables** - Update team members and issue correlations
- **Live announcements** - Accessibility updates for screen readers

### Turbo Stream Channels

- `team_#{team.id}` - Team-specific updates on show page
- `teams_index` - Updates for team cards on index page

## Configuration

### Team Job Settings

Teams have configurable settings for issue correlation:

```ruby
# Default search configuration
def effective_search_terms
  search_terms.presence || "access"
end

def effective_exclusion_terms  
  exclusion_terms.presence || ""
end

def effective_search_repository
  search_repository.presence || "#{organization.github_login}/va.gov-team"
end
```

### Job Status Management

Simplified status management through generic methods:

```ruby
# Start any job type
team.start_job!(:sync)
team.start_job!(:issue_correlation)

# Complete any job type
team.complete_job!(:sync, completion_field: :sync_completed_at)
team.complete_job!(:issue_correlation, completion_field: :issue_correlation_completed_at)
```

## Testing

### Job Testing Strategy

1. **Unit Tests** - Test individual job methods in isolation
2. **Integration Tests** - Test job flow with mocked external dependencies
3. **Service Tests** - Test extracted service logic separately
4. **Concern Tests** - Test shared broadcasting logic

### Example Job Test

```ruby
test "job processes team and updates status" do
  # Mock external dependencies
  Github::ApiClient.stubs(:new).returns(mock_api_client)
  
  # Mock broadcasting
  job = TeamSyncJob.new
  job.stubs(:broadcast_job_started)
  job.stubs(:broadcast_job_completed)
  
  # Verify status changes
  @team.expects(:start_sync_job!)
  @team.expects(:complete_sync_job!)
  
  job.perform(@team.id)
end
```

## Performance Considerations

### Database Operations

- Use `upsert_all` for efficient bulk updates
- Wrap correlation updates in transactions
- Reload objects only when necessary for broadcasting

### API Rate Limiting

- Jobs respect GitHub API rate limits
- Progress updates include rate limit countdowns
- Exponential backoff for retry scenarios

### UI Responsiveness

- Broadcast progress updates every member (issue correlation)
- Use targeted Turbo Stream updates
- Minimize DOM updates through selective targeting

This architecture provides a maintainable, testable, and user-friendly background job system that gracefully handles errors and provides real-time feedback to users.