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

## Deployment Flow: `./deploy.sh deploy`

```
1. Source lib modules
   └─ logging, common, config, aws-common, cloudformation, s3, ...

2. Load configuration
   └─ Merge .deployrc + environment variables + CLI args

3. Pre-flight validation
   └─ Check AWS credentials
   └─ Check Bash version (4.0+)
   └─ Scan for exposed secrets
   └─ Validate domain ownership

4. Create infrastructure via CloudFormation
   └─ Create S3 bucket with versioning
   └─ Create CloudFront distribution
   └─ Create Route 53 alias records
   └─ Create ACM certificate (if needed)

5. Upload website files
   └─ Find all files matching patterns
   └─ Exclude build/dev directories
   └─ Calculate SHA256 hash for each file
   └─ Upload to S3

6. Create version manifest
   └─ Generate manifest with all files + hashes
   └─ Store in deployments/1.0.0.json
   └─ Commit to git

7. Save deployment state
   └─ Write .deploy/state.json (local only)
   └─ Store CloudFormation stack ID
   └─ Store S3 bucket name, CloudFront dist ID

8. Invalidate cache
   └─ Invalidate CloudFront "/*" path
   └─ Wait for cache refresh (1-2 minutes)
```

---

## Update Flow: `./deploy.sh update`

```
1. Load configuration
   └─ .deployrc, environment variables, CLI args

2. Load previous version manifest
   └─ Read deployments/1.1.0.json
   └─ Extract all files + expected hashes

3. Scan current working directory
   └─ Find all files matching patterns
   └─ Calculate current SHA256 hashes

4. Detect changes
   └─ Compare current hashes vs manifest hashes
   └─ Build list of: new files, modified files, deleted files

5. Upload changed files only
   └─ Upload modified/new files to S3
   └─ Delete removed files from S3

6. Create new version manifest
   └─ Calculate new hashes
   └─ Store in deployments/1.1.1.json
   └─ Commit to git

7. Invalidate changed paths
   └─ Invalidate only changed files in CloudFront
   └─ More efficient than "/*" invalidation

8. Update state.json
   └─ Record new version
   └─ Update last_deployed timestamp
```

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
