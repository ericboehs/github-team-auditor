# Product Requirements Document: GitHub Team Auditor

## Executive Summary

The GitHub Team Auditor is a Rails 8.0 web application designed to streamline and modernize the process of conducting security audits of GitHub teams and their repository access permissions. This application replaces the existing Sinatra-based `gh-team-audit-ui` with a modern, database-backed Rails application featuring an improved Tailwind CSS interface and enhanced user experience.

## Problem Statement

Organizations, particularly government agencies like the Department of Veterans Affairs, require regular security audits of their GitHub team memberships for compliance purposes (quarterly access reviews for eMASS reporting). The current manual process is time-consuming, error-prone, and lacks proper data persistence and audit trails.

## Product Goals

### Primary Goals
- **Streamline Security Audits**: Reduce time required for quarterly GitHub team access reviews
- **Improve Data Integrity**: Replace CSV-based storage with a robust database backend
- **Enhance User Experience**: Provide a modern, responsive interface with improved usability
- **Ensure Compliance**: Support eMASS reporting requirements and audit trail maintenance
- **Enable Scalability**: Support auditing multiple teams and organizations simultaneously

### Secondary Goals
- **Improve Performance**: Faster data processing and user interactions
- **Better Reporting**: Enhanced export capabilities and audit reports
- **Mobile Support**: Responsive design for various device types
- **API Integration**: Robust GitHub API integration with proper error handling

## Target Users

### Primary Users
- **Platform SRE Teams**: Conduct quarterly security audits
- **Security Engineers**: Perform access reviews and compliance validation
- **Compliance Officers**: Generate reports for eMASS and other compliance frameworks

### Secondary Users
- **Team Managers**: Review and validate team member access
- **Auditors**: External auditors requiring access to audit trails and reports

## Core Features

### 1. GitHub Integration & Data Management

#### 1.1 GitHub API Integration
- **Multi-Organization Support**: Connect to and audit teams across multiple GitHub organizations
- **Team Member Discovery**: Automatically fetch complete team member lists with profile information and avatar images
- **Advanced Issue Correlation**: Search and correlate repository access issues with team members by scanning issue bodies/titles
- **Configurable Issue Search**: Support for custom search terms and exception patterns to filter relevant issues
- **Issue Tracking**: Track multiple issue numbers per member with creation/update timestamps
- **API Pagination**: Handle large datasets with proper GitHub API pagination
- **Rate Limit Management**: Intelligent handling of GitHub API rate limits with automatic backoff and progress indicators
- **Real-time Sync**: Options to refresh team data on demand

#### 1.2 Data Import & Export
- **Bulk Import**: Import team member data from GitHub organizations with environment-based configuration
- **Smart Data Merging**: Merge new API data with existing manual audit changes, preserving human edits
- **Retained Member Handling**: Keep members who were removed from team but need audit retention
- **CSV Export**: Export audit results for compliance reporting
- **Data Migration**: Import existing CSV data from legacy system
- **Click-to-Copy Data**: Easy selection and copying of member names, dates, and other data fields

### 2. Audit Management Interface

#### 2.1 Member Overview Dashboard
- **Comprehensive Table View**: Display team members with:
  - GitHub profile information (avatar with hover zoom, username, real name)
  - Access validation status with toggle switches  
  - Removal status indicators with toggle switches
  - Multiple issue numbers with clickable GitHub links
  - Issue creation/update timestamps (latest from comma-separated values)
  - Audit comments and notes with in-place text editing
  - Real-time member count display with GitHub team links
- **Smart Sorting**: Click-to-sort on all columns with visual indicators (arrows)
  - Chronological sorting for dates
  - Numeric sorting for issue numbers
  - Boolean priority sorting (Yes/No/blank)
- **In-place Editing**: Edit comments and status without page refresh with keyboard shortcuts
- **Batch Operations**: Select multiple members for bulk status updates
- **Visual Indicators**: Color-coded status indicators for quick assessment
- **Filtered vs Total Counts**: Display both filtered and total member counts

#### 2.2 Advanced Filtering & Search
- **Multi-criteria Filtering**: Filter by validation status, removal status, user, issue number, and comments
- **Regex Support**: Full regex pattern support in all search/filter fields for power users
- **URL-based Persistence**: Shareable filtered views via URL parameters
- **Advanced Search**: Support complex queries across all data fields
- **Saved Filters**: Create and save frequently used filter combinations
- **Quick Filters**: One-click filters for common audit scenarios
- **Search History**: Remember recent searches for efficiency
- **Clear All Filters**: Single-click to reset all filters

#### 2.3 Keyboard Navigation
- **Full Keyboard Support**: Navigate entire interface without mouse
- **Vim/Emacs Key Bindings**: Support both Vim and Emacs navigation styles
- **Table Navigation**:
  - Vim-style: Ctrl+H/L (prev/next cell), Ctrl+J/K (prev/next row)
  - Emacs-style: Ctrl+P/N (prev/next row), Ctrl+B/F (prev/next cell)
  - Standard: Tab/Shift+Tab for forward/backward navigation
- **Row Navigation**:
  - Ctrl+A (jump to first cell in row)
  - Ctrl+E (jump to last cell in row)
- **Editing Controls**:
  - Enter (save and move down), Shift+Enter (save and move up)
  - Escape (cancel editing and revert changes)
- **Quick Actions**:
  - / (focus user search field)
  - Ctrl+/ (show/hide keyboard shortcuts modal)
  - Ctrl+T (search GitHub team for selected user with pre-filtering)
- **Customizable Shortcuts**: Allow users to configure additional keyboard shortcuts

### 3. Data Persistence & Audit Trail

#### 3.1 Database Backend
- **SQLite Database**: Replace CSV files with proper database storage
- **Data Versioning**: Maintain complete history of all changes with automatic backup creation
- **Version Management**: Keep last 10 versions automatically with pruning of older versions
- **Audit Logging**: Track all user actions with timestamps and user attribution
- **Data Integrity**: Constraints and validations to ensure data quality
- **Backup Strategy**: Automated database backups with retention policies

#### 3.2 Change Management
- **Version Control**: Track all modifications with full audit trail
- **One-Click Revert**: Revert to any previous version via dropdown selection
- **Non-Destructive Rollback**: Create backup before reverting to preserve current state
- **Version Dropdown**: Real-time dropdown showing all available versions in chronological order
- **Conflict Resolution**: Handle simultaneous edits gracefully
- **Change Notifications**: Alert users to data updates and conflicts
- **Pre-Change Backup**: Automatic backup creation before each data modification

### 4. User Experience Enhancements

#### 4.1 Modern Interface Design
- **Tailwind CSS**: Clean, modern, responsive design
- **Dark Mode**: Optional dark theme for user preference
- **Accessibility**: WCAG 2.1 AA compliance for screen readers and keyboard navigation
- **Mobile Responsive**: Optimized layouts for tablets and mobile devices
- **Progressive Enhancement**: Works without JavaScript for core functionality

#### 4.2 Interactive Features
- **Real-time Updates**: Live updates using Hotwire/Turbo
- **Smart Forms**: Auto-save drafts and validate input
- **Context Menus**: Right-click actions for power users
- **Drag & Drop**: Reorder and organize audit items
- **Tooltips & Help**: Contextual assistance throughout the interface

### 5. Reporting & Analytics

#### 5.1 Compliance Reporting
- **eMASS Export**: Generate compliant reports for security frameworks
- **Custom Reports**: Create tailored reports for different stakeholders
- **Scheduled Reports**: Automated report generation and delivery
- **Report Templates**: Pre-configured formats for common use cases
- **Audit Summaries**: Executive dashboards with key metrics

#### 5.2 Analytics Dashboard
- **Audit Metrics**: Track completion rates, time-to-completion, and user activity
- **Trend Analysis**: Historical data visualization and pattern recognition
- **Performance Metrics**: System usage and efficiency measurements
- **Compliance Tracking**: Monitor adherence to audit requirements

### 6. Configuration & Administration

#### 6.1 Multi-tenant Support
- **Organization Management**: Configure multiple GitHub organizations
- **Team Selection**: Audit specific teams or entire organizations
- **User Permissions**: Role-based access control for different user types
- **Custom Fields**: Configurable fields for organization-specific requirements

#### 6.2 System Configuration
- **Environment Variables**: Support for all legacy environment-based configuration:
  - GH_TOKEN (GitHub personal access token)
  - GH_ORGANIZATION (target GitHub organization)
  - GH_REPOSITORY (repository for issue searches)
  - GH_TEAM (team slug to audit)
  - GH_REPOSITORY_SEARCH (search terms for relevant issues)
  - GH_REPOSITORY_SEARCH_EXCEPT (terms to exclude from results)
  - GH_CSV_NAME (configurable data file name)
- **Environment Management**: Support for development, staging, and production
- **API Configuration**: Flexible GitHub API token and endpoint management
- **Notification Settings**: Configurable alerts and notifications
- **Backup Configuration**: Automated backup schedules and retention policies

## Technical Requirements

### Architecture
- **Rails 8.0**: Modern Rails application with latest features
- **SQLite Database**: Multi-database setup (primary, cache, queue, cable)
- **Hotwire Stack**: Turbo + Stimulus for interactive features
- **Tailwind CSS**: Utility-first styling framework
- **ImportMap**: Modern JavaScript without bundling complexity

### Performance Requirements
- **Response Time**: < 200ms for standard operations
- **Throughput**: Support 100+ concurrent users
- **Data Capacity**: Handle teams with 1000+ members
- **API Efficiency**: Minimize GitHub API calls through intelligent caching

### Security Requirements
- **Authentication**: Secure GitHub token management
- **Authorization**: Role-based access control
- **Data Protection**: Encrypt sensitive data at rest
- **Audit Logging**: Complete audit trail for compliance
- **Session Management**: Secure session handling and timeout

### Scalability Requirements
- **Horizontal Scaling**: Support multiple application instances
- **Database Scaling**: Efficient queries and indexing
- **Caching Strategy**: Multi-level caching for performance
- **Background Processing**: Async operations for data-intensive tasks

## Success Metrics

### User Experience Metrics
- **Time to Complete Audit**: Reduce by 50% compared to legacy system
- **User Satisfaction**: 90%+ satisfaction rating from audit teams
- **Error Rate**: < 1% data entry errors
- **Adoption Rate**: 100% migration from legacy system within 6 months

### Technical Metrics
- **System Uptime**: 99.9% availability
- **Response Time**: 95% of requests under 200ms
- **Data Accuracy**: 99.9% data integrity maintenance
- **API Efficiency**: 80% reduction in GitHub API calls through optimization

### Business Metrics
- **Compliance Achievement**: 100% on-time quarterly audit completion
- **Cost Reduction**: 60% reduction in audit-related labor costs
- **Audit Quality**: Improved audit trail completeness and accuracy
- **Process Efficiency**: Streamlined workflow reducing manual steps by 70%

## Timeline & Milestones

### Phase 1: Foundation (Weeks 1-4)
- [ ] Core Rails application setup
- [ ] Database schema design and migration
- [ ] Basic GitHub API integration
- [ ] User authentication and authorization

### Phase 2: Core Features (Weeks 5-8)
- [ ] Team member import and management
- [ ] Basic audit interface with table view
- [ ] In-place editing and status updates
- [ ] Search and filtering functionality

### Phase 3: Advanced Features (Weeks 9-12)
- [ ] Keyboard navigation system
- [ ] Advanced filtering and search
- [ ] Audit trail and versioning
- [ ] Export and reporting capabilities

### Phase 4: Polish & Launch (Weeks 13-16)
- [ ] UI/UX refinements and accessibility
- [ ] Performance optimization
- [ ] Comprehensive testing and QA
- [ ] Documentation and training materials
- [ ] Production deployment and monitoring

## Risk Assessment

### Technical Risks
- **GitHub API Changes**: Mitigation through versioned API usage and monitoring
- **Data Migration**: Thorough testing with production data backups
- **Performance Issues**: Load testing and optimization during development
- **Browser Compatibility**: Cross-browser testing and progressive enhancement

### Business Risks
- **User Adoption**: Comprehensive training and gradual migration strategy
- **Compliance Requirements**: Early validation with compliance teams
- **Timeline Pressure**: Agile development with MVP approach
- **Resource Availability**: Cross-training and documentation for continuity

## Future Enhancements

### Short-term (6 months)
- **Mobile App**: Native mobile application for on-the-go audits
- **Advanced Analytics**: Machine learning for audit pattern recognition
- **Integration APIs**: Connect with other security tools and workflows
- **Bulk Operations**: Enhanced batch processing capabilities

### Long-term (12+ months)
- **Multi-platform Support**: Extend beyond GitHub to GitLab, Bitbucket
- **Automated Compliance**: AI-powered compliance checking and recommendations
- **Enterprise Features**: Advanced admin controls and multi-tenant improvements
- **Workflow Automation**: Automated audit scheduling and notifications

## Conclusion

The GitHub Team Auditor represents a significant modernization of the organization's security audit capabilities. By replacing the legacy CSV-based system with a modern Rails application, we will deliver improved user experience, better data integrity, and enhanced compliance capabilities while reducing the time and effort required for critical security audits.

The success of this project will directly impact the organization's ability to maintain security compliance efficiently and effectively, supporting both operational requirements and regulatory obligations.