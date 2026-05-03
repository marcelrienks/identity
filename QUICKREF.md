# Quick Reference

Essential commands and file locations.

---

## Commands

```bash
# Deploy everything (first time setup)
./deploy.sh deploy --domain marcelrienks.com --subdomain www

# Update after changes (detects changed files automatically)
./deploy.sh update

# View deployment history
./deploy.sh versions list

# Rollback to previous version
./deploy.sh rollback

# Validate configuration
./deploy.sh validate --dry-run

# Get help
./deploy.sh help
```

---

## Project Structure

```
├── index.html                    ← Main website
├── assets/                       ← Styles, scripts, images
│   ├── css/main.css
│   ├── js/main.js
│   └── vendor/                   ← Bootstrap, AOS, Typed.js, etc.
├── .deployrc                     ← Configuration (domain, region, etc.)
├── deploy.sh                     ← Main orchestrator (6KB)
├── lib/                          ← 19 deployment modules
│   ├── logging.sh               ← Log output
│   ├── common.sh                ← Common utilities
│   ├── config.sh                ← Configuration loading
│   ├── aws-common.sh            ← AWS CLI validation
│   ├── cloudformation.sh        ← CloudFormation operations
│   ├── s3.sh                    ← S3 bucket operations
│   ├── cloudfront.sh            ← CloudFront CDN operations
│   ├── route53.sh               ← Route 53 DNS operations
│   ├── versioning.sh            ← Manifest generation
│   ├── deploy-cmd.sh            ← Full deployment logic
│   ├── update-cmd.sh            ← Incremental updates
│   ├── rollback-cmd.sh          ← Rollback operations
│   ├── validate-cmd.sh          ← Pre-flight validation
│   ├── versions-cmd.sh          ← Version history
│   └── ...                      ← Other modules
├── deployments/                 ← Version manifests (tracked in git)
│   ├── 1.0.0.json
│   └── 1.1.0.json               ← Current version
├── .deploy/                     ← Local state (NOT in git)
│   ├── state.json               ← Current deployment metadata
│   └── versions/                ← Cached copies (for speed)
├── docs/                        ← Documentation
│   ├── guide.md                 ← User guide
│   ├── reference.md             ← Technical reference
│   ├── architecture.md          ← System design
│   ├── deployments.md           ← Manifest storage
│   ├── operations.md            ← AWS operations
│   ├── performance.md           ← Timing & metrics
│   └── security.md              ← Security best practices
├── specs/                       ← Feature specifications
│   └── 001-unified-cfn-deployment/
│       ├── spec.md              ← Requirements
│       ├── plan.md              ← Architecture
│       └── tasks.md             ← Implementation tasks
└── tests/                       ← Integration tests
    ├── integration/
    └── unit/
```

---

## Common Questions

**Q: How do I deploy?**
```bash
./deploy.sh deploy --domain marcelrienks.com
```

**Q: How do I update after changing index.html?**
```bash
./deploy.sh update
```

**Q: How do I know what changed?**
```bash
./deploy.sh update --verbose
# Shows which files changed
```

**Q: Can I undo a deployment?**
```bash
./deploy.sh rollback --version 1.0.0
```

**Q: Where are my manifests stored?**
```
deployments/1.1.0.json  ← Contains file hashes and paths
```

**Q: How do I deploy from another machine?**
```bash
# On machine B:
git clone https://github.com/marcelrienks/identity.git
cd identity
./deploy.sh update
# Reads manifest from deployments/1.1.0.json automatically
```

**Q: How long does deployment take?**
- Full deploy (`./deploy.sh deploy`): **6-8 minutes**
- Update (`./deploy.sh update`): **2-4 minutes**
- Changes live in CloudFront: **1-2 minutes**

---

## Important Files

| File | Purpose |
|---|---|
| `deploy.sh` | Entry point — routes commands |
| `.deployrc` | Configuration (domain, region, AWS profile) |
| `deployments/` | Version manifests (tracked in git) |
| `.deploy/state.json` | Current deployment state (local, not in git) |
| `docs/guide.md` | Complete user guide |
| `docs/reference.md` | Technical details |

---

## Environment Variables

Override without editing `.deployrc`:

```bash
# AWS profile
export AWS_PROFILE=my-profile

# Domain
export DEPLOY_DOMAIN=example.com

# Region  
export DEPLOY_REGION=us-west-2

# Then deploy
./deploy.sh update
```

---

## Troubleshooting

**Q: "No changes detected"**
- File hashes haven't changed
- Solution: Make an actual change to a file

**Q: "AWS credentials not found"**
- Run: `aws configure`
- Set `AWS_PROFILE` or `AWS_ACCESS_KEY_ID` environment variable

**Q: "Bash version too old"**
- Need Bash 4.0+
- macOS: `brew install bash`

**Q: "CloudFront cache still showing old content"**
- Cache invalidation takes 1-2 minutes
- Force refresh browser: `Cmd+Shift+R` (macOS) or `Ctrl+Shift+F5` (Windows/Linux)

See [docs/reference.md](docs/reference.md) for full troubleshooting guide.
