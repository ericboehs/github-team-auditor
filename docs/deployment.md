# Deployment Guide

This guide covers deploying the GitHub Team Auditor application to production environments.

## Overview

The application is built for deployment with:
- **Kamal** for containerized deployment
- **SQLite** databases for all environments
- **Rails 8.0.2** with modern asset pipeline
- **Solid libraries** for caching, queues, and cables

## Prerequisites

### Required Software

- Docker (for containerization)
- Kamal gem (`gem install kamal`)
- GitHub Personal Access Token with appropriate permissions

### GitHub Token Setup

Create a GitHub Personal Access Token with these scopes:
- `read:org` - Read organization membership and team data  
- `read:user` - Read user profile information

## Environment Configuration

### Environment Variables

Set these environment variables in your deployment:

```bash
# Required
GHTA_GITHUB_TOKEN=ghp_your_production_token_here

# Optional (with defaults)
RAILS_ENV=production
RAILS_LOG_LEVEL=info
RAILS_SERVE_STATIC_FILES=true
```

### Rails Credentials

Encrypt sensitive configuration using Rails credentials:

```bash
# Edit production credentials
bin/rails credentials:edit --environment production
```

Add:
```yaml
github:
  token: ghp_your_production_token_here

secret_key_base: your_secret_key_base_here
```

## Kamal Deployment

### Configuration

The application includes a `config/deploy.yml` file configured for Kamal deployment. Key settings:

```yaml
# Basic service configuration
service: github-team-auditor
image: github-team-auditor
servers:
  - your-production-server.com

# Registry configuration
registry:
  server: registry.digitalocean.com
  username: your-registry-username
  password:
    - REGISTRY_PASSWORD

# Environment variables
env:
  clear:
    RAILS_ENV: production
  secret:
    - GHTA_GITHUB_TOKEN
    - RAILS_MASTER_KEY
```

### Initial Setup

1. **Configure your deploy.yml**:
   ```bash
   # Edit config/deploy.yml with your server details
   vim config/deploy.yml
   ```

2. **Set up server access**:
   ```bash
   # Setup Kamal on your servers
   kamal setup
   ```

3. **Deploy the application**:
   ```bash
   # Initial deployment
   kamal deploy
   ```

### Subsequent Deployments

```bash
# Deploy updates
kamal deploy

# Deploy specific version
kamal deploy --version=v1.2.3

# Roll back if needed
kamal rollback
```

## Database Setup

### SQLite Configuration

The application uses separate SQLite databases:

- **Primary**: Application data (`storage/production.sqlite3`)
- **Cache**: Solid Cache data (`storage/production_cache.sqlite3`)
- **Queue**: Solid Queue jobs (`storage/production_queue.sqlite3`)
- **Cable**: Solid Cable data (`storage/production_cable.sqlite3`)

### Database Initialization

```bash
# Run migrations
kamal app exec bin/rails db:migrate

# Seed initial data
kamal app exec bin/rails db:seed

# Or run setup (includes both)
kamal app exec bin/setup
```

## SSL and Security

### SSL Certificate

Configure SSL in your reverse proxy (nginx, Cloudflare, etc.):

```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/private.key;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Security Headers

The application includes security headers via Rails configuration:

```ruby
# config/application.rb
config.force_ssl = true  # Enable in production
config.ssl_options = { redirect: { exclude: ->(request) { request.path.start_with?('/health') } } }
```

## Background Jobs

### Solid Queue Setup

Background jobs are handled by Solid Queue:

```bash
# Check queue status
kamal app exec bin/rails solid_queue:status

# Monitor jobs
kamal app exec bin/rails console
> SolidQueue::Job.pending.count
> SolidQueue::Job.failed.count
```

### Job Monitoring

Monitor important job types:

- **TeamSyncJob**: Syncs team data from GitHub
- **MemberEnrichmentJob**: Enriches member profiles

```ruby
# Check recent sync jobs
TeamSyncJob.where(created_at: 1.day.ago..).count

# View failed jobs
SolidQueue::Job.failed.includes(:failed_execution)
```

## Health Checks

### Application Health

The application includes health check endpoints:

```bash
# Basic health check
curl https://your-domain.com/up

# Detailed health (if implemented)
curl https://your-domain.com/health
```

### Database Health

Check database connectivity:

```bash
# Connect to console
kamal app exec bin/rails console

# Test database
> ActiveRecord::Base.connection.execute("SELECT 1")
> User.count
> Team.count
```

## Monitoring and Logging

### Application Logs

Access application logs:

```bash
# View recent logs
kamal app logs

# Follow logs in real-time
kamal app logs --follow

# Filter by service
kamal app logs --grep "ERROR"
```

### Performance Monitoring

Monitor key metrics:

- Response times for audit operations
- GitHub API rate limit usage
- Background job processing times
- Database query performance

### GitHub API Monitoring

Track API usage to avoid rate limits:

```ruby
# Check current rate limit
organization = Organization.first
client = Github::ApiClient.new(organization)
rate_limit = client.instance_variable_get(:@client).rate_limit
puts "Rate limit: #{rate_limit.remaining}/#{rate_limit.limit}"
puts "Resets at: #{rate_limit.resets_at}"
```

## Backup and Recovery

### Database Backups

SQLite databases should be backed up regularly:

```bash
# Create backup script
#!/bin/bash
BACKUP_DIR="/backup/github-team-auditor/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Backup all databases
cp storage/production.sqlite3 $BACKUP_DIR/
cp storage/production_cache.sqlite3 $BACKUP_DIR/
cp storage/production_queue.sqlite3 $BACKUP_DIR/
cp storage/production_cable.sqlite3 $BACKUP_DIR/

# Compress backups
tar -czf $BACKUP_DIR.tar.gz $BACKUP_DIR/
rm -rf $BACKUP_DIR/
```

### Recovery Process

To restore from backup:

```bash
# Stop the application
kamal app stop

# Restore database files
tar -xzf backup-20250101.tar.gz
cp backup-20250101/*.sqlite3 storage/

# Restart application
kamal app start
```

## Scaling Considerations

### Horizontal Scaling

For multiple application servers:

1. **Shared Storage**: Use network storage for SQLite files
2. **Load Balancer**: Distribute traffic across instances
3. **Session Store**: Configure shared session storage

### Database Scaling

If SQLite becomes a bottleneck:

1. **PostgreSQL Migration**: Rails supports easy database switching
2. **Read Replicas**: For read-heavy workloads
3. **Connection Pooling**: Configure appropriate pool sizes

## Troubleshooting

### Common Issues

**GitHub API Errors**:
```bash
# Check token permissions
kamal app exec bin/rails console
> ENV['GHTA_GITHUB_TOKEN']
> Github::ApiClient.new(Organization.first).instance_variable_get(:@client).rate_limit
```

**Background Job Issues**:
```bash
# Check queue processing
kamal app exec bin/rails solid_queue:status

# Restart job processing
kamal app restart
```

**Database Lock Issues**:
```bash
# Check for long-running transactions
kamal app exec bin/rails console
> ActiveRecord::Base.connection.execute("PRAGMA wal_checkpoint(TRUNCATE)")
```

### Emergency Procedures

**Quick Rollback**:
```bash
kamal rollback
```

**Emergency Maintenance Mode**:
```bash
kamal app stop
# Fix issues
kamal app start
```

**Database Recovery**:
```bash
# If database corruption occurs
kamal app exec bin/rails db:drop db:create db:migrate db:seed
# Restore from backup if available
```

## Security Checklist

- [ ] GitHub token has minimum required permissions
- [ ] SSL/TLS enabled with valid certificates
- [ ] Rails credentials properly encrypted
- [ ] Security headers configured
- [ ] Regular security updates applied
- [ ] Database files properly secured
- [ ] Backup files encrypted
- [ ] Log files don't contain sensitive data

## Maintenance

### Regular Tasks

**Weekly**:
- Review application logs for errors
- Check GitHub API rate limit usage
- Monitor background job processing
- Verify team sync operations

**Monthly**:
- Update dependencies (security patches)
- Review and rotate GitHub tokens if needed
- Archive old audit sessions
- Check backup integrity

**Quarterly**:
- Performance review and optimization
- Security audit
- Capacity planning review
- Documentation updates

This deployment guide ensures reliable, secure operation of the GitHub Team Auditor in production environments.