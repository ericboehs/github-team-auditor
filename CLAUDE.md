# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Rails 8.0.2 application called **GitHub Team Auditor** (`GithubTeamAuditor` module) built for auditing GitHub teams. The application uses modern Rails features including Solid libraries (Cache, Queue, Cable).

## Development Commands

### Code Quality & Testing
- `bin/ci` - Run full CI pipeline (formatting, linting, security scan, tests, coverage)
- `bin/ci --fix` - Auto-fix formatting issues before running CI checks  
- `bin/coverage` - Generate detailed test coverage report with line/branch analysis
- `bin/watch-ci` - Monitor CI status in real-time during development

### Standard Rails Commands
- `bin/dev` - Start development server (preferred)
- `bin/rails server` - Alternative development server
- `bin/rails test` - Run test suite
- `bin/rails test:system` - Run system tests
- `bin/setup` - Initial application setup

### Individual Quality Tools
- `rubocop` - Ruby style checking (Rails Omakase style)
- `rubocop -A` - Auto-fix Ruby style violations
- `brakeman` - Security vulnerability scanning
- `npx eclint check` - EditorConfig compliance checking
- `npx eclint fix` - Auto-fix EditorConfig violations

## Architecture & Configuration

### Modern Rails Stack
- **Rails 8.0.2** with modern asset pipeline (Propshaft)
- **SQLite3** for all environments including production
- **ImportMap** for JavaScript (no Node.js bundling)
- **Hotwire** (Turbo + Stimulus) for interactivity
- **Solid Libraries**: Database-backed cache, queue, and cable

### Multi-Database Setup
The application uses separate SQLite databases:
- Primary database for application data
- `cache` database for Solid Cache
- `queue` database for Solid Queue  
- `cable` database for Solid Cable

### Code Quality Standards
- **EditorConfig**: UTF-8, LF line endings, 2-space indentation
- **RuboCop**: Rails Omakase configuration (DHH's opinionated style)
- **Brakeman**: Security scanning integrated into CI
- **SimpleCov**: Test coverage with detailed HTML reports

### Testing Setup
- **Minitest** (Rails default) for unit and integration tests
- **Capybara + Selenium** for system tests
- **SimpleCov** for coverage analysis with branch coverage tracking
- Pre-commit hooks run full CI pipeline to ensure quality

## Key Files & Directories

### Application Structure
- `app/` - Standard Rails MVC structure with comprehensive audit functionality
- `app/components/` - ViewComponent-based reusable UI components
- `app/services/` - Business logic services and GitHub API integration
- `app/jobs/` - Background job architecture with real-time updates
- `config/application.rb` - Main application configuration
- `config/database.yml` - Multi-database SQLite configuration

### Development Tools
- `bin/ci` - Comprehensive CI script with formatting, linting, security, and testing
- `bin/coverage` - Advanced coverage reporting with HTML parsing
- `bin/watch-ci` - Real-time CI monitoring using GitHub CLI
- `.editorconfig` - Code formatting standards

### Quality Assurance
- `rubocop` configured with Rails Omakase
- `brakeman` for security scanning
- `eclint` for EditorConfig enforcement
- Pre-commit hooks ensure code quality

### Commit Messages

This project follows [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Types:**
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation only changes
- `style:` Code style changes (formatting, missing semi-colons, etc)
- `refactor:` Code change that neither fixes a bug nor adds a feature
- `perf:` Performance improvements
- `test:` Adding missing tests or correcting existing tests
- `build:` Changes that affect the build system or external dependencies
- `ci:` Changes to CI configuration files and scripts
- `chore:` Other changes that don't modify src or test files

**Examples:**
```bash
git commit -m "feat: add GitHub team member validation"
git commit -m "fix: handle API rate limiting in team fetcher"
git commit -m "docs: update setup instructions in README"
git commit -m "refactor: extract team analysis logic to service"
```

### Code Coverage

The project enforces comprehensive test coverage using SimpleCov:
- **Minimum coverage**: 95% overall
- **Per-file minimum**: 80%
- **Branch coverage**: Enabled
- **Coverage reports**: Generated in `coverage/` directory
- **CI integration**: Coverage reports generated automatically with tests

Coverage configuration in `test/test_helper.rb`:
- Excludes test files, config, vendor, and database files
- Groups results by component type (Controllers, Models, Services, etc.)
- Fails CI if coverage drops below thresholds

## Development Workflow

1. **Setup**: Run `bin/setup` for initial configuration
2. **Development**: Use `bin/watch-ci` for real-time feedback during coding
3. **Quality Check**: Run `bin/ci --fix` to auto-fix issues and verify code quality
4. **Testing**: Use `bin/rails test` and `bin/rails test:system` for targeted testing
5. **Coverage**: Check `bin/coverage` for detailed test coverage analysis

The application emphasizes code quality with automated formatting, comprehensive testing, security scanning, and 95% code coverage requirement integrated into the development workflow.

## GitHub Configuration

The application uses GitHub API for team auditing functionality. Configuration is done via environment variables:

- **Environment Variable**: `GHTA_GITHUB_TOKEN` (required)
- **Scopes Required**: `repo` and `read:org` 
- **Token Type**: GitHub Personal Access Token (classic)

### Environment Setup Options

1. **Using direnv** (recommended):
  ```bash
  echo "export GHTA_GITHUB_TOKEN=your_token_here" >> .envrc
  direnv allow
  ```

2. **Using .env file**:
  ```bash
  echo "GHTA_GITHUB_TOKEN=your_token_here" >> .env
  ```

3. **Direct environment variable**:
  ```bash
  export GHTA_GITHUB_TOKEN=your_token_here
  ```

## Key Features Implemented

### Real-time UI Updates
- **Turbo Streams**: Server-driven DOM updates for audit progress
- **ActionCable**: WebSocket connections for live job status
- **Stimulus Controllers**: Client-side interactivity and keyboard navigation

### Audit Session Management
- **Interactive Status Toggles**: pending → validated → removed workflow
- **Progress Tracking**: Real-time completion percentage updates
- **Keyboard Navigation**: Vim-style (hjkl) and Emacs-style (bfpn) shortcuts
- **Local Timezone Display**: Browser-based timestamp conversion

### Background Job Architecture
- **Team Synchronization**: GitHub API integration with rate limiting
- **Issue Correlation**: Batch GraphQL queries for member activity tracking
- **Progress Broadcasting**: Real-time status updates via turbo streams

## Architecture Notes

### Turbo Streams vs Turbo Frames
- **Audit interfaces use Turbo Streams** for multi-target DOM updates
- **Avoided Turbo Frames** to prevent conflicts with stream-based updates
- **Regular divs with IDs** as turbo stream targets instead of frame tags

### Component Architecture
- **ViewComponent-based UI** for maintainable, reusable components
- **Stimulus controllers** for client-side behavior and keyboard navigation
- **Service objects** for GitHub API integration and business logic
