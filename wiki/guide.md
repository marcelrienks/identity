# Guide

This guide covers the everyday deployment workflow for this project: deploy once, update after changes, validate before acting, and roll back if needed.

## What the deployment does

A deployment creates or updates:

- S3 storage for the site files
- CloudFront distribution for CDN delivery and cache invalidation
- Route 53 DNS records for the chosen subdomain
- ACM certificate and HTTPS support when needed

For the full command reference, see [reference.md](reference.md).

## Quick start

### Initial deployment

```bash
./deploy.sh deploy \
  --domain marcelrienks.com \
  --subdomain www \
  --region us-east-1
```

### Update after changes

```bash
./deploy.sh update
```

This compares the current files with the last deployed manifest, uploads only changed files, and invalidates the CloudFront cache.

### Validate before deploying

```bash
./deploy.sh validate --domain marcelrienks.com
```

### Roll back if needed

```bash
./deploy.sh rollback --version 1.0.0
```

## Common workflow

1. Deploy the site once with `./deploy.sh deploy ...`
2. Edit the site files locally
3. Run `./deploy.sh update` to publish the changes
4. Use `./deploy.sh validate` when you want a safe pre-flight check
5. Use `./deploy.sh rollback --version <version>` if you need to restore an older release

## Configuration

The script reads configuration in this order:

1. Command-line arguments
2. Environment variables such as `DEPLOY_DOMAIN` and `DEPLOY_SUBDOMAIN`
3. `.deployrc`
4. Built-in defaults

A minimal `.deployrc` can look like this:

```yaml
domain: marcelrienks.com
subdomain: www
region: us-east-1
source_dir: ./
aws_profile: default
```

## Useful commands

```bash
./deploy.sh deploy --domain example.com --subdomain www
./deploy.sh update --version major
./deploy.sh rollback --version previous
./deploy.sh versions list
./deploy.sh versions show 1.1.0
```

For the complete list of supported flags and examples, see [reference.md](reference.md).

---

## Tips

- Use `./deploy.sh validate` before a production deployment if you want a pre-flight check.
- Use `./deploy.sh update --dry-run` when you want to preview the change set without publishing.
- Use `./deploy.sh versions list` to inspect the deployment history before rolling back.

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

## See also

- [reference.md](reference.md) for the full command and option list
- [quickref.md](quickref.md) for a short cheat sheet
- [deployments.md](deployments.md) for manifest and rollback details
