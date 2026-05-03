# Usage Examples - Deploy.sh Capabilities

## Quick Start

```bash
# Initial deployment to AWS
./deploy.sh deploy --domain marcelrienks.com --subdomain www

# Update website content after changes
./deploy.sh update

# Check what would be deployed (dry-run)
./deploy.sh validate --dry-run

# View deployment history
./deploy.sh versions

# Rollback to previous version
./deploy.sh rollback --version 1.0.0
```

---

## 1. Initial Deployment

**Capability: Set up entire AWS infrastructure and deploy website**

```bash
# Full deployment with all infrastructure
./deploy.sh deploy \
  --domain marcelrienks.com \
  --subdomain www \
  --region us-east-1

# What happens:
# ✓ Creates S3 bucket with versioning
# ✓ Creates CloudFront CDN distribution
# ✓ Creates Route 53 DNS alias records
# ✓ Requests ACM SSL certificate
# ✓ Uploads all website files
# ✓ Saves deployment state for future updates
```

---

## 2. Update Website Content

**Capability: Upload only changed files, fast CDN refresh**

```bash
# Update after making changes to website
./deploy.sh update

# What happens:
# ✓ Compares local files with S3
# ✓ Uploads ONLY modified files (faster)
# ✓ Invalidates CloudFront cache
# ✓ Changes live in 1-2 minutes
```

---

## 3. Validation & Dry-Run

**Capability: Test deployment without making changes**

```bash
# Validate configuration and check AWS permissions
./deploy.sh validate

# Test deployment without uploading
./deploy.sh validate --dry-run

# What's checked:
# ✓ AWS credentials and permissions
# ✓ Domain name validity
# ✓ Configuration file format
# ✓ File permissions and readability
# ✓ AWS API connectivity
# ✓ Required AWS permissions
```

---

## 4. Version Management

**Capability: Track and manage deployment versions**

```bash
# List all deployments
./deploy.sh versions

# Show specific version details
./deploy.sh versions --show 1.0.0

# What you see:
# - Version ID (timestamp-based)
# - Deployment date
# - Number of files deployed
# - File list with hashes
```

---

## 5. Rollback to Previous Version

**Capability: Restore website to earlier state**

```bash
# Rollback to specific version
./deploy.sh rollback --version 1.0.0

# What happens:
# ✓ Restores files from S3 version history
# ✓ Invalidates CloudFront cache
# ✓ Website reverts immediately
# ✓ Previous version accessible again
```

---

## 6. Multi-Subdomain Support

**Capability: Deploy to multiple subdomains from single repo**

```bash
# Deploy to www subdomain
./deploy.sh deploy --domain marcelrienks.com --subdomain www

# Deploy to blog subdomain
./deploy.sh deploy --domain marcelrienks.com --subdomain blog

# What happens:
# ✓ CloudFront behaviors route different paths/subdomains
# ✓ Each subdomain gets separate cache rules
# ✓ All served from same S3 bucket
```

---

## 7. Configuration Management

**Capability: Environment-based deployments**

```bash
# Using config file
cat > .deployrc << EOF
domain: marcelrienks.com
subdomain: www
region: us-east-1
aws_profile: my-aws-profile
source_dir: ./
cache_default_ttl: 86400
verbose: false
EOF

./deploy.sh deploy

# Override via environment variables
export DEPLOY_DOMAIN="marcelrienks.com"
export DEPLOY_SUBDOMAIN="www"
./deploy.sh deploy

# Override via CLI args (highest priority)
./deploy.sh deploy --domain marcelrienks.com --subdomain www
# Priority: CLI args > ENV vars > .deployrc > defaults
```

---

## 8. Verbose Debugging

**Capability: Troubleshooting deployments**

```bash
# See detailed debug output
./deploy.sh deploy --verbose

# Set debug environment
export LOG_LEVEL=DEBUG
./deploy.sh deploy

# Output includes:
# - Function execution trace
# - AWS API calls
# - File operations
# - State transitions
```

---

## Advanced Scenarios

### Scenario 1: Deploy to Multiple Environments

```bash
# Staging environment
AWS_PROFILE=staging ./deploy.sh deploy \
  --domain staging-portfolio.com \
  --subdomain www

# Production environment
AWS_PROFILE=production ./deploy.sh deploy \
  --domain marcelrienks.com \
  --subdomain www
```

### Scenario 2: Content Update Workflow

```bash
# 1. Update local files
# (edit index.html, CSS, etc.)

# 2. Validate before upload
./deploy.sh validate --dry-run

# 3. Deploy to production
./deploy.sh update

# 4. Verify live
curl https://marcelrienks.com

# 5. If issues: quick rollback
./deploy.sh rollback --version previous
```

### Scenario 3: CI/CD Pipeline Integration

```bash
# In your GitHub Actions / GitLab CI:
#!/bin/bash
set -e

# Install dependencies
brew install bash aws-cli

# Deploy with CI/CD credentials
export AWS_PROFILE=ci-user
export DEPLOY_DOMAIN=$DOMAIN
export DEPLOY_SUBDOMAIN=www

/opt/homebrew/bin/bash ./deploy.sh deploy
```

### Scenario 4: Blog/Multi-Project Setup

```bash
# Main portfolio on /
./deploy.sh deploy --domain marcelrienks.com --subdomain www

# Blog on /blog subdomain
./deploy.sh deploy --domain marcelrienks.com --subdomain blog

# Docs on /docs subdomain
./deploy.sh deploy --domain marcelrienks.com --subdomain docs

# Each served from same S3 bucket with CloudFront routing
```

---

## Configuration Reference

### File: `.deployrc`

```yaml
# Required
domain: marcelrienks.com

# Optional
subdomain: www                    # default: www
region: us-east-1                # default: us-east-1 (required for CloudFront)
source_dir: ./                   # default: ./
aws_profile: default             # default: default

# File filtering
include_patterns:
  - "*.html"
  - "*.css"
  - "*.js"
  - "*.json"
  - "*.jpg"
  - "*.png"
  - "*.svg"

exclude_patterns:
  - "node_modules/"
  - ".git/"
  - ".env*"
  - "*.tmp"

# CDN cache control
# cache_default_ttl: 86400          # 1 day
# cache_max_ttl: 31536000           # 1 year

# Flags
# verbose: false                     # Enable debug output
# dry_run: false                     # Don't make AWS changes
```

---

## Environment Variables

```bash
# Configuration
export DEPLOY_DOMAIN="marcelrienks.com"
export DEPLOY_SUBDOMAIN="www"
export DEPLOY_REGION="us-east-1"
export DEPLOY_SOURCE_DIR="./"
export DEPLOY_AWS_PROFILE="default"

# Behavior
export DEPLOY_DRY_RUN="1"                 # Test without changes
export DEPLOY_VERBOSE="1"                 # Debug output
export LOG_LEVEL="DEBUG"                  # Logging level

# AWS Credentials (if not using profiles)
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
```

---

## Exit Codes

| Code | Meaning | Example |
|------|---------|---------|
| 0 | Success | Deployment completed |
| 1 | General error | AWS permission denied |
| 2 | Invalid arguments | Missing required --domain |
| 3 | AWS error | CloudFormation stack failed |
| 4 | Validation failed | Configuration invalid |
| 5 | Timeout | CloudFormation stack creation too slow |

---

## Command Reference

| Command | Purpose | Example |
|---------|---------|---------|
| `deploy` | Full infrastructure setup + content | `./deploy.sh deploy --domain example.com` |
| `update` | Update changed files only | `./deploy.sh update` |
| `validate` | Check configuration and permissions | `./deploy.sh validate --dry-run` |
| `versions` | List deployment history | `./deploy.sh versions` |
| `rollback` | Revert to previous version | `./deploy.sh rollback --version 1.0.0` |
| `help` | Show help | `./deploy.sh help` |
