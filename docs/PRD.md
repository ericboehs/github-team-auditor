# Product Requirements Document (PRD)
# GitHub Team Auditor

**Version**: 0.5  
**Date**: June 2025  
**Status**: In Development  

## Executive Summary

GitHub Team Auditor is a Rails application designed to audit GitHub team members and their repository access permissions. It provides a comprehensive web-based interface for managing team access reviews, tracking validation status, and maintaining audit documentation for compliance and security purposes.

## Project Background

This Rails application is a modernization of an existing Sinatra-based GitHub Team Auditor tool, bringing enhanced security, scalability, and user experience to GitHub team access management workflows. The application is specifically designed to support organizations like the Department of Veterans Affairs (VA) in conducting periodic security access reviews as required by compliance frameworks.

### Compliance Context

The application addresses the need for systematic access reviews mandated by security frameworks such as eMASS (Enterprise Mission Assurance Support Service). Organizations must regularly validate user access to systems and applications, ensuring:

- Only authorized personnel maintain system access
- Administrative roles have appropriate government employee representation
- Each system maintains at least two administrators for operational continuity
- Access changes are properly documented and tracked over time
- Results are provided to security teams for formal compliance documentation

### VA.gov Use Case

The GitHub Team Auditor specifically supports VA.gov Platform Security teams in conducting quarterly access reviews across multiple systems including GitHub teams, Sidekiq, VetsAPI, Argo, and other critical infrastructure components. These reviews are part of OCTO-DE (Office of the Chief Technology Officer - Digital Experience) security processes.

## Core Features

### 1. GitHub Integration & Data Management

#### Team Member Discovery
- **GitHub API Integration** - Connects to GitHub organizations and teams via API
- **Team Member Enumeration** - Fetches complete team member lists with profile data
- **Organization Scope** - Configurable organization and team targeting
- **Rate Limit Handling** - Intelligent API rate limiting with automatic delays
- **Pagination Support** - Handles large teams with paginated data retrieval

#### Issue Correlation System
- **Access Request Tracking** - Automatically correlates team members with repository access issues
- **Configurable Search** - Customizable search terms and exclusion patterns
- **Issue Linking** - Direct integration with GitHub issue tracking
- **Historical Context** - Maintains audit trail of access decisions

### 2. Interactive Audit Interface

#### Advanced Data Table
- **Sortable Columns** - Multi-column sorting by username, name, validation status, dates
- **Visual Indicators** - Status icons, GitHub avatars, and clear visual feedback
- **Responsive Design** - Mobile-friendly interface adapting to all screen sizes
- **Real-time Updates** - Live data updates without page refreshes

#### Comprehensive Filtering System
- **User Search** - Text and regex-based username filtering
- **Status Filtering** - Filter by validation status (Validated/Pending/All)
- **Removal Tracking** - Filter members marked for access removal
- **Issue Number Search** - Find members by associated issue numbers
- **Comment Search** - Full-text search within audit comments
- **Combined Filters** - Multiple simultaneous filter criteria
- **URL Persistence** - Shareable URLs maintaining filter state

#### In-Place Editing
- **Toggle Controls** - Visual switches for validation and removal status
- **Inline Text Editing** - Direct editing of comments and notes
- **Keyboard Navigation** - Full keyboard accessibility and shortcuts
- **Auto-save** - Immediate persistence of changes
- **Conflict Resolution** - Handles concurrent editing scenarios

### 3. Advanced Keyboard Navigation

#### Table Navigation Shortcuts
- **Ctrl+H/L** - Horizontal cell navigation
- **Ctrl+J/K** - Vertical row navigation  
- **Ctrl+A/E** - Jump to row start/end
- **Tab/Shift+Tab** - Field navigation
- **Row Selection** - Visual highlighting of current position

#### Editing Shortcuts
- **Enter/Shift+Enter** - Save and navigate to next/previous field
- **Escape** - Cancel editing without saving
- **/** - Focus search box
- **Ctrl+/** - Show keyboard shortcuts help modal
- **Ctrl+T** - Search GitHub team for current user

### 4. Data Management & Versioning

#### Version Control System
- **Automatic Versioning** - Maintains up to 10 backup versions of audit data
- **Version Dropdown** - User interface for browsing and reverting to previous versions
- **Smart Merging** - Preserves manual edits when importing fresh team data
- **Conflict Resolution** - Intelligent handling of data conflicts during updates
- **Audit Trail** - Complete history of changes and decisions

#### Data Import/Export
- **CSV-Based Storage** - Structured data storage with full audit information
- **GitHub Synchronization** - Regular updates from GitHub team membership
- **Data Preservation** - Maintains manual annotations during automated updates
- **Export Capabilities** - Generate reports and data exports for compliance

### 5. Security & Authentication

#### User Authentication System
- **Secure Login** - Email/password authentication with BCrypt hashing
- **Session Management** - Secure session handling with CSRF protection
- **Password Reset** - Email-based password recovery system
- **User Profiles** - Profile management with Gravatar integration
- **Access Control** - Role-based access to audit functions

#### Security Features
- **GitHub Token Management** - Secure storage and handling of API credentials
- **Input Validation** - Comprehensive validation at all data entry points
- **Security Scanning** - Integrated Brakeman security analysis
- **HTTPS Enforcement** - Secure communication protocols
- **Audit Logging** - Comprehensive logging of all audit activities

## Technical Architecture

### Modern Rails Foundation
- **Rails 8.0.2** - Latest Rails framework with modern conventions
- **Solid Libraries** - Database-backed cache, queue, and cable systems
- **SQLite3 Multi-Database** - Separate databases for primary, cache, queue, cable
- **ViewComponent Architecture** - Reusable UI components for maintainability
- **Hotwire Integration** - Turbo and Stimulus for interactive features

### Frontend Technologies
- **Tailwind CSS** - Utility-first styling framework with dark mode support
- **Alpine.js** - Lightweight JavaScript framework for interactivity
- **ImportMap** - Modern JavaScript imports without build steps
- **Responsive Design** - Mobile-first approach with adaptive layouts

### Data & Integration Layer
- **GitHub API Client** - Custom HTTP client with rate limiting and error handling
- **CSV Processing** - Ruby-based data manipulation and versioning
- **File System Management** - Automated backup and version control
- **RESTful APIs** - Clean API design for frontend interactions

## Quality Assurance

### Testing Framework
- **99%+ Test Coverage** - Comprehensive test suite with SimpleCov
- **Multi-Level Testing** - Unit, integration, system, and component tests
- **Parallel Execution** - Optimized test performance
- **CI/CD Pipeline** - Automated testing and quality enforcement

### Code Quality Standards
- **RuboCop Compliance** - Rails Omakase style guide enforcement
- **Security Scanning** - Zero-vulnerability requirement with Brakeman
- **EditorConfig** - Consistent code formatting across development environments
- **Pre-commit Hooks** - Quality gates preventing substandard commits

## Deployment & Operations

### Infrastructure
- **Kamal Deployment** - Rails' modern deployment tool
- **Docker Containerization** - Consistent deployment environments
- **SQLite3 Production** - Simplified database management without external dependencies
- **Zero-Downtime Deployments** - Rolling updates with health checks

### Monitoring & Maintenance
- **Application Logging** - Comprehensive audit and error logging
- **Performance Monitoring** - Response time and resource utilization tracking
- **Automated Backups** - Data versioning and recovery capabilities
- **Health Checks** - System monitoring and alerting

## User Workflows

### Initial Setup Workflow
1. **Environment Configuration** - Set GitHub API tokens and organization settings
2. **Team Data Import** - Initial fetch of team members and associated issues
3. **Interface Access** - Secure login to audit dashboard
4. **Baseline Establishment** - Initial audit state creation

### Ongoing Audit Workflow
1. **Team Review** - Filter and sort team members for systematic review
2. **Access Validation** - Mark each member's access as validated or requiring action
3. **Administrative Verification** - Ensure at least two administrators per system
4. **Government Employee Check** - Verify government employee admin representation
5. **Removal Tracking** - Identify members who should lose access
6. **Documentation** - Add comments and context for audit decisions
7. **Progress Monitoring** - Track completion status across the team
8. **Compliance Reporting** - Generate reports for Platform Security and eMASS documentation

### Update & Synchronization Workflow
1. **Fresh Data Import** - Fetch updated team membership from GitHub
2. **Smart Merge** - Combine new data with existing audit annotations
3. **Change Review** - Identify and review membership changes
4. **Audit Continuation** - Resume audit process with updated information

## Future Roadmap

### Phase 1: Core Implementation (Current)
- Complete Rails application foundation
- GitHub integration and data management
- Interactive audit interface
- User authentication system

### Phase 2: Enhanced Features
- Advanced reporting and analytics
- Bulk operations and batch processing
- eMASS integration for automated compliance reporting
- Multi-system audit support (Sidekiq, VetsAPI, Argo, etc.)
- Administrative role verification workflows
- Government employee tracking and validation

### Phase 3: Enterprise Features
- Multi-organization support
- Advanced role-based access control
- API for external integrations
- Automated audit workflows

## Success Metrics

### Operational Metrics
- **Audit Completion Time** - Reduce time to complete team audits by 75%
- **Data Accuracy** - Maintain 99%+ accuracy in team member validation
- **User Adoption** - 100% adoption by security teams within 6 months
- **Compliance** - Meet all organizational access control requirements

### Technical Metrics
- **System Uptime** - 99.9% availability target
- **Response Time** - Sub-second response for all operations
- **Test Coverage** - Maintain 95%+ code coverage
- **Security** - Zero critical vulnerabilities

## Conclusion

The GitHub Team Auditor represents a significant modernization of team access management, bringing enterprise-grade security, usability, and scalability to critical compliance workflows. The Rails foundation provides robust security and maintainability while the comprehensive feature set addresses all aspects of GitHub team auditing from data import through compliance reporting.
