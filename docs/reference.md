# Reference - Technical Details

Technical reference for operations, performance, security, and troubleshooting.

---

## Operations & Monitoring

### Deployment Commands

```bash
# Initial deployment
./deploy.sh deploy \
  --domain example.com \
  --subdomain www \
  --region us-east-1 \
  --source-dir ./website

# Content update
./deploy.sh update

# Dry-run (test without changes)
./deploy.sh deploy --dry-run

# Multi-subdomain deployment
./deploy.sh deploy \
  --domain example.com \
  --subdomains www,blog,docs \
  --source-dir ./website
```

### Version Management

```bash
# List versions
./deploy.sh versions list
./deploy.sh versions list --limit 50 --json

# Show specific version
./deploy.sh versions --show 20260502-143022

# Rollback to version
./deploy.sh rollback --version 20260502-143022
./deploy.sh rollback --version 20260502-143022 --confirm

# Rollback to previous
./deploy.sh rollback
```

### Validation

```bash
./deploy.sh validate --domain example.com
./deploy.sh validate --domain example.com --json
./deploy.sh validate --dry-run
```

### Monitoring CloudFormation

```bash
# Check stack status
aws cloudformation describe-stacks \
  --stack-name identity \
  --query 'Stacks[0].StackStatus'

# View stack events
aws cloudformation describe-stack-events \
  --stack-name identity \
  --max-results 20

# List all stacks
aws cloudformation list-stacks
```

### CloudFront Cache Invalidation

```bash
# List invalidations
aws cloudfront list-invalidations --distribution-id D123ABC456

# Get invalidation status
aws cloudfront get-invalidation \
  --distribution-id D123ABC456 \
  --id I1ABC2D3E4F5

# Manual cache clear (if needed)
aws cloudfront create-invalidation \
  --distribution-id D123ABC456 \
  --paths "/*"
```

---

## File Patterns

### ✓ Included by Default

- `.html` files
- `.css` stylesheets
- `.js` scripts
- `.json` data files
- `.jpg`, `.png`, `.svg`, `.webp`, `.gif` images
- `.ico` favicon
- `.woff`, `.woff2`, `.ttf`, `.otf` fonts

### ✗ Excluded by Default

- `node_modules/` directory
- `.git/` and `.gitignore`
- `.env*` files (security)
- `*.key` and `*.pem` files (security)
- `.DS_Store`, `*.tmp` (OS/temp files)
- Anything in your `.gitignore`

### Customize Patterns

```yaml
# In .deployrc
include_patterns:
  - "*.html"
  - "*.custom-format"

exclude_patterns:
  - "vendor/"
  - "*.map"
  - "secret*"
```

---

## Performance Metrics

### Speed Summary

- **Deploy time:** 6-8 minutes (first time, infrastructure creation)
- **Update time:** 2-4 minutes (changed files only)
- **Cache refresh:** 1-2 minutes globally
- **Content delivery:** <100ms from nearest edge location

### AWS Costs

| Service | Cost | Notes |
|---------|------|-------|
| S3 Storage | ~$0.02/month | Small portfolio |
| CloudFront | ~$0.09/GB | Minimal for portfolio |
| Route 53 | $0.50/month | Per hosted zone |
| ACM Certificate | FREE | Auto-renewal |
| **Total** | **~$1-5/month** | Typical |

### Initial Deployment Timing

| Component | Time | Notes |
|-----------|------|-------|
| Pre-flight validation | 30s | Credentials, IAM, domain validation |
| CloudFormation stack | 3-5min | S3, CloudFront, Route53, ACM creation |
| File inventory | 10-20s | Directory scan, SHA256 hashing |
| Parallel upload (5 batches) | 1-2min | ~50 files typical, 5 concurrent |
| CloudFront invalidation | 1-2min | Cache refresh |
| Health checks | 30s | HTTPS, DNS, asset delivery |
| **Total** | **~6-8 min** | Typical |

### Content Update Timing

| Component | Time | Notes |
|-----------|------|-------|
| Load version manifest | 5s | S3 or local cache |
| Scan files & compute hashes | 10s | SHA256, only changed files |
| Diff vs S3 | 10s | Object metadata queries |
| Upload changed | 30-60s | Typically 2-5 files |
| CloudFront invalidation | 1-2min | Selective paths |
| Health checks | 20s | Verification |
| **Total** | **~2-4 min** | Typical |

### Upload Strategy

- **Batch size:** 5 concurrent uploads
- **Rationale:** Optimal throughput without HTTP connection exhaustion (limit 6-8 per domain)
- **Retry:** 3 attempts with exponential backoff (2s, 4s, 8s) covers 99%+ of transient failures
- **Resume:** Checkpoint system (`.deploy/last-upload-state.json`) enables recovery from network failures

### Change Detection

- **Method:** Hash-based (SHA256 comparison)
- **Detection:** Added (new hash), Modified (hash changed), Deleted (in manifest, not local)
- **Selective invalidation:** <100 files → specific paths (fast), >100 files → wildcard (simpler)

---

## Scaling Limits (MVP)

| Limit | Value | Solution |
|-------|-------|----------|
| File size | <50MB total | Multipart upload (Phase 5+) for >100MB |
| File count | <500 files | Batch uploads (Phase 5+) for >5k files |
| Concurrent deployments | 1 at a time | Lock file system, queue for Phase 6+ |
| Subdomain count | <10 recommended | CloudFront has no hard limit |

---

## Security - Credential Handling

### ✅ Best Practices

**AWS IAM Roles** (Production - Recommended)
```bash
# EC2 instance with attached role
# GitHub Actions with OIDC provider
# ECS task with execution role
# Lambda with execution role
```

**Environment Variables** (Local development)
```bash
export AWS_PROFILE=my-profile
./deploy.sh deploy --domain example.com
```

**AWS Credentials File** (`~/.aws/credentials`)
```bash
[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/...

[staging]
aws_access_key_id = AKIA...
aws_secret_access_key = ...

[production]
aws_access_key_id = AKIA...
aws_secret_access_key = ...
```

### ⚠️ Never Do

❌ Commit `.aws/credentials` to Git  
❌ Hardcode AccessKey/SecretKey in scripts  
❌ Share credentials in Slack/email/GitHub  
❌ Store credentials in `.deployrc`  
❌ Upload credential files to S3  

### 🔐 Secrets Scanning

Deployment auto-scans files before upload. Detected patterns:
- `*.pem`, `*.key`, `*.pkcs12`, `*.p12`, `*.pfx` (private keys)
- `.env*` files
- Lines containing: `password`, `api_key`, `secret`, `token`, `credential`
- AWS access key pattern: `AKIA[0-9A-Z]{16}`

**If detected:** Deployment STOPS. Fix by removing file or adding to `.deployignore`.

---

## S3 Security Configuration

### ✅ Default Protections (Auto-enabled)

| Setting | Value | Purpose |
|---------|-------|---------|
| Public Access Block | ENABLED | Prevents accidental public exposure |
| Versioning | ENABLED | Enables rollback to any version |
| Encryption | AWS-managed | Objects encrypted at rest (AES-256) |
| Logging | Optional | S3 access logs to audit bucket |
| Block public ACLs | YES | Prevents public ACL grants |
| Ignore public ACLs | YES | Ignores existing public ACLs |
| Block public policy | YES | Blocks public bucket policies |
| Restrict public buckets | YES | Limits public access |

### Access Control: Origin Access Control (OAC)

```
S3 Bucket (Private)
  ↓ (OAC signature)
CloudFront Distribution (Public)
  ↓ (HTTPS)
End Users
```

**How it works:**
- S3 bucket completely private (no public access)
- Only CloudFront can access via OAC
- Users cannot bypass CloudFront
- All traffic forced to HTTPS
- Direct S3 URLs return 403 Forbidden

---

## HTTPS/TLS Security

### ✅ Default Protections

- **HTTP → HTTPS:** Automatic redirect, all traffic encrypted
- **TLS 1.2+:** Enforced, no insecure protocols
- **ACM Certificate:** Auto-provisioned in CloudFormation
- **Auto-renewal:** 30 days before expiration
- **DNS Validation:** Automatic via Route53

### Certificate Requirements

- Domain must have Route53 hosted zone
- DNS accessible for ACM validation
- Provisioning: 5-15 minutes typical
- Auto-renewal: 30 days before expiry

---

## IAM Permissions - Least Privilege

### Minimum Required Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3StaticSite",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning",
        "s3:GetObjectVersion"
      ],
      "Resource": [
        "arn:aws:s3:::website-*-static",
        "arn:aws:s3:::website-*-static/*"
      ]
    },
    {
      "Sid": "CloudFormationStack",
      "Effect": "Allow",
      "Action": [
        "cloudformation:CreateStack",
        "cloudformation:UpdateStack",
        "cloudformation:DeleteStack",
        "cloudformation:DescribeStacks",
        "cloudformation:ListStackEvents",
        "cloudformation:GetTemplate"
      ],
      "Resource": "arn:aws:cloudformation:*:*:stack/website-*/*"
    },
    {
      "Sid": "CloudFrontCDN",
      "Effect": "Allow",
      "Action": [
        "cloudfront:CreateInvalidation",
        "cloudfront:GetDistribution",
        "cloudfront:ListDistributions"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Route53DNS",
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:GetHostedZone",
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/*"
    },
    {
      "Sid": "ACMCertificate",
      "Effect": "Allow",
      "Action": [
        "acm:RequestCertificate",
        "acm:DescribeCertificate",
        "acm:ListCertificates"
      ],
      "Resource": "arn:aws:acm:*:*:certificate/*"
    },
    {
      "Sid": "IAMPassRole",
      "Effect": "Allow",
      "Action": ["iam:PassRole"],
      "Resource": "arn:aws:iam::*:role/*",
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "cloudformation.amazonaws.com"
        }
      }
    }
  ]
}
```

### Verify Permissions

```bash
# Validate configuration first
./deploy.sh deploy --domain example.com --dry-run

# Simulate policy
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/deploy-role \
  --action-names s3:PutObject cloudformation:CreateStack cloudfront:CreateInvalidation
```

---

## Audit Logging & CloudTrail

### Enable CloudTrail

```bash
aws cloudtrail create-trail \
  --name deployment-trail \
  --s3-bucket-name audit-logs \
  --include-global-service-events

aws cloudtrail start-logging --trail-name deployment-trail
```

### CloudTrail Captures

- CloudFormation operations (stack creation/updates)
- S3 uploads/deletions
- Route53 DNS changes
- ACM certificate requests
- CloudFront invalidations
- IAM role usage

### View Logs

```bash
# CloudFormation events
aws cloudformation describe-stack-events \
  --stack-name identity

# CloudTrail events
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=example.com
```

---

## Network Security

### ✅ Default Protections

- **HTTPS/TLS Only:** All traffic encrypted
- **No Direct S3:** Only accessible via CloudFront
- **DDoS Protection:** Free at CloudFront edge (AWS Shield Standard)

### Optional: AWS Shield Advanced

- Cost: $3,000/month
- Includes: Dedicated support + cost protection guarantee
- Use for: High-traffic websites needing guaranteed DDoS protection

---

## Safe Configuration Pattern

### ✓ Safe in .deployrc

```yaml
domain: example.com
region: us-east-1
source_dir: ./website
aws_profile: production
cache_default_ttl: 86400
verbose: false
```

### ✗ Never in .deployrc

```yaml
# NEVER include these:
aws_access_key_id: AKIA...
aws_secret_access_key: ...
password: secret123
api_token: token_xyz
```

---

## Troubleshooting

### CloudFormation Timeout

**Cause:** ACM certificate validation, Route53 permissions, or S3 bucket naming conflict  
**Fix:** Check stack events with `aws cloudformation describe-stack-events`. Retry with same command (idempotent).

### File Upload Fails

**Cause:** Network issues, AWS service interruption, or invalid IAM permissions  
**Fix:** Resume operation; checkpoint system auto-detects completed uploads. Verify network: `curl -I https://s3.amazonaws.com`

### CloudFront Cache Not Updating

**Cause:** Invalidation not complete or CloudFront serving stale cache  
**Fix:** Verify invalidation status: `aws cloudfront list-invalidations --distribution-id D123ABC456`. Usually completes within 1-2 minutes.

### Domain Validation Fails

**Valid formats:** `example.com`, `www.example.com`  
**Invalid formats:** `example` (no TLD), `.com` (no domain), `example.com.` (trailing dot)  
**Fix:** Check domain format in CLI args or .deployrc

### No Route53 Zone Found

**Cause:** Hosted zone doesn't exist or credentials lack permissions  
**Fix:** Create zone: `aws route53 create-hosted-zone --name example.com --caller-reference $(date +%s)`  
Update domain registrar DNS servers to Route53 nameservers.

### ACM Certificate Timeout

**Cause:** DNS validation not completed  
**Fix:** Certificate validation runs in background (5-15 min typical). Check status: `aws acm describe-certificate --certificate-arn arn:...`

### Permission Denied Errors

**Cause:** IAM policy missing required actions or resources  
**Fix:** Run `./deploy.sh validate` to identify missing permissions. Compare IAM policy with reference in this document.

---

## See Also

- [guide.md](guide.md) - User guide with examples and workflows
