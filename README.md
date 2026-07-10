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

## Command Reference

The deployment script exposes several commands. The most complete references live in [wiki/guide.md](wiki/guide.md) and [wiki/reference.md](wiki/reference.md).

### Common options

These options are available on the relevant commands:

| Option | Applies to | Description |
|--------|------------|-------------|
| `--domain` | `deploy`, `validate` | Domain name (for example `example.com`) |
| `--subdomain` | `deploy`, `update`, `validate` | Subdomain prefix (default `www`) |
| `--region` | `deploy`, `validate` | AWS region (default `us-east-1`) |
| `--source-dir` | `deploy`, `update`, `validate` | Directory containing the website files |
| `--aws-profile` | `deploy`, `validate` | AWS CLI profile name |
| `--certificate-arn` | `deploy` | Reuse an existing ACM certificate |
| `--s3-bucket-name` | `deploy` | Reuse an existing S3 bucket |
| `--cloudfront-distribution-id` | `deploy` | Reuse an existing CloudFront distribution |
| `--dry-run` | `deploy`, `update` | Show what would happen without making AWS changes |
| `-v`, `--verbose` | all commands | Enable detailed debug output |
| `-h`, `--help` | all commands | Show command-specific usage |

### Commands at a glance

| Command | Purpose | Key arguments |
|---------|---------|---------------|
| `deploy` | Provision AWS resources and upload the initial site | `--domain` (required), `--subdomain`, `--region`, `--source-dir`, `--aws-profile`, `--certificate-arn`, `--s3-bucket-name`, `--cloudfront-distribution-id`, `--dry-run` |
| `update` | Upload changed files, invalidate cache, and create a new version | `--subdomain`, `--source-dir`, `--version [major\|minor]`, `--dry-run` |
| `rollback` | Restore a prior deployment version | `--version VERSION`, `--confirm` |
| `versions` | List or inspect deployment history | `list`, `show VERSION`, `--limit`, `--json` |
| `validate` | Run pre-flight checks without changing AWS resources | `--domain` (required), `--subdomain`, `--region`, `--source-dir`, `--aws-profile`, `--json` |
| `status` | Registered command; current implementation is a placeholder | — |
| `destroy` | Registered command; current implementation is a placeholder | `--confirm` |

### Examples

```bash
./deploy.sh deploy --domain example.com --subdomain www
./deploy.sh update
./deploy.sh update --version major
./deploy.sh rollback --version previous
./deploy.sh versions list --limit 10
./deploy.sh versions show 20260710-120000
./deploy.sh validate --domain example.com
```

**Configuration Priority** (highest to lowest):
1. Command-line arguments (`--domain`, `--subdomain`, etc.)
2. Environment variables (`DEPLOY_DOMAIN`, `DEPLOY_SUBDOMAIN`, etc.)
3. `.deployrc` config file
4. Built-in defaults

---

## 📖 Full Documentation

- **[wiki/guide.md](wiki/guide.md)** — User guide with workflows, configuration, examples
- **[wiki/reference.md](wiki/reference.md)** — Technical reference: operations, performance, security, troubleshooting
- **[wiki/architecture.md](wiki/architecture.md)** — System design, deployment flow, state management
- **[wiki/deployments.md](wiki/deployments.md)** — Version manifest storage and multi-machine deployments

The deployment uses [cloud/s3-static-website-deploy.yaml](cloud/s3-static-website-deploy.yaml) for the real deploy/update flow, while [cloud/s3-static-website-validate.yaml](cloud/s3-static-website-validate.yaml) is used by the validation command. In practice: `./deploy.sh deploy` and `./deploy.sh update` use the deploy template, and `./deploy.sh validate` checks the validation template.

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
