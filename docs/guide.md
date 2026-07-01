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
# ✓ Bumps version (default: minor, e.g., 1.1.0 → 1.2.0)
# ✓ Compares local files with S3
# ✓ Uploads ONLY modified files (faster)
# ✓ Invalidates CloudFront cache
# ✓ Creates versioned manifest for rollback
# ✓ Changes live in 1-2 minutes
```

**Version Bumping:**
```bash
./deploy.sh update                    # Minor bump (default): 1.1.0 → 1.2.0
./deploy.sh update --version major    # Major bump: 1.1.0 → 2.0.0
./deploy.sh update --version minor    # Explicit minor: 1.1.0 → 1.2.0
```

**Why version bumping?** Each `update` automatically creates a new semantic version manifest (`1.2.0.json`, `1.3.0.json`, etc.) in `deployments/`, tracked in git. This enables:
- Rollback to any specific version: `./deploy.sh rollback --version 1.1.0`
- Multi-machine deployments (manifests in git)
- Clear version history and audit trail

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

# Certificate (optional)
# Leave empty to auto-provision, or provide existing cert ARN
certificate_arn:                 # Use existing cert (leave blank for auto-provision)
# certificate_arn: arn:aws:acm:us-east-1:123456789012:certificate/abc123

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
# Core deployment settings
export DEPLOY_DOMAIN="marcelrienks.com"
export DEPLOY_SUBDOMAIN="www"
export DEPLOY_REGION="us-east-1"
export DEPLOY_AWS_PROFILE="default"

# Certificate (leave empty for auto-provision)
export DEPLOY_CERTIFICATE_ARN=""
# export DEPLOY_CERTIFICATE_ARN="arn:aws:acm:us-east-1:123456789012:certificate/abc123"

# Behavior flags
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

## Command Arguments Reference

### Deploy Command

**Syntax:** `./deploy.sh deploy [OPTIONS]`

| Argument | Env Var | Config Key | Default | Required | Description |
|----------|---------|-----------|---------|----------|-------------|
| `--domain` | `DEPLOY_DOMAIN` | `domain` | — | ✅ Yes | Domain name (e.g., `example.com`). Must be registered in Route 53 hosted zone. |
| `--subdomain` | `DEPLOY_SUBDOMAIN` | `subdomain` | `www` | No | Subdomain prefix (e.g., `www`, `blog`, `docs`, `api`). Creates `subdomain.domain.com`. |
| `--region` | `DEPLOY_REGION` | `region` | `us-east-1` | No | AWS region. **Must be `us-east-1`** for CloudFront + ACM integration. |
| `--source-dir` | `DEPLOY_SOURCE_DIR` | `source_dir` | `./` | No | Directory containing website files. Uploaded to S3 bucket. |
| `--aws-profile` | `DEPLOY_AWS_PROFILE` | `aws_profile` | `default` | No | AWS CLI profile name. Defined in `~/.aws/config`. |
| `--certificate-arn` | `DEPLOY_CERTIFICATE_ARN` | `certificate_arn` | `` | No | Existing ACM certificate ARN. Leave empty to auto-provision. Format: `arn:aws:acm:us-east-1:123456789012:certificate/12345678-...` |
| `--s3-bucket-name` | `DEPLOY_S3_BUCKET_NAME` | `s3_bucket_name` | `` | No | Existing S3 bucket name. Leave empty to auto-create. Must be accessible and have proper permissions. |
| `--cloudfront-distribution-id` | `DEPLOY_CLOUDFRONT_DISTRIBUTION_ID` | `cloudfront_distribution_id` | `` | No | Existing CloudFront distribution ID. Leave empty to auto-create. Format: `E1234ABCD5FGH` |
| `--dry-run` | — | `dry_run` | — | No | Validate without making AWS changes. Useful for testing. |
| `-v`, `--verbose` | — | `verbose` | — | No | Enable debug output. Shows detailed operation logs. |

### Resource Provisioning Modes

Each major resource can be auto-provisioned (default) or use an existing resource:

#### Auto-Provision Everything (Default)
```bash
./deploy.sh deploy --domain example.com --subdomain www
# Creates: S3 bucket, CloudFront distribution, ACM certificate, Route53 record
```

#### Use Existing Certificate
```bash
./deploy.sh deploy --domain example.com \
  --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/abc123
# CloudFormation creates S3, CloudFront, Route53; skips certificate
```

#### Use Existing S3 Bucket
```bash
./deploy.sh deploy --domain example.com \
  --s3-bucket-name my-existing-bucket
# CloudFormation creates CloudFront, certificate, Route53; skips S3 bucket
```

#### Use Existing CloudFront Distribution
```bash
./deploy.sh deploy --domain example.com \
  --cloudfront-distribution-id E1234ABCD5FGH
# CloudFormation creates S3, certificate, Route53; skips CloudFront
# Routes Route53 record to existing distribution
```

#### Mix Auto-Provisioned and Existing Resources
```bash
./deploy.sh deploy --domain example.com \
  --certificate-arn arn:aws:acm:... \
  --s3-bucket-name my-bucket
# Uses existing cert and bucket; auto-creates CloudFront and Route53
```

#### Finding AWS Resource IDs

**ACM Certificate ARN:**
```bash
aws acm list-certificates --region us-east-1
aws acm describe-certificate --certificate-arn arn:aws:acm:... --region us-east-1
```

**S3 Bucket Name:**
```bash
aws s3 ls
```

**CloudFront Distribution ID:**
```bash
aws cloudfront list-distributions | jq '.DistributionList.Items[] | {Id, DomainName, Aliases}'
```

### Other Commands

| Command | Syntax | Arguments |
|---------|--------|-----------|
| **Update** | `./deploy.sh update` | `--version [major\|minor]`, `--dry-run`, `-v` |
| **Rollback** | `./deploy.sh rollback` | `--version VERSION`, `--dry-run`, `-v` |
| **Versions** | `./deploy.sh versions` | `--region`, `--aws-profile` |
| **Validate** | `./deploy.sh validate` | `--dry-run`, `-v` |

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
