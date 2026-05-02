# Performance Analysis: AWS Static Website Deployment

**Date**: 2026-05-02  
**Version**: 1.0  
**Focus**: MVP (Phase 3 & 4) performance targets

---

## Performance Targets

- **Initial deployment**: <10 minutes
- **Content updates**: <5 minutes
- **Asset load time (P95)**: <1 second via CloudFront

---

## Phase 3: Initial Deployment

### Time Breakdown

| Component | Time | Notes |
|-----------|------|-------|
| Pre-flight validation | 30s | Credentials, IAM, domain |
| CloudFormation stack | 3-5min | S3, CloudFront, Route53, ACM |
| File inventory | 10-20s | Hashing |
| Parallel upload (5 batches) | 1-2min | ~50 files typical |
| CloudFront invalidation | 1-2min | Cache refresh |
| Health checks | 30s | HTTPS, DNS, assets |
| **Total** | **~6-8 min** | Typical |

### Upload Strategy: Batches of 5

Design: 5 concurrent uploads = optimal throughput without connection exhaustion (HTTP limit: 6-8 per domain, S3 has no hard limit).

Retry: 3 attempts with exponential backoff (2s, 4s, 8s) covers 99%+ of transient failures.

Resume: Checkpoint system (`.deploy/last-upload-state.json`) enables recovery from network failures without re-uploading completed files.

---

## Phase 4: Content Updates

### Time Breakdown

| Component | Time | Notes |
|-----------|------|-------|
| Load version manifest | 5s | S3 or local cache |
| Scan files & compute hashes | 10s | SHA256, only changed |
| Diff vs S3 | 10s | Metadata queries |
| Upload changed | 30-60s | Typically 2-5 files |
| CloudFront invalidation | 1-2min | Selective paths |
| Health checks | 20s | Verification |
| **Total** | **~2-4 min** | Typical |

### Change Detection

Hash-based: Compares local SHA256 vs manifest hashes. Detects: added (new hash), modified (hash changed), deleted (in manifest, not local).

Selective Invalidation: <100 files → specific paths (fast). >100 files → wildcard (simpler). Both complete <5 min.

---

## MVP Scaling Limits

**File size**: Typical <50MB total. Multipart upload (Phase 5+) for >100MB.

**File count**: Practical <500 files. Batch uploads (Phase 5+) for >5k files.

**Deployment**: Single deployment at a time (lock file). Concurrent deployments need queuing (Phase 6+).

---

## See Also

- [operations.md](operations.md) - Deployment commands, monitoring, troubleshooting
- [security.md](security.md) - Security best practices and hardening
