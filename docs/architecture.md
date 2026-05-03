# Architecture - System Design Overview

Overview of the deployment system architecture and how components interact.

---

## System Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ deploy.sh (Main Orchestrator)                                │
│ - Routes commands (deploy, update, rollback, etc.)           │
│ - Sources 19 lib modules in dependency order                 │
│ - Handles CLI arg parsing and config loading                 │
└──────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
   ┌─────────────┐    ┌─────────────┐    ┌──────────────────┐
   │ lib/ (19 modules)│    │ .deployrc │    │ deployments/    │
   ├─────────────┤    ├─────────────┤    ├──────────────────┤
   │ logging     │    │ config file │    │ 1.1.0.json       │
   │ common      │    │ domain      │    │ (tracked in git) │
   │ config      │    │ region      │    │                  │
   │ aws-common  │    │ aws_profile │    │ Contains:        │
   │ cloudform.. │    │             │    │ - file hashes    │
   │ s3          │    │             │    │ - file paths     │
   │ cloudfront  │    │             │    │ - file sizes     │
   │ route53     │    │             │    │ - version ID     │
   │ file-ops   │    │             │    │ - timestamp      │
   │ versioning │    │             │    │                  │
   │ validation │    │             │    │                  │
   │ state      │    │             │    │                  │
   │ deploy-cmd │    │             │    │                  │
   │ update-cmd │    │             │    │                  │
   │ rollback-cmd│    │             │    │                  │
   │ validate-cmd│    │             │    │                  │
   │ versions-cmd│    │             │    │                  │
   │ multi-sub  │    │             │    │                  │
   └─────────────┘    └─────────────┘    └──────────────────┘
        │                                         │
        │                                         │
        └──────────────────┬──────────────────────┘
                           ▼
        ┌──────────────────────────────────────┐
        │ AWS Services                         │
        ├──────────────────────────────────────┤
        │ • S3 (versioned storage)             │
        │ • CloudFront (CDN + cache)           │
        │ • Route 53 (DNS)                     │
        │ • CloudFormation (infrastructure)    │
        │ • ACM (SSL certificates)             │
        │ • CloudTrail (audit logs)            │
        └──────────────────────────────────────┘
```

---

**See [reference.md](reference.md) for detailed deployment and update commands.**

---

## State Management

### Tracked in Git (`deployments/`)
- ✅ Version manifests (1.0.0.json, 1.1.0.json, etc.)
- ✅ Deployment history
- ✅ File hashes for change detection

### Local Only (`.deploy/` not tracked)
- ❌ state.json (machine-specific timestamps)
- ❌ Cached version files (for performance)
- ❌ Deployment logs

This separation ensures:
- Team members can deploy with consistent manifests
- Each machine has independent state
- Git history stays clean
- CI/CD can read manifests

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| **CloudFormation only** | AWS-native, no vendor lock-in to Terraform/Ansible |
| **Manifests in git** | Enable multi-machine deployments, CI/CD integration |
| **SHA256 hashing** | Fast, reliable change detection; impossible hash collisions |
| **S3 versioning** | Instant rollback without re-uploading all files |
| **CloudFront cache invalidation** | Live changes in 1-2 minutes (typical) |
| **State in .deploy/** | Local timestamps prevent unnecessary cache refreshes |
| **19 modular lib files** | Each module has single responsibility, easy to test/debug |
