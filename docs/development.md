# Development Guide

This guide covers setting up and contributing to the GitHub Team Auditor application.

## Development Setup

### Prerequisites

- Ruby 3.2+ 
- Rails 8.0.2
- SQLite3
- Git
- GitHub Personal Access Token (for API integration)

### Initial Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-org/github-team-auditor.git
   cd github-team-auditor
   ```

2. **Install dependencies**:
   ```bash
   bin/setup
   ```
   This will:
   - Install gems
   - Setup databases
   - Run migrations
   - Seed initial data

3. **Configure GitHub API access**:
   ```bash
   # Set your GitHub token for development
   export GHTA_GITHUB_TOKEN=ghp_your_development_token_here
   
   # Or add to .env (not committed)
   echo "GHTA_GITHUB_TOKEN=ghp_your_token_here" >> .env.local
   ```

4. **Start the development server**:
   ```bash
   bin/rails server
   ```

5. **Visit the application**:
   Open http://localhost:3000

## Development Workflow

### Code Quality Pipeline

The project uses a comprehensive CI pipeline that you can run locally:

```bash
# Run full CI pipeline
bin/ci

# Auto-fix formatting issues first
bin/ci --fix

# Individual quality tools
rubocop                    # Ruby style checking
rubocop -A                # Auto-fix Ruby style violations
brakeman                  # Security vulnerability scanning
npx eclint check          # EditorConfig compliance
npx eclint fix            # Auto-fix EditorConfig violations
```

### Testing

```bash
# Run all tests
bin/rails test

# Run specific test types
bin/rails test:system     # System/integration tests
bin/rails test test/models/  # Model tests only

# Run with coverage
bin/coverage
```

### Development Commands

```bash
# Watch CI status during development
bin/watch-ci

# Generate coverage report
bin/coverage

# Rails console
bin/rails console

# Database operations
bin/rails db:migrate
bin/rails db:reset
bin/rails db:seed
```

## Architecture Overview

### Application Structure

```
app/
├── components/          # ViewComponents for reusable UI
│   ├── auth/           # Authentication-related components
│   ├── form/           # Form components
│   └── concerns/       # Shared component logic
├── controllers/        # Rails controllers
├── helpers/           # View helpers
├── javascript/        # Stimulus controllers
├── jobs/             # Background jobs (Solid Queue)
├── models/           # ActiveRecord models
├── services/         # Business logic services
│   └── github/       # GitHub API integration
└── views/            # ERB templates
```

### Key Components

**Models**:
- `Organization` - GitHub organizations
- `Team` - GitHub teams within organizations  
- `TeamMember` - Current and historical team members
- `AuditSession` - Compliance audit sessions
- `AuditMember` - Member validation status in audits
- `AuditNote` - Notes and findings for audit members

**Services**:
- `Github::ApiClient` - GitHub API client with rate limiting
- `Github::TeamSyncService` - High-level team synchronization
- `IssueCorrelationService` - Business logic for issue correlation finding

**Jobs**:
- `TeamSyncJob` - Background team data synchronization with integrated member enrichment via GraphQL
- `IssueCorrelationFinderJob` - Background issue correlation finding with GraphQL batch processing and real-time UI updates

**Job Concerns**:
- `TurboBroadcasting` - Shared concern for real-time UI updates and error handling

**Components**:
- `Auth::*` - Form components for authentication
- `Form::*` - Reusable form components
- `UserPageComponent` - Page layout wrapper

## Database Design

### Multi-Database Setup

The application uses separate SQLite databases:

```yaml
# config/database.yml
production:
  primary:
    database: storage/production.sqlite3
  cache:
    database: storage/production_cache.sqlite3
    migrations_paths: db/cache_migrate
  queue:
    database: storage/production_queue.sqlite3
    migrations_paths: db/queue_migrate
  cable:
    database: storage/production_cable.sqlite3
    migrations_paths: db/cable_migrate
```

### Key Relationships

```ruby
Organization
├── has_many :teams
└── has_many :audit_sessions

Team  
├── belongs_to :organization
├── has_many :team_members
└── has_many :audit_sessions

AuditSession
├── belongs_to :organization
├── belongs_to :team
├── belongs_to :user
└── has_many :audit_members

AuditMember
├── belongs_to :audit_session
└── has_many :audit_notes
```

## GitHub API Integration

### Client Configuration

```ruby
# Initialize API client
organization = Organization.find_by(github_login: "department-of-veterans-affairs")
client = Github::ApiClient.new(organization)

# The client automatically handles:
# - Rate limiting with exponential backoff
# - Authentication with provided token
# - Error handling and retries
```

### Rate Limiting Strategy

The API client implements sophisticated rate limiting:

```ruby
# Rate limit thresholds (configurable)
CRITICAL_RATE_LIMIT_THRESHOLD = 50    # Requests remaining
WARNING_RATE_LIMIT_THRESHOLD = 200    # Requests remaining
DEFAULT_RATE_LIMIT_DELAY = 0.1        # Seconds between requests
MIN_CRITICAL_DELAY = 1.0              # Minimum delay when critical
```

### Common API Operations

```ruby
# Fetch team members (with pagination)
members = client.fetch_team_members("platform-security")

# Get team information
team_data = client.fetch_team_by_slug("platform-security")

# Enrich user profiles
user_data = client.user_details("username")

# Search for issues
issues = client.search_issues("security vulnerability", repository: "org/repo")
```

## Testing Strategy

### Test Organization

```
test/
├── components/         # ViewComponent tests
├── controllers/        # Controller integration tests
├── fixtures/          # Test data
├── helpers/           # Helper method tests
├── jobs/              # Background job tests
├── models/            # Model unit tests
├── services/          # Service object tests
└── system/            # End-to-end system tests
```

### Test Categories

**Unit Tests**: Fast, isolated tests for models and services
```ruby
# test/models/team_test.rb
test "should calculate member count correctly" do
  assert_equal 5, @team.total_members_count
end
```

**Integration Tests**: Controller and helper tests
```ruby
# test/controllers/audits_controller_test.rb  
test "should create audit session" do
  assert_difference("AuditSession.count") do
    post audits_url, params: { audit_session: valid_params }
  end
end
```

**System Tests**: Full browser automation with Capybara
```ruby
# test/system/audit_workflow_test.rb
test "user can create and view audit session" do
  visit new_audit_path
  fill_in "Name", with: "Test Audit"
  click_button "Create Audit Session"
  assert_text "Test Audit"
end
```

### Testing Best Practices

1. **Mock External APIs**: Use fixtures for GitHub API responses
2. **Test Error Scenarios**: Verify graceful error handling
3. **Maintain High Coverage**: Target 95%+ line and branch coverage
4. **Use Descriptive Names**: Test names should explain the scenario
5. **Test Edge Cases**: Handle nil values, empty arrays, etc.

### Running Specific Tests

```bash
# Single test file
bin/rails test test/models/team_test.rb

# Single test method
bin/rails test test/models/team_test.rb::test_should_calculate_member_count

# Tests matching pattern
bin/rails test -n "/audit/"

# System tests only
bin/rails test:system

# With coverage
bin/coverage
```

## ViewComponents Development

### Component Structure

```ruby
# app/components/auth/button_component.rb
class Auth::ButtonComponent < ViewComponent::Base
  def initialize(text:, variant: :primary, **options)
    @text = text
    @variant = variant
    @options = options
  end

  private

  attr_reader :text, :variant, :options

  def button_classes
    base_classes = "btn"
    variant_class = "btn-#{variant}"
    "#{base_classes} #{variant_class}"
  end
end
```

```erb
<!-- app/components/auth/button_component.html.erb -->
<button class="<%= button_classes %>" <%= options %>>
  <%= text %>
</button>
```

### Component Testing

```ruby
# test/components/auth/button_component_test.rb
class Auth::ButtonComponentTest < ViewComponent::TestCase
  test "renders button with text" do
    render_inline Auth::ButtonComponent.new(text: "Click me")
    
    assert_selector "button", text: "Click me"
    assert_selector "button.btn.btn-primary"
  end
end
```

### Component Previews

```ruby
# test/components/previews/auth/button_component_preview.rb
class Auth::ButtonComponentPreview < ViewComponent::Preview
  def default
    render Auth::ButtonComponent.new(text: "Default Button")
  end

  def variants
    render_with_template
  end
end
```

Visit `/rails/view_components` in development to see component previews.

## Background Jobs

### Job Development

```ruby
# app/jobs/team_sync_job.rb
class TeamSyncJob < ApplicationJob
  queue_as :default
  
  def perform(team_id)
    team = Team.find(team_id)
    Github::TeamSyncService.new(team).sync!
  rescue Github::ApiClient::ConfigurationError => e
    # Handle API configuration errors
    Rails.logger.error "GitHub API configuration error: #{e.message}"
  end
end
```

### Job Testing

```ruby
# test/jobs/team_sync_job_test.rb
class TeamSyncJobTest < ActiveJob::TestCase
  test "should sync team successfully" do
    assert_enqueued_jobs 1 do
      TeamSyncJob.perform_later(@team.id)
    end
  end
  
  test "should handle API errors gracefully" do
    # Mock API error and verify handling
  end
end
```

### Local Job Processing

```bash
# Start job processing in development
bin/rails solid_queue:start

# Or run jobs inline for testing
Rails.application.config.active_job.queue_adapter = :inline
```

## JavaScript Development

### Stimulus Controllers

```javascript
// app/javascript/controllers/audit_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["organizationSelect", "teamSelect"]
  static values = { teams: Object }

  organizationChanged() {
    const orgId = this.organizationSelectTarget.value
    this.updateTeams(orgId)
  }

  updateTeams(organizationId) {
    // Update team options based on organization
  }
}
```

### Testing JavaScript

```ruby
# test/system/audit_workflow_test.rb
test "team selection updates when organization changes" do
  visit new_audit_path
  
  select "Department of Veterans Affairs", from: "Organization"
  
  # Verify teams are loaded
  assert_selector "select#audit_session_team_id option", text: "Platform Security"
end
```

## Development Tips

### Debugging

```ruby
# Use Rails console for debugging
bin/rails console

# Debug API interactions
organization = Organization.first
client = Github::ApiClient.new(organization)
client.fetch_team_members("platform-security")

# Check background jobs
SolidQueue::Job.where(class_name: "TeamSyncJob").recent

# Debug ViewComponents
render_inline(Auth::ButtonComponent.new(text: "Test"))
```

### Performance

```ruby
# Use includes to avoid N+1 queries
@audit_sessions = AuditSession.includes(:organization, :team, :user)

# Monitor SQL queries in development
Rails.logger.level = :debug

# Profile slow operations
result = Benchmark.measure do
  # Your slow code here
end
```

### Code Style

The project follows Rails Omakase style guidelines:

```ruby
# Good: Use Rails conventions
class AuditSession < ApplicationRecord
  belongs_to :team
  has_many :audit_members, dependent: :destroy
  
  scope :recent, -> { order(created_at: :desc) }
  
  def progress_percentage
    # Implementation
  end
end

# Good: Descriptive method names
def compliance_ready?
  validated_members_count >= minimum_required_validations
end
```

## Contributing

### Git Workflow

1. **Create feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make changes with tests**:
   - Write failing tests first
   - Implement the feature
   - Ensure tests pass
   - Run code quality checks

3. **Commit with conventional messages**:
   ```bash
   git commit -m "feat: add team member validation workflow"
   git commit -m "fix: handle GitHub API rate limiting gracefully"
   git commit -m "docs: update API integration guide"
   ```

4. **Push and create PR**:
   ```bash
   git push -u origin feature/your-feature-name
   gh pr create --title "feat: your feature description"
   ```

### Code Review Checklist

- [ ] Tests added for new functionality
- [ ] Existing tests still pass
- [ ] Code follows style guidelines
- [ ] Security considerations addressed
- [ ] Documentation updated if needed
- [ ] No sensitive data in commits

### Release Process

1. Update version in appropriate files
2. Run full test suite and CI checks
3. Create release notes
4. Tag the release
5. Deploy to staging for verification
6. Deploy to production

This development guide ensures consistent, high-quality contributions to the GitHub Team Auditor application.