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
2. **Bash 4.0+** – macOS: `brew install bash`
3. **Domain** – Route 53 hosted zone created for your domain

### Deploy Everything

```bash
./deploy.sh deploy --domain marcelrienks.com --subdomain www
```

**What happens automatically:**
- ✓ Creates S3 bucket with versioning
- ✓ Creates CloudFront CDN distribution  
- ✓ Creates Route 53 DNS alias records
- ✓ Requests ACM SSL/TLS certificate
- ✓ Uploads all website files
- ✓ Saves deployment state for future updates
- **Time:** ~6-8 minutes

### Update After Changes

```bash
./deploy.sh update
```

**What happens:**
- ✓ Detects only changed files
- ✓ Uploads changed files to S3
- ✓ Invalidates CloudFront cache
- **Time:** ~2-4 minutes, changes live in 1-2 min

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
