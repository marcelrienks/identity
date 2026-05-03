# Quick Reference - Deploy System Capabilities

## What Can You Do With This System?

### 🚀 Core Deployment Abilities

| Capability | Command | When to Use |
|---|---|---|
| **Deploy Everything** | `./deploy.sh deploy` | First time setup or new domains |
| **Update Changed Files** | `./deploy.sh update` | After modifying HTML/CSS/JS |
| **Test Without Changes** | `./deploy.sh validate --dry-run` | Before production deployments |
| **Rollback Website** | `./deploy.sh rollback` | If deployment breaks something |
| **View History** | `./deploy.sh versions` | See what versions exist |

---

## Infrastructure You Get

```
✓ S3 Bucket (versioned storage)
  - Stores website files
  - Automatic version history
  - 0 versions retained for rollback
  
✓ CloudFront CDN
  - Global content delivery
  - Automatic cache invalidation on updates
  - 1-2 minute cache refresh
  
✓ Route 53 DNS
  - Custom domain routing (marcelrienks.com)
  - Automatic alias records
  - Multi-subdomain support (www, blog, docs)
  
✓ ACM SSL/TLS Certificate
  - HTTPS for your domain
  - Automatic renewal
  - DNS validation
```

---

## Typical Workflows

### 👤 Solo Developer Workflow
```
1. Initial setup:   ./deploy.sh deploy --domain mysite.com
2. Make changes:    (edit HTML/CSS/JS)
3. Push to live:    ./deploy.sh update
4. Oops, rollback:  ./deploy.sh rollback --version previous
```

### 🤖 CI/CD Pipeline Workflow
```
1. Push to main branch
2. GitHub Actions runs: ./deploy.sh deploy --domain mysite.com
3. Website updated automatically
4. If tests fail: automatic rollback
```

### 📱 Multi-Project Workflow
```
Main site:    ./deploy.sh deploy --domain mysite.com --subdomain www
Blog:         ./deploy.sh deploy --domain mysite.com --subdomain blog
Docs:         ./deploy.sh deploy --domain mysite.com --subdomain docs
All from same S3 bucket, different CloudFront behaviors
```

---

## What Files Get Deployed?

### ✓ Automatically Included
- `.html` files
- `.css` stylesheets
- `.js` scripts
- `.json` data files
- `.jpg`, `.png`, `.svg`, `.webp` images
- `.ico` favicon
- `.woff`, `.woff2`, `.ttf`, `.otf` fonts

### ✗ Automatically Excluded
- `node_modules/` directory
- `.git/` and `.gitignore`
- `.env*` files (security)
- `*.key` and `*.pem` files (security)
- `.DS_Store`, `*.tmp` (OS/temp files)
- Anything in `.gitignore`

### 🔧 Customize
```yaml
# In .deployrc
include_patterns:
  - "*.custom-format"

exclude_patterns:
  - "vendor/"
  - "*.map"
```

---

## Performance & Costs

### ⚡ Performance
- **Deploy time:** 30-60 seconds for full deployment
- **Update time:** 5-10 seconds for changed files
- **Cache invalidation:** 1-2 minutes globally
- **Content delivery:** <100ms from nearest edge location

### 💰 AWS Costs (Typical)
- **S3 Storage:** ~$0.02/month (small portfolio)
- **CloudFront:** ~$0.09/GB (minimal for portfolio)
- **Route 53:** $0.50/month per hosted zone
- **ACM Certificate:** FREE

**Total:** ~$1-5/month for small portfolio

---

## Key Features

### 📦 Versioning
- Every deployment creates a version snapshot
- S3 keeps object history
- Instantly rollback to any previous version
- Version manifest includes file hashes

### 🔒 Security
- S3 bucket blocks all public access
- Only CloudFront can read files
- Origin Access Identity (OAI) for S3
- No direct S3 URL exposure
- `.env` and key files excluded automatically

### 🚦 Multi-Environment
```bash
# Staging (separate AWS profile)
AWS_PROFILE=staging ./deploy.sh deploy --domain staging.mysite.com

# Production
AWS_PROFILE=production ./deploy.sh deploy --domain mysite.com
```

### 🌍 Multi-Subdomain
```bash
# Route traffic to different subdomains
./deploy.sh deploy --domain mysite.com --subdomain www
./deploy.sh deploy --domain mysite.com --subdomain blog
./deploy.sh deploy --domain mysite.com --subdomain api
```

---

## Validation & Safety

### ✓ Pre-Flight Checks
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

### ✓ Dry-Run Mode
```bash
./deploy.sh validate --dry-run
```
- Validates everything
- Shows what WOULD be deployed
- Makes NO AWS changes

---

## Troubleshooting Capabilities

| Problem | Command | Result |
|---------|---------|--------|
| Permission denied | `./deploy.sh validate` | Shows missing AWS permissions |
| Config error | `./deploy.sh validate` | Shows config problems |
| Too slow? | `LOG_LEVEL=DEBUG ./deploy.sh deploy` | Shows each step |
| Wrong version deployed? | `./deploy.sh rollback --version X` | Instant rollback |
| Need previous state? | `./deploy.sh versions` | See all versions |

---

## Integration Examples

### GitHub Actions
```yaml
- name: Deploy to AWS
  run: |
    brew install bash
    /opt/homebrew/bin/bash ./deploy.sh deploy \
      --domain ${{ secrets.DOMAIN }} \
      --subdomain www
```

### GitLab CI
```yaml
deploy:
  script:
    - apt-get install -y bash
    - bash ./deploy.sh deploy --domain $DOMAIN
```

### Manual Deployment
```bash
# One-liner
cd /path/to/website && /opt/homebrew/bin/bash deploy.sh update
```

---

## Limitations & Constraints

| Limitation | Impact | Workaround |
|---|---|---|
| Static sites only | No server-side code | Use Jamstack (Next.js, Hugo, etc.) |
| us-east-1 for certificates | CloudFront requirement | Use us-east-1 region |
| Route 53 only | Can't use other DNS | Add CNAME records manually |
| Manual config | Not auto-discovered | Create `.deployrc` once, reuse |
| File size limits | S3 limit is 5GB per file | Gzip/compress if needed |

---

## Summary - 5 Things You Can Do

1. **Deploy a website to AWS in seconds** with full CDN, DNS, and SSL
2. **Update changed files only** (fast incremental updates, not full redeployment)
3. **Rollback instantly** to any previous version if something breaks
4. **Validate safely** with dry-run mode before going live
5. **Deploy multiple subdomains** (blog, docs, portfolio) from single repo

That's it! Everything else is optional configuration.
