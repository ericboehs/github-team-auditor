# Rake Tasks

This directory contains custom rake tasks for managing the GitHub Team Auditor application.

## Available Tasks

### Team Management

#### `teams:clear_failed_jobs`
Clears all teams stuck in failed job states (sync or issue correlation).

```bash
bin/rails teams:clear_failed_jobs
```

**Use when:**
- Teams are stuck showing "failed" status in the UI
- Sync or issue correlation jobs have failed and need to be reset
- You want to allow teams to retry operations

**Output:**
```
Clearing failed job states...
  Clearing failed sync_status for team: Platform Security (ID: 1)
  Clearing failed issue_correlation_status for team: Vets API (ID: 2)
Done! Cleared 2 failed job states.
All teams should be ready for new operations.
```

#### `teams:job_status`
Shows the current job status for all teams with active job states.

```bash
bin/rails teams:job_status
```

**Use when:**
- You want to see which teams have running or failed jobs
- Debugging job state issues
- Getting an overview of system activity

**Output:**
```
Team Job Status Report
==================================================
Department of Veterans Affairs/Platform Security (ID: 1)
  Status: sync: running
Department of Veterans Affairs/Vets API (ID: 2)
  Status: correlation: failed
```

## Adding New Tasks

When creating new rake tasks:

1. **Namespace appropriately** - Group related tasks under meaningful namespaces
2. **Add descriptions** - Use `desc` to provide helpful descriptions
3. **Include error handling** - Wrap operations in begin/rescue blocks
4. **Provide feedback** - Show progress and results to the user
5. **Document here** - Add documentation for new tasks

### Example Task Structure

```ruby
namespace :my_feature do
  desc "Description of what this task does"
  task my_task: :environment do
    puts "Starting task..."
    
    begin
      # Task implementation
      puts "Task completed successfully!"
    rescue => e
      puts "Task failed: #{e.message}"
      exit 1
    end
  end
end
```
