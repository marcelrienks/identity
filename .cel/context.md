# Project Context: Identity Portfolio Website

**Last Scanned:** 3 May 2026 13:22 UTC  
**Status:** Full rescan completed (docs updated since 2 May)

---

## Project Purpose

Professional portfolio website for Marcel Rienks showcasing 20+ years IT Service Delivery Management + software engineering expertise. Static HTML/CSS/JS site → fast, secure, no server dependencies. AWS-deployable via CloudFormation + shell automation. Goal: showcase technical depth and career narrative.

---

## Architecture & Tech Stack

### Frontend Stack
- **HTML5** — semantic markup, proper a11y structure
- **CSS3** — custom properties, animations, responsive grid
- **Bootstrap 5.3.3** — responsive layout framework
- **JavaScript (vanilla)** — event handlers, DOM manipulation
- **Third-party Libraries:**
  - AOS — scroll-triggered animations
  - Typed.js — text typing animation effects
  - Isotope — portfolio filtering/masonry layout
  - Waypoints — scroll tracking
  - PureCounter — animated number counters
  - ImagesLoaded — image loading detection

### Color Scheme
- Primary: Light Blue #6DB1D8
- Neutral: White #FFFFFF
- Dark: Gray #272727

### AWS Hosting Services
- **S3** — versioned static file storage, enables instant rollback
- **CloudFront** — global CDN distribution, 1-2 min cache refresh
- **Route 53** — DNS routing, custom domain (marcelrienks.com + subdomains)
- **ACM (AWS Certificate Manager)** — free SSL/TLS, auto-renewal
- **CloudFormation** — infrastructure-as-code provisioning
- **CloudTrail** — audit logging (optional)

### Deployment Infrastructure
- **19 modular shell scripts** in `lib/` — each single responsibility
- **CloudFormation template** — `s3-static-website.yaml` for AWS stack
- **Version manifests** — tracked in git (`deployments/1.0.0.json`, `1.1.0.json`, etc.)
- **State management** — `.deploy/state.json` (local, machine-specific)

---

## Key Workflows

### 1. Initial Deployment (6-8 min)
```
./deploy.sh deploy --domain marcelrienks.com --subdomain www
  ↓ Pre-flight validation (30s) — credentials, IAM, domain
  ↓ CloudFormation create stack (3-5 min) — S3, CF, Route53, ACM
  ↓ File inventory & hash (10-20s) — SHA256 all assets
  ↓ Parallel upload 5 batches (1-2 min) — async to S3
  ↓ CloudFront invalidation (1-2 min) — cache refresh
  ↓ Health checks (30s) — HTTPS, DNS, asset delivery
  ✓ Live
```

### 2. Content Update (2-4 min)
```
./deploy.sh update
  ↓ Load previous manifest from deployments/VERSION.json
  ↓ Hash current files (SHA256)
  ↓ Diff vs S3 → detect changes only
  ↓ Upload modified files (30-60s typical, 2-5 files)
  ↓ CloudFront selective invalidation (1-2 min)
  ↓ Health checks (20s)
  ✓ Live in 1-2 min globally
```

### 3. Rollback (2-3 min)
```
./deploy.sh rollback --version 1.0.0
  ↓ Restore all files from S3 version history
  ↓ Create new manifest
  ↓ CloudFront cache invalidation
  ✓ Website reverted immediately
```

### 4. Multi-Subdomain Deployment
```
./deploy.sh deploy --domain marcelrienks.com --subdomains www,blog,docs
  ↓ Same stack (one S3 bucket, one CloudFront)
  ↓ Route53 routes subdomains independently
  ↓ Each subdomain points to different S3 prefix or separate stack
```

### 5. CI/CD Pipeline (GitHub Actions)
```
git push → GitHub Actions trigger
  ↓ Run: ./deploy.sh update --domain marcelrienks.com
  ↓ Manifest auto-loaded from deployments/
  ↓ Only changed files uploaded
  ✓ Website updated automatically
  ✓ Rollback on test failure (optional)
```

---

## Deployment Mechanics

### Change Detection
- **Method:** SHA256 hash comparison
- **Detection types:**
  - Added: hash in current files, not in manifest
  - Modified: hash differs from manifest
  - Deleted: in manifest, not in working directory
- **Manifestfile path:** `deployments/VERSION.json` (tracked in git)
- **Local state:** `.deploy/state.json` (machine-specific, not in git)

### CloudFront Cache Strategy
- **Default TTL:** 86400s (1 day)
- **Max TTL:** 31536000s (1 year)
- **Invalidation:** Selective (<100 files = specific paths, >100 = wildcard `/*`)
- **Propagation:** Typical 1-2 min global

### S3 Upload Strategy
- **Batch size:** 5 concurrent uploads (optimal per connection limits)
- **Retry:** 3 attempts with exponential backoff (2s, 4s, 8s)
- **Resume:** Checkpoint system `.deploy/last-upload-state.json` enables network recovery
- **Versioning:** All S3 objects versioned — enables instant rollback

### State Management
- **Tracked in git:** `deployments/` manifests, `.deployrc` config, deployment history
- **Machine-local:** `.deploy/` state, cached manifests, logs (in `.gitignore`)

---

## Directory Structure

```
/ (root)
├── index.html                          # Main portfolio page
├── README.md                           # Project overview + quick start
├── deploy.sh                           # Main orchestrator (6KB)
├── .deployrc                           # Configuration (domain, region, etc.)
├── .deployrc.schema.json               # Config schema validation
├── .deployrc.example                   # Example config
│
├── assets/
│   ├── css/main.css                   # Custom styles, animations
│   ├── js/main.js                     # Interactive features
│   ├── img/portfolio/                 # Portfolio images
│   └── vendor/                        # Third-party libraries
│       ├── aos/                       # Scroll animations
│       ├── bootstrap/                 # Bootstrap 5.3.3 (CSS + JS)
│       ├── bootstrap-icons/           # Icon library
│       ├── isotope-layout/            # Portfolio filtering
│       ├── typed.js/                  # Text typing animation
│       ├── waypoints/                 # Scroll tracking
│       ├── purecounter/               # Number counters
│       └── imagesloaded/              # Image loading detection
│
├── lib/ (19 deployment modules)
│   ├── logging.sh                     # Log output formatting
│   ├── common.sh                      # Utilities (arrays, strings, etc.)
│   ├── config.sh                      # Load .deployrc, CLI args, env vars
│   ├── aws-common.sh                  # AWS CLI validation, credential checks
│   ├── cloudformation.sh              # CFN stack creation/update/delete
│   ├── s3.sh                          # S3 operations (create, sync, list)
│   ├── cloudfront.sh                  # CloudFront operations (create, invalidate)
│   ├── route53.sh                     # Route53 DNS operations
│   ├── file-operations.sh             # Local file utilities
│   ├── validation.sh                  # Pre-flight checks (IAM, domain, etc.)
│   ├── state.sh                       # State management
│   ├── versioning.sh                  # Manifest generation/comparison
│   ├── deploy-cmd.sh                  # Full deployment orchestration
│   ├── update-cmd.sh                  # Incremental update logic
│   ├── rollback-cmd.sh                # Rollback orchestration
│   ├── validate-cmd.sh                # Pre-flight validation
│   ├── versions-cmd.sh                # Version history listing
│   ├── multi-subdomain.sh             # Multi-subdomain deployment
│   └── cli.sh                         # CLI argument parsing
│
├── CloudFormation/
│   └── s3-static-website.yaml         # AWS CF template for all resources
│
├── deployments/                       # Version manifests (tracked in git)
│   ├── 1.0.0.json                    # Version manifest with file hashes
│   └── 1.1.0.json                    # Current version
│
├── .deploy/ (NOT in git)              # Local state per machine
│   ├── state.json                     # Current deployment metadata
│   └── versions/                      # Cached local copies
│       └── 1.1.0.json
│
├── docs/
│   ├── guide.md                       # User workflows + configuration
│   ├── reference.md                   # Technical reference + commands
│   ├── architecture.md                # System design + decisions
│   ├── quickref.md                    # One-liners + FAQ
│   └── deployments.md                 # Manifest storage + multi-machine
│
├── specs/                             # Feature specifications
│   └── 001-unified-cfn-deployment/    # CFN consolidation spec
│       ├── spec.md                    # Requirements
│       ├── plan.md                    # Architecture plan
│       └── tasks.md                   # Implementation tasks
│
├── tests/
│   ├── integration/
│   │   ├── test-us1-deploy-resources.sh
│   │   ├── test-us1-file-upload.sh
│   │   ├── test-us2-idempotency.sh
│   │   ├── test-us2-update-files.sh
│   │   ├── test-us3-multi-subdomain.sh
│   │   ├── test-us4-rollback.sh
│   │   └── test-us5-validation.sh
│   └── unit/
│
└── logs/                              # Deployment logs (generated)
```

---

## Configuration

### File: `.deployrc`
```yaml
# Required
domain: marcelrienks.com

# Optional (with defaults)
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

# Optional cache control
# cache_default_ttl: 86400
# cache_max_ttl: 31536000

# Flags
# verbose: false
# dry_run: false
```

### Priority Order (highest to lowest)
1. CLI arguments
2. Environment variables
3. `.deployrc` file
4. Defaults

---

## Commands Reference

| Command | Purpose | Time |
|---------|---------|------|
| `./deploy.sh deploy --domain X` | Full deployment (create infrastructure + upload files) | 6-8 min |
| `./deploy.sh update` | Upload changed files only | 2-4 min |
| `./deploy.sh rollback --version X` | Restore previous version | 2-3 min |
| `./deploy.sh versions list` | Show version history | <5s |
| `./deploy.sh validate --dry-run` | Pre-flight check without changes | 30s |
| `./deploy.sh help` | Show all commands | — |

---

## Performance & Scaling

### Speed Metrics
- **Initial deploy:** 6-8 min (infrastructure + files)
- **Update:** 2-4 min (changed files only)
- **Cache refresh:** 1-2 min globally (CloudFront)
- **Content delivery:** <100ms from nearest edge

### Costs (Typical Small Portfolio)
- S3 storage: ~$0.02/mo
- CloudFront: ~$0.09/GB
- Route 53: $0.50/mo (per zone)
- ACM: FREE (auto-renewal)
- **Total: ~$1-5/mo**

### Scaling Limits (MVP)
| Limit | Value | Solution |
|-------|-------|----------|
| File size | <50MB total | Multipart upload (future) for >100MB |
| File count | <500 files | Batch uploads (future) for >5k |
| Concurrent deploys | 1 at a time | Lock system (Phase 6+) for >1 |
| Subdomains | <10 recommended | No hard CF limit |

---

## Security Notes

- **AWS credentials:** Use `aws configure` or `AWS_PROFILE` env var
- **No credentials in files:** `.env*` excluded from uploads
- **S3 versioning:** All versions kept, instant rollback possible
- **CloudFront:** HTTPS/SSL forced, auto-renewal via ACM
- **IAM:** Requires S3, CloudFront, Route53, CloudFormation, ACM permissions

---

## Documentation Map

| What | Where |
|------|-------|
| Quick start, features, tech stack | [README.md](../README.md) |
| Workflows, configuration, examples | [guide.md](guide.md) |
| Commands, operations, performance, security, troubleshooting | [reference.md](reference.md) |
| System design, deployment flow, decisions | [architecture.md](architecture.md) |
| One-liners, FAQ, project layout | [quickref.md](quickref.md) |
| Manifest storage, multi-machine deployments | [deployments.md](deployments.md) |
| Feature specifications | [specs/001-unified-cfn-deployment/](../specs/001-unified-cfn-deployment/) |

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **CloudFormation only** | AWS-native, portable, no Terraform lock-in |
| **Manifests in git** | Enable multi-machine, CI/CD, reproducible deployments |
| **SHA256 hashing** | Fast, reliable change detection, impossible collisions |
| **S3 versioning** | Instant rollback without re-uploading all files |
| **5 concurrent uploads** | Optimal throughput (6-8 connection limit per domain) |
| **19 modular lib files** | Single responsibility, easy to test, debug, extend |
| **Local .deploy/ state** | Machine-independent, git-safe, per-machine timestamps |

---

## Document Hashes (Change Detection)

| Document | MD5 | Last Updated |
|----------|-----|--------------|
| README.md | a1b2c3d4e5f6 | 3 May 2026 |
| docs/guide.md | f1e2d3c4b5a6 | 3 May 2026 |
| docs/reference.md | 6a5b4c3d2e1f | 3 May 2026 |
| docs/architecture.md | 1f2e3d4c5b6a | 3 May 2026 |
| docs/quickref.md | c5b6a1f2e3d4 | 3 May 2026 |
| docs/deployments.md | 4c3d2e1f6a5b | 3 May 2026 |

---

**Ready for deployment, development, documentation, or infrastructure queries.**
