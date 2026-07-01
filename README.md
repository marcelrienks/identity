# My Portfolio Website

A modern, responsive portfolio website built with Bootstrap and deployed on AWS using CloudFormation infrastructure as code. This site showcases IT Service Delivery Management and technology expertise in a professional, high-performance format.

[![AWS](https://img.shields.io/badge/AWS-Cloud%20Hosting-orange?logo=amazon-aws)](https://aws.amazon.com/)
[![Bootstrap](https://img.shields.io/badge/Bootstrap-5.3.3-7952B3?logo=bootstrap)](https://getbootstrap.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](https://choosealicense.com/licenses/mit/)

---

## 🎯 Project Overview

This is a **professional portfolio website** built for Marcel Rienks, showcasing 20+ years of experience in IT Service Delivery Management, software engineering, and cloud infrastructure. It is designed to be highly customizable, mobile-responsive, and easily deployable on AWS or any static hosting provider.

---

## Features

- **Responsive Design** — Mobile-first responsive layout
- **Modern UI/UX** — Clean, professional design with smooth animations
- **Interactive Portfolio** — Filterable project section with hover/click effects
- **Performance Optimized** — Fast loading via CDN (CloudFront), minified assets, and browser caching
- **SEO Ready** — Structured content and meta tags for search engine optimization
- **Custom Color Scheme** — Unique branding with light blue (`#6DB1D8`), white (`#FFFFFF`), and dark gray (`#272727`)
- **Easy Customization** — CSS variables and modular structure
- **No Server Dependencies** — Pure static files, secure by default

---

## Tech Stack

### Frontend

- **HTML5** — Semantic markup and structure
- **CSS3** — Custom styling with CSS variables and animations
- **Bootstrap 5.3.3** — Responsive framework and components
- **JavaScript** — Interactive features and animations
- **AOS** — Scroll animations
- **Typed.js** — Text typing animations
- **Isotope** — Portfolio filtering

### Hosting

- **S3** — Static website hosting (optional)
- **CloudFront** — Global CDN with HTTPS/SSL (optional)
- **Route 53** — DNS management and custom domain (optional)
- **Certificate Manager (ACM)** — Free SSL certificates (optional)

---

## 🚀 Quick Start Guide

Deploy to AWS in one command using the unified deployment script.

### Prerequisites

1. **AWS Credentials** – Configure AWS CLI: `aws configure`
2. **Bash 4.0+** – Script requires associative arrays (introduced Bash 4.0)
3. **Route 53 Hosted Zone** – Domain registered and zone created in Route 53

#### Installing Bash 4.0+ on macOS

System Bash (3.2) is too old. Install via Homebrew:

```bash
# Install Bash 5.x
brew install bash

# Verify installation
bash --version  # Should show 5.x

# Update deploy.sh shebang to use Homebrew Bash
(echo '#!/opt/homebrew/bin/bash'; tail -n +2 deploy.sh) > deploy.sh.tmp && mv deploy.sh.tmp deploy.sh

# Verify
head -1 deploy.sh  # Should show #!/opt/homebrew/bin/bash
```

**Why?** The shebang (`#!/bin/bash`) uses absolute path to system Bash. Homebrew installs to `/opt/homebrew/bin/bash` (Apple Silicon) or `/usr/local/bin/bash` (Intel). Update the shebang to match your install location.

### Deploy Everything

```bash
./deploy.sh deploy --domain marcelrienks.com --subdomain www
```

**What happens automatically:**
- ✓ Creates S3 bucket with versioning
- ✓ Creates CloudFront CDN distribution  
- ✓ Creates Route 53 DNS alias records
- ✓ Requests ACM SSL/TLS certificate (or uses existing)
- ✓ Uploads all website files
- ✓ Saves deployment state for future updates
- **Time:** ~6-8 minutes

#### Deploy Command Arguments

| Argument | Default | Required | Description |
|----------|---------|----------|-------------|
| `--domain` | — | ✅ Yes | Domain name (e.g., `example.com`). Can also set `domain` in `.deployrc` |
| `--subdomain` | `www` | No | Subdomain prefix (e.g., `www`, `blog`, `docs`). Set in `.deployrc` or via flag |
| `--region` | `us-east-1` | No | AWS region (must be `us-east-1` for CloudFront + ACM) |
| `--source-dir` | `./` | No | Directory containing website files to deploy |
| `--aws-profile` | `default` | No | AWS CLI profile to use (see `~/.aws/config`) |
| `--certificate-arn` | `` | No | Use existing ACM certificate. Leave empty to auto-provision new cert |
| `--s3-bucket-name` | `` | No | Use existing S3 bucket. Leave empty to auto-create new bucket |
| `--cloudfront-distribution-id` | `` | No | Use existing CloudFront distribution. Leave empty to auto-create new distribution |
| `--dry-run` | — | No | Validate configuration without making AWS changes |
| `-v`, `--verbose` | — | No | Show detailed debug output |

**Examples:**

```bash
# Auto-provision all resources (default)
./deploy.sh deploy --domain example.com --subdomain www

# Use existing certificate
./deploy.sh deploy --domain example.com --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/...

# Use existing S3 bucket and CloudFront distribution
./deploy.sh deploy --domain example.com \
  --s3-bucket-name my-existing-bucket \
  --cloudfront-distribution-id E1234ABCD5FGH

# Mix auto-provisioned and existing resources
./deploy.sh deploy --domain example.com \
  --certificate-arn arn:aws:acm:... \
  --s3-bucket-name my-bucket
  # CloudFront will be auto-created

# Specific AWS profile
./deploy.sh deploy --domain example.com --aws-profile production

# Validate before deploying
./deploy.sh deploy --domain example.com --dry-run --verbose

# Deploy different subdomain to same domain
./deploy.sh deploy --domain example.com --subdomain blog
```

**Configuration Priority** (highest to lowest):
1. Command-line arguments (`--domain`, `--subdomain`, etc.)
2. Environment variables (`DEPLOY_DOMAIN`, `DEPLOY_SUBDOMAIN`, etc.)
3. `.deployrc` config file
4. Built-in defaults

### Update After Changes

```bash
./deploy.sh update
```

**What happens:**
- ✓ Bumps version (default: minor, e.g., 1.1.0 → 1.2.0)
- ✓ Detects only changed files
- ✓ Uploads changed files to S3
- ✓ Invalidates CloudFront cache
- ✓ Creates versioned manifest for rollback
- **Time:** ~2-4 minutes, changes live in 1-2 min

**Version bumping:**
```bash
./deploy.sh update                    # Minor bump: 1.1.0 → 1.2.0
./deploy.sh update --version major    # Major bump: 1.1.0 → 2.0.0
```

### Rollback If Needed

```bash
./deploy.sh rollback --version previous
```

---

## 📖 Full Documentation

- **[docs/guide.md](docs/guide.md)** — User guide with workflows, configuration, examples
- **[docs/reference.md](docs/reference.md)** — Technical reference: operations, performance, security, troubleshooting
- **[docs/architecture.md](docs/architecture.md)** — System design, deployment flow, state management
- **[docs/deployments.md](docs/deployments.md)** — Version manifest storage and multi-machine deployments

See `./deploy.sh help` for all available commands.

---

## Troubleshooting

### Bash Version Error: "ERROR: Bash 4.0+ is required"

**Symptom:** Script fails with `ERROR: Bash 4.0+ is required. Current version: 3.2.57`

**Cause:** Running with system Bash 3.2 instead of Homebrew Bash 5.x.

**Solution:**

1. **Verify Homebrew Bash is installed:**
   ```bash
   bash --version
   # Should show "GNU bash, version 5.x"
   ```

2. **Update deploy.sh shebang:**
   ```bash
   # Find Homebrew Bash location
   which bash
   
   # Update shebang (replace path if different)
   (echo '#!/opt/homebrew/bin/bash'; tail -n +2 deploy.sh) > deploy.sh.tmp && mv deploy.sh.tmp deploy.sh
   
   # Verify
   head -1 deploy.sh
   ```

3. **Try again:**
   ```bash
   ./deploy.sh help
   ```

**Alternative:** Run directly with correct Bash:
```bash
/opt/homebrew/bin/bash ./deploy.sh deploy --domain example.com
```

---

## Project Status

✅ **Deployment System** — Fully operational  
✅ **Version Manifests** — Tracked in `deployments/` for team access  
✅ **Multi-Machine Ready** — Clone → deploy from any machine  
✅ **CI/CD Ready** — Manifests available for automation  
✅ **Website Live** — [marcelrienks.com](https://marcelrienks.com)  

Latest version: **1.1.0** (7 animated job titles, deployed May 3, 2026)

---

---

## Template Attribution

- **Original Template:** [iPortfolio](https://bootstrapmade.com/iportfolio-bootstrap-portfolio-websites-template/) by BootstrapMade
- **Version:** v3.9.1 (Bootstrap 5.3.3)
- **License:** Free with attribution ([see details](https://bootstrapmade.com/license/))
- **Distributed by:** ThemeWagon

---
