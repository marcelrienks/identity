# Quick Reference

Essential commands — for details see [reference.md](reference.md).

---

## Commands (One-Liners)

```bash
./deploy.sh deploy --domain marcelrienks.com          # Deploy everything
./deploy.sh update                                     # Update + bump minor (1.1.0 → 1.2.0)
./deploy.sh update --version major                     # Update + bump major (1.1.0 → 2.0.0)
./deploy.sh versions list                              # View history
./deploy.sh rollback --version 1.0.0                   # Rollback
./deploy.sh validate --dry-run                         # Test (no changes)
./deploy.sh help                                       # Show help
```

---

## Project Layout

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
│   ├── quickref.md              ← Quick reference
│   ├── reference.md             ← Technical reference
│   ├── architecture.md          ← System design
│   └── deployments.md           ← Manifest storage
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

## FAQ

| Q | A |
|---|---|
| How do I deploy? | `./deploy.sh deploy --domain marcelrienks.com` |
| Update after changes? | `./deploy.sh update` |
| Undo a deployment? | `./deploy.sh rollback --version 1.0.0` |
| See manifests? | `deployments/1.1.0.json` |
| Deploy from another machine? | Clone → manifests in git → `./deploy.sh update` |
| How long? | Deploy: 6-8 min, Update: 2-4 min, Live: 1-2 min |
| Credentials? | `aws configure` or `export AWS_PROFILE=my-profile` |
| Bash version? | Need 4.0+. macOS: `brew install bash` |
| Cache not updating? | Takes 1-2 minutes. Force refresh: `Cmd+Shift+R` |

---

## Docs

| Doc | Purpose |
|---|---|
| [../README.md](../README.md) | Project overview |
| [guide.md](guide.md) | Workflows & configuration |
| [reference.md](reference.md) | Commands, operations, performance, security |
| [architecture.md](architecture.md) | System design & decisions |
| [deployments.md](deployments.md) | Manifest storage & multi-machine |

See [reference.md](reference.md) for detailed command reference and troubleshooting.
