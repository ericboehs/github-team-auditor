# Real-time Features Guide

This document explains the real-time UI features implemented using Turbo Streams, ActionCable, and Stimulus controllers.

## Overview

The application provides real-time updates for background job progress, team synchronization, and issue correlation finding. Users receive immediate feedback without page refreshes.

## Technical Architecture

### Core Technologies

- **Turbo Streams** - Server-driven DOM updates over WebSockets
- **ActionCable** - WebSocket connections for real-time communication
- **Stimulus Controllers** - Client-side JavaScript for interactive components
- **Shared Broadcasting Concern** - Centralized broadcasting logic

### Broadcasting Channels

**Team-specific Channel** (`team_#{team.id}`)
- Job progress updates
- Completion notifications
- Error messages
- Data table updates

**Global Index Channel** (`teams_index`)
- Team card status updates
- Job status badges

**Audit Session Updates**
- Member status changes (pending/validated/removed)
- Real-time progress statistics updates
- Audit table refreshes without page reloads

## Real-time Components

### 1. Job Progress Indicators

**Status Banner** (`shared/_status_banner.html.erb`)
```erb
<div id="status-banner-container" 
     class="fixed top-16 left-0 right-0 z-40 px-4 sm:px-6 lg:px-8">
  <!-- Dynamically updated content -->
</div>
```

Features:
- Animated spinner during processing
- Progress messages with member names
- Rate limit countdown when GitHub API is throttled
- Accessibility announcements for screen readers

**Team Card Badges**
- "Syncing" badge during team sync
- "Finding Issues" badge during correlation
- Color-coded status indicators

### 2. Interactive Dropdown Components

**Team Actions Dropdown** (`_team_actions_dropdown.html.erb`)
- Dynamically enables/disables actions based on job status
- Prevents concurrent job execution
- Provides contextual action options

**Due Date Dropdown** (`due_date_dropdown_component.rb`)
- Inline date selection with real-time form submission
- Responsive design for mobile/desktop
- Stimulus controller for interaction handling

### 3. Live Data Updates

**Team Members Table**
- Real-time updates as sync completes
- New members appear immediately
- Member status changes reflect instantly

**Issue Correlations**
- Live updates as issues are found for each member
- Progress tracking through team member list
- Issue counts update in real-time

## Broadcasting Implementation

### Shared Broadcasting Concern

```ruby
# app/jobs/concerns/turbo_broadcasting.rb
module TurboBroadcasting
  def broadcast_job_started(team, message_key, announcement_key)
    broadcast_status_banner(team, I18n.t(message_key), :info, spinner: true)
    broadcast_live_announcement(team, I18n.t(announcement_key, team_name: team.name))
    broadcast_team_card_update(team)
  end

  def broadcast_job_completed(team, message, type: :success)
    broadcast_flash_message(team, message, type)
    broadcast_clear_status_banner(team)
    broadcast_dropdown_update(team)
    broadcast_team_card_update(team)
  end
end
```

### Turbo Stream Targets

**Primary Targets:**
- `status-banner-container` - Job progress indicators
- `flash-messages` - Success/error notifications
- `team-actions-dropdown` - Action button states
- `team-card-#{team.id}` - Team status on index page
- `member-issues-#{member.id}` - Individual member issue counts
- `live-announcements` - Screen reader notifications

## Stimulus Controllers

### 1. Dropdown Controller

```javascript
// app/javascript/controllers/dropdown_controller.js
export default class extends Controller {
  static targets = ["menu", "button"]
  
  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }
  
  closeAction() {
    this.close()
  }
  
  clearFlashMessages() {
    // Clear existing flash messages before action
    document.querySelectorAll('[data-flash-message]').forEach(el => el.remove())
  }
}
```

Features:
- Keyboard navigation (arrow keys, escape)
- Click outside to close
- Accessibility attributes (ARIA)
- Focus management
- Flash message clearing for sync actions

### 2. Alert Controller

```javascript
// app/javascript/controllers/alert_controller.js  
export default class extends Controller {
  connect() {
    this.scheduleRemoval()
  }
  
  close() {
    this.element.remove()
  }
  
  scheduleRemoval() {
    setTimeout(() => this.close(), 5000)
  }
}
```

Auto-dismissing alerts for better UX.

### 3. Issue List Controller

Manages dynamic issue correlation displays with real-time updates.

## User Experience Features

### 1. Progress Feedback

**Visual Indicators:**
- Animated spinners during processing
- Progress counters (e.g., "Processing member 3 of 15")
- Color-coded status badges

**Rate Limit Handling:**
- Countdown timers when GitHub API is throttled
- User-friendly messaging explaining delays
- Automatic resumption when limits reset

### 2. Error Handling

**Graceful Error Display:**
- User-friendly error messages (not technical stack traces)
- Contextual error information
- Recovery suggestions when possible

**Error Translation:**
```ruby
def translate_error_message(error)
  case error.class.name
  when "Github::ApiClient::ConfigurationError"
    I18n.t("jobs.shared.errors.configuration")
  when "Octokit::Unauthorized"  
    I18n.t("jobs.shared.errors.unauthorized")
  # ... more error types
  end
end
```

### 3. Accessibility

**Screen Reader Support:**
- Live announcements for job progress
- ARIA labels on interactive elements
- Semantic HTML structure
- Focus management in dropdowns

**Keyboard Navigation:**
- Arrow keys for dropdown navigation
- Escape key to close modals/dropdowns
- Tab order management

## Implementation Examples

### 1. Adding Real-time Updates to New Jobs

```ruby
class MyCustomJob < ApplicationJob
  include TurboBroadcasting
  
  def perform(team_id)
    @team = Team.find(team_id)
    
    # Start with real-time feedback
    broadcast_job_started(@team, "jobs.my_custom.starting", "jobs.my_custom.started_announcement")
    
    # Do work...
    process_data
    
    # Complete with success message
    message = I18n.t("jobs.my_custom.completed_success")
    broadcast_job_completed(@team, message)
  rescue StandardError => e
    # Handle errors with user feedback
    broadcast_job_error(@team, e)
    raise
  end
end
```

### 2. Custom Turbo Stream Updates

```ruby
# Update specific UI components
Turbo::StreamsChannel.broadcast_replace_to(
  "team_#{team.id}",
  target: "custom-component-#{record.id}",
  partial: "teams/custom_component",
  locals: { record: record, team: team }
)
```

### 3. Adding New Interactive Components

```erb
<!-- Component with Stimulus controller -->
<div data-controller="my-component"
     data-my-component-target="container">
  <!-- Interactive content -->
</div>
```

## Architecture Decisions

### Turbo Streams vs Turbo Frames

**Audit Session Implementation:**

The audit session interface uses **Turbo Streams** instead of Turbo Frames for real-time updates:

```erb
<!-- Before: Turbo Frames (caused conflicts) -->
<%= turbo_frame_tag "audit-stats" do %>
  <!-- Content -->
<% end %>

<!-- After: Regular divs with IDs for Turbo Streams -->
<div id="audit-stats">
  <!-- Content -->
</div>
```

**Why this change was necessary:**

- **Turbo Frames** expect frame-based navigation and updates
- **Turbo Streams** allow multiple simultaneous DOM updates
- Mixing frames and streams can cause update conflicts
- Regular divs with IDs work better for multi-target updates

**Controller Implementation:**

```ruby
# Audit members controller sends turbo streams
respond_to do |format|
  format.turbo_stream do
    render turbo_stream: [
      turbo_stream.replace("sortable-table", partial: "audits/team_members_table"),
      turbo_stream.replace("audit-stats", partial: "audits/audit_stats", locals: {...})
    ]
  end
end
```

**JavaScript Event Handling:**

```javascript
// Status toggle controller listens for turbo stream events
document.addEventListener('turbo:before-stream-render', (event) => {
  // Handle post-update logic like keyboard navigation
});
```

## Best Practices

### 1. Broadcasting Performance

- Use targeted updates instead of full page renders
- Batch related updates when possible
- Avoid excessive broadcasting frequency

### 2. Error Handling

- Always provide user-friendly error messages
- Include recovery instructions when possible
- Log technical details separately for debugging

### 3. Accessibility

- Always include ARIA labels for dynamic content
- Provide text alternatives for visual indicators
- Test with screen readers

### 4. Mobile Considerations

- Ensure real-time updates work on mobile
- Consider reduced motion preferences
- Optimize for touch interactions

## Testing Real-time Features

### System Tests

```ruby
test "user sees real-time sync progress" do
  visit team_path(@team)
  
  # Start sync job
  click_button "Sync Team"
  
  # Verify progress indicator appears
  assert_selector "[data-testid='status-banner']", text: "Syncing"
  
  # Wait for completion
  assert_selector ".alert-success", text: "completed successfully"
end
```

### JavaScript Testing

```ruby
test "dropdown closes on escape key" do
  visit team_path(@team)
  
  # Open dropdown
  click_button "Actions"
  assert_selector "[data-dropdown-target='menu']:not(.hidden)"
  
  # Press escape
  page.driver.browser.action.send_keys(:escape).perform
  
  # Verify dropdown closes
  assert_selector "[data-dropdown-target='menu'].hidden"
end
```

## Monitoring and Debugging

### Development Tools

- Use browser DevTools to monitor WebSocket connections
- Check Rails logs for broadcasting activity
- Use Turbo Stream inspector for debugging updates

### Production Monitoring

- Monitor ActionCable connection health
- Track broadcasting performance metrics
- Alert on WebSocket connection failures

This real-time feature set provides users with immediate feedback and creates a responsive, modern web application experience.