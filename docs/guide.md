# Guide - AWS Static Website Deployment

Complete guide to deploying and managing static websites on AWS using CloudFormation infrastructure.

---

## Core Capabilities

| Capability | Command | When to Use |
|---|---|---|
| **Deploy Everything** | `./deploy.sh deploy` | First time setup or new domains |
| **Update Changed Files** | `./deploy.sh update` | After modifying HTML/CSS/JS |
| **Test Without Changes** | `./deploy.sh validate --dry-run` | Before production deployments |
| **Rollback Website** | `./deploy.sh rollback` | If deployment breaks something |
| **View History** | `./deploy.sh versions` | See what versions exist |

---

## Infrastructure

Your deployment creates:

```
✓ S3 Bucket (versioned storage)
  - Stores website files with automatic history
  - Enables instant rollback to any version
  
✓ CloudFront CDN
  - Global content delivery via edge locations
  - Automatic cache invalidation on updates
  - 1-2 minute cache refresh time
  
✓ Route 53 DNS
  - Custom domain routing (marcelrienks.com)
  - Automatic alias records
  - Multi-subdomain support (www, blog, docs)
  
✓ ACM SSL/TLS Certificate
  - HTTPS for your domain
  - Automatic renewal (30 days before expiry)
  - DNS validation via Route53
```

---

## Quick Start

### Initial Deployment

```bash
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

### Update Website

```bash
# After making changes to website files
./deploy.sh update

# What happens:
# ✓ Compares local files with S3
# ✓ Uploads ONLY modified files (faster)
# ✓ Invalidates CloudFront cache
# ✓ Changes live in 1-2 minutes
```

### Rollback if Needed

```bash
./deploy.sh rollback --version 1.0.0

# What happens:
# ✓ Restores files from S3 version history
# ✓ Invalidates CloudFront cache
# ✓ Website reverts immediately
```

---

## Typical Workflows

### Solo Developer

```
1. Initial setup:   ./deploy.sh deploy --domain mysite.com
2. Make changes:    (edit index.html, CSS, images)
3. Push to live:    ./deploy.sh update
4. View changes:    https://mysite.com (1-2 min)
5. Issues?          ./deploy.sh rollback --version previous
```

### CI/CD Pipeline

```
1. Push code to main branch
2. GitHub Actions runs: ./deploy.sh deploy --domain mysite.com
3. Website updated automatically
4. Tests fail → automatic rollback triggered
```

### Multi-Project Setup

```bash
# Main portfolio on www
./deploy.sh deploy --domain marcelrienks.com --subdomain www

# Blog on blog subdomain
./deploy.sh deploy --domain marcelrienks.com --subdomain blog

# Docs on docs subdomain  
./deploy.sh deploy --domain marcelrienks.com --subdomain docs

# All served from same S3 bucket with CloudFront routing
```

---

## What Files Get Deployed?

### ✓ Included by Default

- `.html` files
- `.css` stylesheets
- `.js` scripts
- `.json` data files
- `.jpg`, `.png`, `.svg`, `.webp`, `.gif` images
- `.ico` favicon
- `.woff`, `.woff2`, `.ttf`, `.otf` fonts

### ✗ Excluded by Default

- `node_modules/` directory
- `.git/` and `.gitignore`
- `.env*` files (security)
- `*.key` and `*.pem` files (security)
- `.DS_Store`, `*.tmp` (OS/temp files)
- Anything in your `.gitignore`

### Customize Patterns

```yaml
# In .deployrc
include_patterns:
  - "*.html"
  - "*.custom-format"

exclude_patterns:
  - "vendor/"
  - "*.map"
  - "secret*"
```

---

## Configuration

### File: `.deployrc`

```yaml
# Required
domain: marcelrienks.com

# Optional (with defaults shown)
subdomain: www                    # default: www
region: us-east-1                # default: us-east-1
source_dir: ./                   # default: ./
aws_profile: default             # default: default

# File patterns
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

# Cache control (optional)
# cache_default_ttl: 86400
# cache_max_ttl: 31536000

# Flags
# verbose: false
# dry_run: false
```

### Environment Variables

```bash
# Override config file settings
export DEPLOY_DOMAIN="marcelrienks.com"
export DEPLOY_SUBDOMAIN="www"
export DEPLOY_REGION="us-east-1"
export DEPLOY_AWS_PROFILE="default"

# Behavior
export DEPLOY_DRY_RUN="1"         # Test without changes
export DEPLOY_VERBOSE="1"         # Debug output
export LOG_LEVEL="DEBUG"          # Debug logging

# AWS credentials (if not using profiles)
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
```

### Priority Order

CLI args > Environment variables > .deployrc > Defaults

```bash
# CLI args override everything
./deploy.sh deploy --domain override.com --subdomain www

# ENV vars override .deployrc
DEPLOY_DOMAIN=override.com ./deploy.sh deploy

# .deployrc used if CLI args not provided
# (with domain: override.com in .deployrc)
./deploy.sh deploy
```

---

## Validation & Safety

### Pre-Flight Checks

```bash
./deploy.sh validate
```

Checks:
- ✓ AWS credentials valid
- ✓ Required AWS permissions present
- ✓ Domain name format valid
- ✓ Configuration file syntax
- ✓ Local files readable
- ✓ AWS API reachable

### Dry-Run Mode

```bash
./deploy.sh validate --dry-run
```

- Validates everything
- Shows what WOULD be deployed
- Makes NO AWS changes

### Exit Codes

| Code | Meaning | Example |
|------|---------|---------|
| 0 | Success | Deployment completed |
| 1 | General error | AWS permission denied |
| 2 | Invalid arguments | Missing required --domain |
| 3 | AWS error | CloudFormation stack failed |
| 4 | Validation failed | Configuration invalid |
| 5 | Timeout | CloudFormation took too long |

---

## Performance & Costs

### Speed

- **Deploy time:** 6-8 minutes (first time, infrastructure creation)
- **Update time:** 2-4 minutes (changed files only)
- **Cache refresh:** 1-2 minutes globally
- **Content delivery:** <100ms from nearest edge location

### AWS Costs

| Service | Cost | Notes |
|---------|------|-------|
| S3 Storage | ~$0.02/month | Small portfolio |
| CloudFront | ~$0.09/GB | Minimal for portfolio |
| Route 53 | $0.50/month | Per hosted zone |
| ACM Certificate | FREE | Auto-renewal |
| **Total** | **~$1-5/month** | Typical |

---

## Version Management

### List Deployments

```bash
./deploy.sh versions

# Output:
# Version 1.0.0 - 2026-05-02 10:30:15
# Version 1.0.1 - 2026-05-02 11:45:22
# Version 1.0.2 - 2026-05-02 13:12:45
```

### View Version Details

```bash
./deploy.sh versions --show 1.0.0

# Shows:
# - Version ID
# - Deployment timestamp
# - Number of files
# - File list with hashes
```

### Rollback to Any Version

```bash
# Rollback to specific version
./deploy.sh rollback --version 1.0.0

# Rollback to previous (before current)
./deploy.sh rollback --version previous
```

---

## Multi-Environment Deployments

### Staging vs Production

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

### Separate AWS Profiles

```bash
# Configure profiles in ~/.aws/credentials
[staging]
aws_access_key_id = AKIA...
aws_secret_access_key = ...

[production]
aws_access_key_id = AKIA...
aws_secret_access_key = ...

# Use with deploy script
AWS_PROFILE=staging ./deploy.sh deploy --domain staging.example.com
AWS_PROFILE=production ./deploy.sh deploy --domain example.com
```

---

## Multi-Subdomain Deployments

### Single Command per Subdomain

```bash
# Create subdomain entries
./deploy.sh deploy --domain example.com --subdomain www
./deploy.sh deploy --domain example.com --subdomain blog
./deploy.sh deploy --domain example.com --subdomain docs

# All served from same S3 bucket
# CloudFront routes based on subdomain/path
```

### CloudFront Routing

- `www.example.com` → S3 `/www/` prefix
- `blog.example.com` → S3 `/blog/` prefix
- `docs.example.com` → S3 `/docs/` prefix

---

## CI/CD Integration

### GitHub Actions

```yaml
name: Deploy to AWS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Install Bash 4+
        run: |
          apt-get update
          apt-get install -y bash
      
      - name: Deploy to AWS
        env:
          DEPLOY_DOMAIN: ${{ secrets.DOMAIN }}
          DEPLOY_SUBDOMAIN: www
          AWS_PROFILE: ci-user
        run: |
          /bin/bash ./deploy.sh deploy
```

### GitLab CI

```yaml
deploy:
  script:
    - apt-get install -y bash
    - export DEPLOY_DOMAIN=$DOMAIN
    - export DEPLOY_SUBDOMAIN=www
    - /bin/bash ./deploy.sh deploy
  only:
    - main
```

---

## Troubleshooting

### Validation Errors

```bash
# See all validation issues
./deploy.sh validate

# If config error:
cat .deployrc          # Check syntax
./deploy.sh validate   # Shows specific error
```

### Permission Denied

```bash
# Check AWS permissions
./deploy.sh validate

# Verify profile
aws sts get-caller-identity --profile your-profile

# Try with explicit profile
AWS_PROFILE=your-profile ./deploy.sh deploy
```

### CloudFormation Timeout

```bash
# Check stack status
aws cloudformation describe-stacks \
  --stack-name identity \
  --query 'Stacks[0].StackStatus'

# View events for details
aws cloudformation describe-stack-events \
  --stack-name identity
```

### Changes Not Visible

```bash
# Wait 1-2 minutes for CloudFront invalidation
# Then hard refresh in browser:
# Chrome/Firefox: Ctrl+Shift+R
# Safari: Cmd+Shift+R

# Check if update actually ran
./deploy.sh versions

# Verify file was deployed
aws s3 ls s3://id-marcelrienks.com-static/index.html
```

### Rollback Failed

```bash
# List available versions
./deploy.sh versions

# Try specific version
./deploy.sh rollback --version 1.0.0

# Check S3 version history
aws s3api list-object-versions \
  --bucket id-marcelrienks.com-static
```

---

## Key Features Summary

### 📦 Versioning
- Every deployment creates a snapshot
- S3 keeps full object history
- Instant rollback to any version
- Version manifest with file hashes

### 🔒 Security
- S3 bucket blocks all public access
- Only CloudFront can access files
- Origin Access Control (OAC) enforced
- `.env` and `.key` files excluded automatically
- HTTPS required for all traffic

### 🚦 Multi-Environment
- Deploy to staging and production with separate profiles
- Different AWS accounts/credentials per environment

### 🌍 Multi-Subdomain
- Deploy multiple subdomains from single repository
- Each with independent cache rules
- Same S3 bucket, CloudFront routing

### ✅ Validation
- Pre-flight checks before deployment
- Dry-run mode for testing
- Clear error messages

---

## See Also

- [reference.md](reference.md) - Technical details, operations, performance, security
