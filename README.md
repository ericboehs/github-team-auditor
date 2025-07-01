# GitHub Team Auditor

A comprehensive web application for auditing GitHub team memberships and access compliance. Built for organizations that need to regularly review and validate team member access, track member activity, and maintain security compliance.

## Overview

GitHub Team Auditor streamlines the process of conducting security audits on GitHub teams by:

- **Automated Team Synchronization** - Pulls team member data directly from GitHub API
- **Interactive Audit Sessions** - Provides guided workflows for reviewing member access
- **Member Activity Tracking** - Correlates GitHub issues with team members to show activity
- **Progress Tracking** - Visual progress indicators and completion statistics
- **Real-time Collaboration** - Multiple auditors can work on the same audit simultaneously
- **Audit Trail** - Complete history of access decisions and notes

## Key Features

### 🔍 **Comprehensive Team Auditing**
- Create audit sessions for any GitHub team
- Review member access with validated/pending/removed status tracking
- Add detailed notes and comments for each member
- Track audit progress with real-time statistics

### 🔄 **Real-time Team Synchronization** 
- Background synchronization of team data from GitHub
- Live UI updates showing sync progress
- Automatic detection of new team members and changes

### 🎯 **Issue Correlation & Activity Tracking**
- Automatically correlates GitHub issues with team members
- Configurable search terms for finding relevant member activity
- Visual indicators showing member engagement and activity levels
- Timeline view of when members were first/last seen in issues

### ⚡ **Modern User Experience**
- Responsive design that works on desktop and mobile
- Dark mode support for comfortable viewing
- Keyboard shortcuts for power users (Ctrl+hjkl navigation, Ctrl+/ for help)
- Real-time updates without page refreshes using Turbo Streams

### 🛡️ **Security & Compliance**
- Secure session-based authentication
- Audit trail of all access decisions
- Export capabilities for compliance reporting
- Role-based access controls

## Use Cases

### Security Audits
- **Quarterly Access Reviews** - Systematically review all team members' continued need for access
- **Onboarding/Offboarding** - Ensure new hires have appropriate access and departing employees are removed
- **Compliance Reporting** - Generate reports showing audit completion and decisions

### Team Management
- **Activity Monitoring** - Identify inactive team members who may no longer need access
- **Access Validation** - Verify that team membership aligns with current roles and responsibilities
- **Team Health** - Get insights into team engagement through issue correlation

### Organizational Oversight
- **Multi-team Audits** - Conduct audits across multiple teams and organizations
- **Progress Tracking** - Monitor audit completion rates across different teams
- **Historical Analysis** - Track access decisions and changes over time

## Tech Stack

- **Rails 8.0.2** with modern asset pipeline (Propsharp)
- **SQLite3** for all environments including production
- **Hotwire** (Turbo + Stimulus) for real-time interactivity
- **Tailwind CSS** for responsive, modern UI design
- **ViewComponent** for maintainable, reusable UI components
- **Solid Libraries** for database-backed cache, queue, and cable

## Getting Started

### Prerequisites

- Ruby 3.2+
- Rails 8.0.2+
- SQLite3
- GitHub Personal Access Token with appropriate permissions

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd github-team-auditor
   ```

2. Install dependencies and set up the database:
   ```bash
   bin/setup
   ```

3. Configure your GitHub API credentials:
   ```bash
   bin/rails credentials:edit
   ```
   
   Add your GitHub configuration:
   ```yaml
   github:
     client_id: your_github_app_client_id
     client_secret: your_github_app_client_secret
     personal_access_token: your_personal_access_token
   ```

4. Start the development server:
   ```bash
   bin/rails server
   ```

5. Visit `http://localhost:3000` and create your first user account

### First Audit Session

1. **Add a Team** - Navigate to Teams and add your GitHub organization/team
2. **Sync Team Data** - Click "Sync GitHub Team" to pull current member data
3. **Create Audit Session** - Start a new audit session for the team
4. **Review Members** - Go through each member and mark them as validated, pending, or removed
5. **Track Progress** - Monitor completion percentage and add notes as needed

## Usage

### Creating an Audit Session

1. Go to **Audits** → **New Audit Session**
2. Select the team you want to audit
3. Give your audit session a descriptive name (e.g., "Q1 2024 Security Review")
4. Set a due date if needed
5. Click **Create Audit Session**

### Conducting the Audit

1. **Review each member** by clicking through the status badges:
   - **Pending** (yellow) → **Validated** (green) → **Removed** (red)
2. **Add notes** for any members requiring explanation
3. **Use keyboard shortcuts** for faster navigation:
   - `Ctrl + h/l` - Navigate left/right between columns
   - `Ctrl + j/k` - Navigate up/down between rows  
   - `Ctrl + /` - Show keyboard shortcuts help
4. **Track progress** using the stats widgets at the top

### Team Management

- **Sync Teams** regularly to get the latest member data from GitHub
- **Find GitHub Issues** to correlate member activity with team membership
- **Monitor job progress** through real-time UI updates

## Development

### Code Quality

Run the full CI pipeline (formatting, linting, security scan, tests):

```bash
bin/ci
```

Auto-fix formatting issues:

```bash
bin/ci --fix
```

Watch CI status in real-time:

```bash
bin/watch-ci
```

### Testing

Run tests:

```bash
bin/rails test
```

Generate coverage report:

```bash
bin/coverage
```

### Code Standards

- **EditorConfig**: UTF-8, LF line endings, 2-space indentation
- **RuboCop**: Rails Omakase configuration  
- **SimpleCov**: 95% minimum coverage requirement
- **Conventional Commits**: Structured commit messages

## Documentation

For detailed technical documentation:

- **[App Components](app/components/README.md)** - ViewComponent architecture and reusable UI components
- **[Background Jobs](app/jobs/README.md)** - Job architecture, real-time updates, and error handling  
- **[Services](app/services/README.md)** - Business logic services and GitHub API integration
- **[Development Guide](docs/development.md)** - Complete development setup and workflow
- **[GitHub API Integration](docs/api_integration.md)** - API client documentation and usage
- **[Real-time Features](docs/real_time_features.md)** - Turbo Streams, ActionCable, and live UI updates

## Contributing

1. Follow the existing code style and conventions
2. Ensure tests pass: `bin/ci`
3. Maintain test coverage above 95%
4. Use conventional commit messages

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).