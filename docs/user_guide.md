# GitHub Team Auditor - User Guide

This guide covers how to use the GitHub Team Auditor application for managing and auditing GitHub team memberships.

## Getting Started

### Dashboard Overview

The dashboard provides a quick overview of your GitHub audit activities:

- **Total Teams**: Number of teams being tracked
- **Total Organizations**: Number of GitHub organizations configured
- **Current Members**: Total active team members across all teams
- **Recent Audits**: Latest audit sessions with their status

### Navigation

- **Dashboard**: Overview and quick access to recent activities
- **Teams**: Manage and view GitHub teams
- **Audits**: Create and manage audit sessions
- **Profile**: User account settings

## Managing Teams

### Viewing Teams

Navigate to **Teams** to see all tracked GitHub teams. Each team shows:

- Team name and organization
- Member count and maintainer count
- Recent audit activity
- Last sync status

### Team Details

Click on any team to view detailed information:

- **Team Statistics**: Total members, maintainers, recent audits
- **Team Members**: Complete list with GitHub profiles and roles
- **Sync Status**: When the team was last synchronized with GitHub

### Adding New Teams

1. Click **"New Team"** from the Teams index
2. Select the organization (defaults to Department of Veterans Affairs)
3. Enter team details:
   - **Name**: Display name for the team
   - **GitHub Slug**: The team's identifier in GitHub (e.g., "platform-security")
   - **Description**: Brief description of the team's purpose
4. Click **"Create Team"**

### Syncing Team Data

Teams can be synchronized with GitHub to update member lists:

1. Go to the team's detail page
2. Click **"Sync from GitHub"**
3. The system will update team members in the background
4. Refresh the page to see updated member counts and sync timestamp

## Audit Sessions

### Creating Audit Sessions

Audit sessions track the validation status of team members for compliance purposes.

1. Navigate to **Audits** and click **"New Audit Session"**
2. Fill in audit details:
   - **Name**: Descriptive name (e.g., "Q1 2025 Platform Security Audit")
   - **Organization**: Select the GitHub organization
   - **Team**: Choose the team to audit
   - **Notes**: Optional notes about the audit purpose
   - **Due Date**: When the audit should be completed
3. Click **"Create Audit Session"**

The system will automatically create audit entries for all current team members.

### Managing Audit Sessions

From the Audits index, you can:

- **View Active Audits**: See audits in progress
- **Filter by Team**: Show audits for specific teams
- **Check Status**: See audit progress and completion status

### Audit Session Details

The audit detail page provides comprehensive information:

#### Audit Statistics
- **Progress**: Percentage of members validated
- **Status**: Draft, Active, or Completed
- **Due Date**: Audit deadline
- **Compliance**: Whether the audit meets requirements

#### Team Members List
For each team member, you can see:
- **GitHub Profile**: Name, username, and avatar
- **Role**: Member or Maintainer status
- **Validation Status**: Whether the member has been validated
- **Notes**: Any audit-specific notes about the member

#### Actions Available
- **Mark Complete/Active**: Toggle the audit status
- **Set Due Date**: Add or update the audit deadline
- **Delete**: Remove the audit session

### Updating Member Status

Within an audit session:

1. Locate the team member in the list
2. Check the validation checkbox if the member has been validated
3. Add notes if needed to document findings
4. The progress percentage updates automatically

### Completing Audits

When all required validations are complete:

1. Go to the audit detail page
2. Click **"Mark Complete"**
3. The audit status changes to "Completed"
4. The completion timestamp is recorded

You can reactivate completed audits by clicking **"Mark Active"**.

## Team Member Management

### Member Information

For each team member, the system tracks:

- **Basic Profile**: Name, GitHub username, avatar
- **GitHub Details**: Company, location, bio (when available)
- **Team Role**: Member or Maintainer
- **Status**: Current or former team member
- **Audit History**: Participation in previous audits

### GitHub Profile Links

Click on member names to visit their GitHub profiles (when available). The system validates GitHub URLs for security.

### Member Status Updates

Team member statuses are updated automatically when teams are synced:

- **Added Members**: New team members are marked as current
- **Removed Members**: Former team members are marked as inactive
- **Role Changes**: Maintainer status is updated based on GitHub data

## Compliance and Reporting

### Progress Tracking

Each audit session shows:
- **Completion Percentage**: How many members have been validated
- **Compliance Status**: Whether minimum validation requirements are met
- **Time Remaining**: Days until the audit due date

### Audit History

View historical audits to track:
- Team composition changes over time
- Compliance trends
- Member validation patterns

## Tips and Best Practices

### Regular Syncing

- Sync teams weekly or before starting new audits
- Monitor the "Teams Needing Sync" section on the dashboard
- Set up regular sync schedules for active teams

### Audit Organization

- Use descriptive names that include time periods (e.g., "Q1 2025")
- Set realistic due dates based on team size
- Add detailed notes about audit requirements or findings

### Team Management

- Keep team descriptions current and informative
- Verify GitHub slugs match actual GitHub team identifiers
- Monitor member count changes for compliance purposes

### Efficient Workflows

1. **Start with Dashboard**: Check for teams needing sync
2. **Sync Teams**: Update team data before creating audits
3. **Create Audits**: Set up audit sessions with clear objectives
4. **Validate Members**: Work through member lists systematically
5. **Document Findings**: Use notes to record validation decisions
6. **Complete Audits**: Mark audits complete when finished

## Troubleshooting

### Team Sync Issues

If team sync fails:
- Verify the GitHub token has proper permissions
- Check that the team slug exactly matches GitHub
- Ensure the organization has access to the team

### Missing Members

If expected members don't appear:
- Confirm they are actual GitHub team members
- Check if they were recently added to the team
- Try syncing the team again

### Audit Problems

If audits don't behave as expected:
- Refresh the page to see latest data
- Check that you have the correct permissions
- Verify the audit status and due dates

## Getting Help

For additional support:
- Check the application logs for error details
- Verify your GitHub token permissions
- Contact your system administrator for access issues

The GitHub Team Auditor is designed to streamline compliance auditing while maintaining accurate team membership records from GitHub.