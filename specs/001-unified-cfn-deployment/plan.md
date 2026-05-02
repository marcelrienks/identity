# Implementation Plan: AWS Static Website with Unified CloudFormation Deployment

**Branch**: `001-aws-static-website-cfn` | **Date**: 2026-05-02 | **Spec**: [aws-static-website-cfn-deployment.md](../aws-static-website-cfn-deployment.md)

**Input**: Feature specification for unified CloudFormation deployment of static websites to AWS S3 with CloudFront CDN and Route 53 DNS integration, including infrastructure provisioning and content update capabilities.

## Summary

This feature enables DevOps engineers to provision production-ready static website infrastructure on AWS via a single unified deployment script. The system provides two critical capabilities: (1) **initial provisioning** that creates S3 storage, CloudFront CDN distribution, Route 53 DNS records, and deploys initial website content via CloudFormation, and (2) **content updates** that allow rapid publication of modified files without rebuilding infrastructure. Both operations use the same script (`./deploy.sh`) with simple `deploy` and `update` commands, achieving complete infrastructure-as-code practices with zero manual AWS console steps required.

The technical approach emphasizes idempotency (safe re-execution), security by default (private S3 buckets, HTTPS/TLS enforced), and operational simplicity. CloudFormation serves as the exclusive infrastructure provisioning tool, while Bash orchestration handles file uploads, cache invalidation, and version management.

## Technical Context

**Language/Version**: Bash 4.0+ (macOS/Linux) | AWS CLI v2  
**Primary Dependencies**: AWS CloudFormation, AWS S3 API, AWS CloudFront API, AWS Route 53 API, AWS ACM  
**Supporting Tools**: jq (JSON parsing), curl/wget (health checks), Git (optional, version tracking)  
**Storage**: AWS S3 (versioning enabled) + S3 object metadata for version tracking  
**Testing**: Integration tests against AWS staging environment + dry-run validation  
**Target Platform**: macOS 10.15+, Linux (Ubuntu 18.04+, CentOS 7+, Amazon Linux 2)  
**Project Type**: CLI tool (deployment orchestration) + CloudFormation infrastructure template  
**Performance Goals**: 
- Initial deployment: <10 minutes
- Content updates: <5 minutes (including CloudFront invalidation)
- Rollback operations: <2 minutes
- Asset load time (P95): <1 second via CloudFront  
**Constraints**:
- Single AWS region (no multi-region failover)
- Single AWS account, production-only deployments (no staging/prod separation in v1)
- Static assets only (<100GB for v1)
- No server-side processing required
- CloudFormation exclusive (no Terraform)
- IAM role required (no embedded credentials)  
**Scale/Scope**: Single domain with multi-subdomain support; 95%+ first-attempt success rate; <$1/month hosting cost

## Constitution Check

**Infrastructure-as-Code First**: ✅ All AWS resources (S3, CloudFront, Route 53, ACM) defined in CloudFormation template; version controlled; no manual console provisioning  
**Idempotency**: ✅ Redeployment with same parameters updates existing stack; no duplicate resources created  
**Security by Default**: ✅ S3 private (no public ACL); CloudFront OAI enforced; HTTPS/TLS required; no secrets in code  
**Observability**: ✅ CloudTrail API logging; S3 access logs; CloudFront logs; CloudFormation event tracking  
**Compliance & Governance**: ✅ IAM least-privilege; cost monitoring; drift detection via CloudFormation  

---

## Architecture Overview

### System Architecture Diagram

```mermaid
graph TB
    subgraph "Local Execution"
        CLI["deploy.sh CLI<br/>(Bash Orchestrator)"]
        CONFIG["Config Files<br/>(.deployrc, CLI args)"]
        FILES["Website Files<br/>(HTML, CSS, JS, Images)"]
    end
    
    subgraph "AWS Infrastructure (CloudFormation Stack)"
        CFN["CloudFormation Template<br/>(s3-static-website.yaml)"]
        S3["S3 Bucket<br/>(versioning enabled)"]
        CF["CloudFront Distribution<br/>(CDN origin)"]
        R53["Route 53 Hosted Zone<br/>(DNS records)"]
        ACM["ACM Certificate<br/>(HTTPS/TLS)"]
    end
    
    subgraph "AWS Core Services"
        CFT["CloudFormation API<br/>(stack mgmt)"]
        S3API["S3 API<br/>(object operations)"]
        CFAPI["CloudFront API<br/>(cache invalidation)"]
        R53API["Route 53 API<br/>(DNS management)"]
        ACMAPI["ACM API<br/>(cert provisioning)"]
    end
    
    subgraph "End User Access"
        BROWSER["User Browser<br/>(HTTPS requests)"]
        DOMAIN["www.example.com<br/>(custom domain)"]
    end
    
    CLI -->|1. Read config| CONFIG
    CLI -->|2. Validate files| FILES
    CLI -->|3. Deploy mode| CFT
    CFT -->|create/update| CFN
    CFN -->|provisions| S3
    CFN -->|provisions| CF
    CFN -->|provisions| R53
    CFN -->|provisions| ACM
    
    CLI -->|4. Upload files| S3API
    S3API -->|store objects| S3
    
    CLI -->|5. Invalidate cache| CFAPI
    CFAPI -->|clear cache| CF
    
    CLI -->|6. Verify DNS| R53API
    R53API -->|query records| R53
    
    BROWSER -->|HTTPS request| DOMAIN
    DOMAIN -->|DNS lookup| R53
    R53 -->|alias record| CF
    CF -->|GET object| S3
    S3 -->|return content| CF
    CF -->|cached response| BROWSER
```

---

## Design Decisions & Rationale

### 1. **CloudFormation as Exclusive IaC Tool**
**Decision**: Use CloudFormation (no Terraform, Ansible, CDK)  
**Rationale**: 
- Native AWS service, no external tool dependencies
- Deep integration with AWS console for troubleshooting
- Simple YAML templates, easy to version control
- Supports drift detection (detect manual console changes)
- Spec explicitly prohibits external tools
**Trade-offs**: Less flexibility than Terraform multi-cloud; smaller ecosystem
**Impact**: Simplified dependency management; faster initial provisioning

### 2. **Single Unified Script with Subcommands**
**Decision**: One `deploy.sh` with `deploy`, `update`, `rollback` subcommands  
**Rationale**:
- Single entry point reduces user confusion
- Consistent parameter handling across operations
- Shared utilities (validation, error handling, AWS client setup)
- Easy to document and teach
**Trade-offs**: Larger script vs. multiple focused scripts
**Impact**: Better UX; reduced documentation overhead

### 3. **S3 Versioning for Rollback Capability**
**Decision**: Enable S3 object versioning; track versions via S3 object metadata (timestamps)  
**Rationale**:
- S3 versioning is built-in, no external version store needed
- Atomic rollback (restore single version ID restores all objects)
- AWS-managed version history (no manual backup management)
- Supports point-in-time recovery
**Trade-offs**: Slightly higher S3 storage costs; older versions consume space
**Impact**: Simple rollback UX; disaster recovery built-in

### 4. **CloudFormation Stack Naming Convention**
**Decision**: Predictable naming: `{app-name}-website-{subdomain}-{domain}.com`  
**Rationale**:
- Avoids naming collisions across environments
- Readable in AWS console (easy to identify which stack owns which website)
- Supports multiple websites in single AWS account
**Trade-offs**: Long names; requires domain/subdomain normalization
**Impact**: Multi-website support without additional tooling

### 5. **Idempotency via CloudFormation Stack Updates**
**Decision**: Redeploying with identical parameters triggers `UpdateStack` not `CreateStack`  
**Rationale**:
- CloudFormation detects no changes and reports "no updates" (safe operation)
- Supports recovery from partial failures (re-run deploy command to complete)
- No data loss on re-execution
- Aligns with Infrastructure-as-Code best practices
**Trade-offs**: Requires tracking stack state; more complex error handling
**Impact**: Safe re-execution; better operational safety

### 6. **Private S3 Bucket + CloudFront Origin Access**
**Decision**: S3 bucket is private; CloudFront accesses via Origin Access Identity (OAI)  
**Rationale**:
- Prevents direct S3 access, forcing CDN usage (cost control)
- Enables future fine-grained access policies (per-subdomain S3 prefixes)
- Aligns with "Security by Default" principle
- Reduces DDoS attack surface (single CloudFront endpoint)
**Trade-offs**: Adds OAI configuration complexity
**Impact**: Better security posture; prevents data exfiltration

### 7. **DNS Alias Records (Route 53 to CloudFront)**
**Decision**: Use Route 53 alias records (not CNAME) pointing to CloudFront  
**Rationale**:
- Alias records are free (no Route 53 query charges)
- Can point root domain (example.com) to CloudFront (CNAME cannot)
- Automatic health checking support (future enhancement)
- AWS-recommended pattern for CloudFront
**Trade-offs**: Requires Route 53 as DNS provider (cannot use external DNS)
**Impact**: Cost optimization; supports root domain deployment

### 8. **ACM Certificate Auto-Validation via Route 53**
**Decision**: ACM provisions certificates; Route 53 auto-validates via DNS (no email validation)  
**Rationale**:
- Fully automated (no manual email approval delays)
- Supports both domain and wildcard certificates
- Certificate renewal automatic (ACM renews 60 days before expiry)
- Supports multiple subdomains (SAN certificates)
**Trade-offs**: Requires Route 53 hosted zone to pre-exist or be created
**Impact**: Zero-touch HTTPS provisioning

### 9. **Explicit File Inclusion List (Not Exclusion)**
**Decision**: Define `DEPLOY_INCLUDE` patterns; exclude by default (allowlist approach)  
**Rationale**:
- Prevents accidental deployment of sensitive files (`.env`, `.git`, `node_modules`)
- Default patterns: `*.html`, `*.css`, `*.js`, `*.json`, `*.jpg`, `*.png`, etc.
- User can override with `--include-patterns` for custom file types
**Trade-offs**: Users must explicitly add new file types
**Impact**: Better security; prevents secrets exposure

### 10. **Parallel File Uploads with Retry Logic**
**Decision**: Upload files in parallel batches (e.g., 5 concurrent uploads); retry failed uploads 3x  
**Rationale**:
- Parallel uploads reduce total time (especially for 100+ files)
- Retry logic handles transient network failures
- Configurable concurrency for rate limiting
**Trade-offs**: More complex script logic; harder to debug
**Impact**: 3-5x faster uploads for large sites

---

## Technical Approach & Patterns

### Pattern 1: Configuration Management
**Approach**: Layered configuration (defaults → config file → CLI args → environment variables)
```
Priority (highest to lowest):
1. Environment variables (AWS_PROFILE, DEPLOY_REGION, etc.)
2. CLI arguments (--domain, --subdomain, --source-dir)
3. Config file (.deployrc, deploy.json)
4. Hardcoded defaults (./assets, us-east-1, etc.)
```

**Rationale**: Supports multiple deployment contexts (local dev, CI/CD, production)  
**Benefit**: Flexible without overwhelming users; sensible defaults

### Pattern 2: Stack State Tracking
**Approach**: Query CloudFormation describe-stacks to detect state (CREATE_COMPLETE, UPDATE_COMPLETE, DELETE_IN_PROGRESS, etc.)
```
If stack exists:
  If parameters match → UpdateStack
  If parameters differ → warn user, require confirmation
Else:
  CreateStack
```

**Rationale**: Idempotency; prevents overwriting existing infrastructure  
**Benefit**: Safe operations; clear user intent

### Pattern 3: Health Check & Validation
**Approach**: Multi-stage validation
1. **Pre-flight**: AWS credentials, file existence, domain syntax, IAM permissions
2. **CloudFormation**: Stack status, parameter validation
3. **Post-deployment**: HTTP/HTTPS health checks, DNS resolution, CloudFront cache test

**Rationale**: Early error detection; clear user feedback  
**Benefit**: Reduces debugging time

### Pattern 4: Atomic File Upload Operations with Retry Logic
**Approach**: Upload files with etag checks; retry failed uploads with exponential backoff; resume from checkpoint
```
1. Calculate local file hashes
2. Query S3 object metadata (existing etags)
3. Upload only changed files (diff-based upload) in parallel batches
4. On upload failure: retry up to 3x (backoff: 2s, 4s, 8s)
5. On network interruption: record successfully uploaded files, resume next run (skip already-uploaded)
6. Verify all uploads succeeded before cache invalidation
7. If verification fails, rollback (delete uploaded files)
```

**Rationale**: Prevents partial deployments; supports fast re-execution; handles transient failures  
**Benefit**: Data consistency; idempotent updates; network resilience

### Pattern 5: Version Snapshots
**Approach**: Store version manifest as S3 object metadata and local JSON file
```
Version manifest:
{
  "version_id": "20260501-143022",
  "timestamp": "2026-05-01T14:30:22Z",
  "files": [
    {"path": "index.html", "s3_key": "v/20260501-143022/index.html", "etag": "..."},
    {"path": "assets/css/main.css", "s3_key": "v/20260501-143022/assets/css/main.css", ...}
  ],
  "subdomain": "www",
  "domain": "example.com"
}
```

**Rationale**: Enables atomic rollback; supports version history query  
**Benefit**: Fast version restore; clear deployment audit trail

---

## Component Interactions

### Interaction 1: Deploy Command Workflow

```
User → ./deploy.sh deploy --domain example.com --subdomain www

1. **Parse Arguments** 
   → Validate syntax, check for conflicts

2. **Load Configuration**
   → Merge CLI args, config file, environment defaults

3. **Pre-flight Validation**
   → Check AWS credentials, verify IAM permissions, validate domain format

4. **Check Existing Stack**
   → Query CloudFormation for stack named "website-www-example-com"
   → If exists: UpdateStack mode, else: CreateStack mode

5. **Generate CloudFormation Parameters**
   → Domain=example.com, Subdomain=www, ACMCertArn=..., etc.

6. **Deploy CloudFormation Stack**
   → aws cloudformation create-stack / update-stack
   → Poll for completion (typically 2-5 minutes)
   → Report resource ARNs (S3 bucket, CloudFront domain, etc.)

7. **Upload Website Files**
   → Read file inclusion patterns
   → Scan local directory recursively
   → Filter files (exclude node_modules, .git, .env, etc.)
   → Calculate file hashes (SHA-256)
   → Compare with S3 metadata (skip if unchanged)
   → Upload changed files in parallel batches

8. **Create Version Snapshot**
   → Generate version manifest (timestamp + file list)
   → Store as S3 object: s3://bucket/versions/20260501-143022/manifest.json
   → Store as local file: .deploy/versions/20260501-143022.json

9. **Invalidate CloudFront Cache**
   → aws cloudfront create-invalidation --paths "/*"
   → Poll for invalidation complete (typically 1-2 minutes)

10. **Post-deployment Health Checks**
    → HTTP GET to custom domain via CloudFront
    → Verify HTTPS certificate valid
    → Check DNS resolution correct
    → Load 3-5 key assets (index.html, main.css, main.js, image)
    → Report latency percentiles (P50, P95, P99)

11. **Success Report**
    → Print summary: Stack ID, S3 bucket, CloudFront domain, TTL values
    → Log to file: .deploy/deployments/20260501-143022.log
```

### Interaction 2: Update Command Workflow

```
User → ./deploy.sh update

1. **Load Configuration**
   → Read from .deployrc or stored stack metadata

2. **Identify Current Stack**
   → Query CloudFormation for active stack
   → Validate stack status is CREATE_COMPLETE or UPDATE_COMPLETE

3. **Detect File Changes**
   → Scan local directory for modified files
   → Compare timestamps/hashes against last deployment manifest
   → Report which files changed

4. **Upload Changed Files**
   → [Same as deploy: filter, hash, compare, upload in parallel]
   → Only upload files detected as changed
   → Skip files with identical content (etag match)

5. **Create New Version Snapshot**
   → Generate new manifest (incremented timestamp)
   → Store version metadata

6. **Invalidate CloudFront**
   → Invalidate only changed file paths (or /* if >100 files changed)
   → Poll for completion

7. **Health Check**
   → Verify updated files accessible via CloudFront
   → Measure latency

8. **Success Report**
   → Print: "Updated X files, deployed in Y seconds"
   → Print new version ID
```

### Interaction 3: Rollback Command Workflow

```
User → ./deploy.sh rollback --version 20260501-143022

1. **Validate Version Exists**
   → Check .deploy/versions/20260501-143022.json exists
   → Read version manifest

2. **Restore S3 Objects**
   → For each file in version manifest:
     → Copy object from versioned S3 key to current key
     → Restore all files atomically (all-or-nothing)

3. **Invalidate CloudFront**
   → aws cloudfront create-invalidation --paths "/*"
   → Poll for completion

4. **Verify**
   → Health check against CloudFront
   → Report success

5. **Audit Log**
   → Record: "Rolled back from 20260502-104512 to 20260501-143022"
```

---

## Data Flows

### Data Flow 1: File Upload Pipeline

```
Local Files (./assets/**/*) 
  ↓ [Filter: include patterns]
  ↓ [Skip: excluded patterns]
  → File Inventory (path, size, hash)
  ↓ [Compare vs S3 metadata]
  → Changed Files Only
  ↓ [Parallel batch upload]
  → S3 (with headers: Content-Type, Cache-Control, x-amz-storage-class)
  ↓ [Verify etags match]
  → Upload Complete Manifest
  ↓ [Store in S3 + local .deploy/]
  → Version Snapshot
```

### Data Flow 2: Cache Invalidation Flow

```
Deploy/Update Complete
  ↓ [Collect changed file paths]
  → Invalidation Request
    {
      "DistributionId": "E123ABC...",
      "InvalidationBatch": {
        "Paths": {
          "Quantity": 10,
          "Items": ["/index.html", "/assets/css/*", "/assets/js/*", ...]
        },
        "CallerReference": "deploy-20260502-104512"
      }
    }
  ↓ [Submit to CloudFront API]
  → Invalidation ID (e.g., I1ABC2D3E4F5...)
  ↓ [Poll for completion]
  → InProgress → Completed
  ↓ [~1-2 minutes]
  → Cache Cleared
```

### Data Flow 3: Version History Flow

```
Deploy Initiated
  ↓ [Timestamp: 2026-05-01T14:30:22Z]
  → Version ID (derived: 20260501-143022)
  ↓ [File scan + upload]
  → Manifest:
    {
      "version_id": "20260501-143022",
      "files": [
        {"path": "index.html", "size": 5120, "hash": "sha256:abc123...", "s3_etag": "..."},
        ...
      ]
    }
  ↓ [Store in two places]
  ├→ S3: s3://bucket/versions/20260501-143022.json
  └→ Local: .deploy/versions/20260501-143022.json
  ↓ [User can query]
  → ./deploy.sh versions --list
  → (outputs all available versions with timestamps)
```

---

## API / Interface Design

### CLI Interface

```bash
# Deploy initial infrastructure + content
./deploy.sh deploy \
  --domain example.com \
  --subdomain www \
  --region us-east-1 \
  --source-dir ./assets \
  --aws-profile production \
  [--dry-run]

# Update content only (uses stored domain/subdomain)
./deploy.sh update \
  [--subdomain www] \
  [--source-dir ./assets] \
  [--dry-run]

# Rollback to specific version
./deploy.sh rollback \
  --version 20260501-143022 \
  [--confirm]

# List deployment versions
./deploy.sh versions \
  [--limit 20] \
  [--json]

# Validate deployment (dry-run)
./deploy.sh validate \
  --domain example.com \
  --subdomain www \
  --source-dir ./assets

# Show deployment status
./deploy.sh status

# Delete infrastructure (destroy stack)
./deploy.sh destroy \
  [--confirm]
```

### Configuration File Format (.deployrc)

```yaml
# Global defaults
domain: example.com
subdomains:
  - www
  - blog
region: us-east-1
source_dir: ./assets
aws_profile: default

# File inclusion/exclusion
include_patterns:
  - "*.html"
  - "*.css"
  - "*.js"
  - "*.json"
  - "*.jpg"
  - "*.png"
  - "*.svg"
  - "*.webp"
  - "*.gif"
  - "*.ico"
  - "*.woff2"
  - "*.ttf"

exclude_patterns:
  - "node_modules/"
  - ".git/"
  - ".env*"
  - "*.md"
  - ".DS_Store"
  - "*.tmp"

# CloudFormation parameters
cloudformation:
  timeout_minutes: 10
  enable_logging: true
  
# CloudFront settings
cloudfront:
  cache_default_ttl: 86400
  cache_max_ttl: 31536000
  compress: true
  
# Monitoring
monitoring:
  enable_health_checks: true
  health_check_interval: 30
```

### Return Codes

```
0   - Success
1   - General error
2   - Validation failed (pre-flight checks)
3   - AWS API error (credential, permission issue)
4   - CloudFormation stack error
5   - File operation error
6   - Network error
7   - Configuration error
```

### Output Formats

**Standard Output** (progress updates):
```
[INFO] 2026-05-01 14:30:22 | Validating configuration...
[INFO] 2026-05-01 14:30:23 | AWS credentials verified
[INFO] 2026-05-01 14:30:24 | Checking existing stack...
[INFO] 2026-05-01 14:30:26 | Stack 'website-www-example-com' not found, creating...
[INFO] 2026-05-01 14:31:45 | Stack creation complete (ID: arn:aws:cloudformation:...)
[INFO] 2026-05-01 14:31:46 | Uploading 42 files...
[PROGRESS] 2026-05-01 14:32:10 | 25/42 files uploaded (59%)
[INFO] 2026-05-01 14:32:35 | All files uploaded successfully
[INFO] 2026-05-01 14:32:36 | Invalidating CloudFront cache...
[INFO] 2026-05-01 14:34:01 | Cache invalidated (ID: I1ABC2D3E4F5...)
[SUCCESS] 2026-05-01 14:34:01 | Deployment complete!

Stack ID: arn:aws:cloudformation:us-east-1:123456789012:stack/website-www-example-com/...
S3 Bucket: website-www-example-com-s3bucket-abc123
CloudFront Domain: d123abc.cloudfront.net
Custom Domain: www.example.com
Version: 20260501-143022
Deployment Time: 3m 39s
```

**JSON Output** (--json flag):
```json
{
  "status": "success",
  "timestamp": "2026-05-01T14:34:01Z",
  "deployment": {
    "version_id": "20260501-143022",
    "operation": "create",
    "duration_seconds": 219
  },
  "resources": {
    "stack_id": "arn:aws:cloudformation:us-east-1:...",
    "s3_bucket": "website-www-example-com-s3bucket-abc123",
    "cloudfront_distribution": "E123ABC...",
    "cloudfront_domain": "d123abc.cloudfront.net",
    "route53_zone_id": "Z123ABC...",
    "acm_certificate_arn": "arn:aws:acm:us-east-1:..."
  },
  "files": {
    "uploaded": 42,
    "skipped": 0,
    "total": 42
  },
  "endpoints": {
    "s3_origin": "https://website-www-example-com-s3bucket-abc123.s3.amazonaws.com",
    "cloudfront": "https://d123abc.cloudfront.net",
    "custom_domain": "https://www.example.com"
  }
}
```

---

## Error Handling Strategy

### Error Categories & Recovery

**Category 1: Pre-flight Validation Errors** (Exit Code: 2)
```
Error: Missing AWS credentials
  → Check: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, ~/.aws/credentials
  → Action: User sets credentials before retry

Error: Invalid domain format (example..com)
  → Suggestion: Did you mean "example.com"?
  → Action: User corrects domain parameter

Error: File not found: ./assets/index.html
  → Action: User creates missing file or specifies --source-dir
```

**Category 2: AWS API Errors** (Exit Code: 3)
```
Error: AccessDenied - User is not authorized to perform: s3:PutObject
  → Suggestion: IAM role needs S3 write permission
  → Action: Admin updates IAM policy to include s3:*
  
Error: ServiceUnavailable - CloudFormation temporary outage
  → Action: Script retries 3x with exponential backoff (2s, 4s, 8s)

Error: ValidationError - Parameter 'DomainName' must not exceed 63 characters
  → Action: User shortens domain name or subdomain
```

**Category 3: CloudFormation Stack Errors** (Exit Code: 4)
```
Error: Stack creation failed (CREATE_FAILED)
  → Root cause: VPC endpoint already exists
  → Action: Query CloudFormation events, suggest delete/recreate
  → Recovery: ./deploy.sh destroy --force, then retry
  
Error: Stack rollback in progress
  → Action: Wait for rollback to complete, then retry

Error: Template validation failed
  → Action: Check CloudFormation YAML syntax in s3-static-website.yaml
```

**Category 4: File Operation Errors** (Exit Code: 5)
```
Error: Permission denied reading ./assets/.git
  → Action: Add .git/ to exclude_patterns

Error: Disk full - cannot read file ./assets/large-video.mp4
  → Action: Check disk space, remove large files, or filter exclusions

Error: Too many files (>10000)
  → Action: Split deployment across multiple subdomains or use .deploy-exclude
```

**Category 5: Network/Timeout Errors** (Exit Code: 6)
```
Error: Connection timeout uploading to S3
  → Recovery: Script records uploaded files, retries only failed ones
  → Action: Check internet connection, increase timeout with --timeout 60

Error: CloudFormation stack creation timeout (>10 minutes)
  → Action: Increase --timeout or check CloudFormation events for blockers
```

### Retry & Backoff Strategy

```bash
# S3 uploads: 3 retries with exponential backoff
attempt 1: upload, wait 2s
attempt 2: upload, wait 4s  
attempt 3: upload, wait 8s
failure: report error, suggest --retry-uploads

# CloudFormation operations: poll every 10s, timeout after 10 minutes
while [ stack_status != "CREATE_COMPLETE" ]; do
  sleep 10
  describe-stack
  if elapsed > 600s: timeout error
done

# CloudFront invalidation: poll every 30s, timeout after 5 minutes
while [ invalidation_status != "Completed" ]; do
  sleep 30
  describe-invalidation
  if elapsed > 300s: timeout error
done
```

### Graceful Degradation

```
If CloudFront cache invalidation fails:
  → Log warning but don't fail deployment
  → Suggest: ./deploy.sh invalidate --manual
  → Content will still be live (just with stale cache)
  
If health check fails:
  → Deployment still succeeds (optional feature)
  → Log warning with suggested troubleshooting steps
  → Example: "DNS not yet propagated, try again in 60s"
```

---

## Security Considerations

### 1. **Credential Management**
- **Approach**: No embedded credentials in script or repository
- **Implementation**: 
  - Use AWS credential profiles (`~/.aws/credentials`)
  - Support environment variables (`AWS_ACCESS_KEY_ID`, etc.)
  - Support IAM roles (EC2 instance, Lambda execution role)
  - Support STS assumed roles (cross-account deployments)
- **Verification**: Script checks credential validity before operations
- **Risk Mitigation**: Log credential file permissions; warn if world-readable

### 2. **S3 Bucket Security**
- **Approach**: Private bucket with no public ACL
- **Implementation**:
  - Block S3 public access (ACL + bucket policy)
  - Bucket policy: allow only CloudFront OAI access
  - Bucket versioning: enabled (supports recovery)
  - Server-side encryption: SSE-S3 default (AES-256)
  - MFA Delete: optional (recommended for production)
  - Logging: access logs to separate bucket (optional)
- **Verification**: CloudFormation template enforces these settings

### 3. **CloudFront Security**
- **Approach**: HTTPS/TLS enforced for all traffic
- **Implementation**:
  - Redirect HTTP → HTTPS
  - TLS 1.2 minimum
  - Origin Access Identity (OAI) for S3 access
  - No direct S3 URL exposure
  - Security headers: X-Frame-Options, X-Content-Type-Options, etc.
- **Verification**: Health check validates HTTPS certificate validity

### 4. **ACM Certificate Management**
- **Approach**: AWS-managed certificates with auto-renewal
- **Implementation**:
  - Certificate auto-provisioned by CloudFormation
  - DNS validation via Route 53 (no email validation)
  - Auto-renewal 60 days before expiry
  - Supports wildccard (*.example.com) and multiple SANs
- **Risk Mitigation**: CloudFormation monitors certificate status

### 5. **IAM Permission Minimization**
- **Minimum IAM Policy** (least-privilege):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:CreateStack",
        "cloudformation:UpdateStack",
        "cloudformation:DescribeStacks",
        "cloudformation:DescribeStackEvents",
        "cloudformation:DeleteStack"
      ],
      "Resource": "arn:aws:cloudformation:*:*:stack/website-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning"
      ],
      "Resource": [
        "arn:aws:s3:::website-*",
        "arn:aws:s3:::website-*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudfront:CreateInvalidation",
        "cloudfront:DescribeInvalidation"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets",
        "route53:ChangeTagsForResource"
      ],
      "Resource": "arn:aws:route53:::hostedzone/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "acm:RequestCertificate",
        "acm:DescribeCertificate",
        "acm:DeleteCertificate",
        "acm:ListCertificates"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::*:role/CloudFormationRole"
    }
  ]
}
```

### 6. **File Upload Security**
- **Approach**: Validate file types before upload; scan for secrets
- **Implementation**:
  - Whitelist file extensions (no .exe, .sh, .bat)
  - Reject files containing AWS credentials patterns (api-key, password)
  - Set Content-Type headers correctly (prevent MIME sniffing)
  - Set Cache-Control headers (browser cache policy)
- **Verification**: Pre-upload validation reports suspicious files

### 7. **Domain Validation**
- **Approach**: Verify domain ownership before deploying
- **Implementation**:
  - Prompt user to confirm domain (prevent typos)
  - Check Route 53 hosted zone exists for domain
  - Verify ACM certificate matches domain (CN + SANs)
- **Risk Mitigation**: Confirmation required for new domains

### 8. **Audit & Logging**
- **Approach**: All operations logged for compliance
- **Implementation**:
  - CloudTrail logs all AWS API calls (enabled by default)
  - S3 access logs (optional, configurable)
  - CloudFront access logs (optional, configurable)
  - Local deployment logs: `.deploy/logs/YYYY-MM-DD.log`
  - JSON deployment records: `.deploy/deployments/TIMESTAMP.json`
- **Retention**: 90-day retention on logs (configurable)

### 9. **Network Security**
- **Approach**: HTTPS-only communication
- **Implementation**:
  - All AWS API calls via HTTPS
  - CloudFront enforces HTTPS for end users
  - No HTTP fallback (HTTP → HTTPS redirect only)
  - TLS 1.2+ for all connections
- **Verification**: Health check validates HTTPS certificate

### 10. **Secrets Management**
- **Approach**: No secrets in code or config files
- **Implementation**:
  - Deploy.sh never logs sensitive data
  - AWS credentials only from external sources (env vars, IAM)
  - .deployrc excluded from Git (.gitignore)
  - Temporary files deleted after operations
- **Verification**: Script audits for accidental secret exposure

---

## Performance Approach

### 1. **Deployment Time Optimization**

**Target**: <10 minutes initial deployment

| Phase | Typical Duration | Optimization |
|-------|------------------|--------------|
| CloudFormation stack creation | 3-5 min | Parallel resource creation (AWS handles) |
| File upload (50 files, 10MB) | 1-2 min | Parallel batch uploads (5 concurrent) |
| CloudFront invalidation | 1-2 min | Path pattern batching (max 3000 paths) |
| Health checks | 30-60 sec | Parallel health checks |
| **Total** | **6-9 min** | Dependencies managed correctly |

### 2. **Update Time Optimization**

**Target**: <5 minutes content update

| Phase | Typical Duration | Optimization |
|-------|------------------|--------------|
| Detect changes | 10-20 sec | Local file hash comparison (cached) |
| Upload changed files (3-5 files) | 10-30 sec | Only changed files uploaded |
| CloudFront invalidation | 1-2 min | Selective path invalidation |
| Health check | 20-30 sec | Spot checks 2-3 key files |
| **Total** | **2-3 min** | Minimal data transfer |

### 3. **File Upload Parallelization**

```bash
# Pseudo-code for parallel uploads
files=($(find . -type f | grep -v exclude_pattern))
batch_size=5
for ((i=0; i<${#files[@]}; i+=batch_size)); do
  for ((j=0; j<batch_size && i+j<${#files[@]}; j++)); do
    aws s3 cp "${files[i+j]}" "s3://bucket/..." &
  done
  wait  # Wait for batch to complete
done
```

**Rationale**: 5 concurrent uploads balance throughput vs. connection limits

### 4. **CloudFront Cache Strategy**

**Default Cache TTLs**:
- HTML files: 60 seconds (fast updates)
- CSS/JS: 30 days (fingerprinted by build tool)
- Images: 365 days (immutable assets)
- Version manifests: 0 seconds (always fresh)

**Implementation**:
```bash
# Set Cache-Control headers per file type
aws s3 cp index.html s3://bucket/ \
  --cache-control "max-age=60, public"
  
aws s3 cp main.js s3://bucket/assets/ \
  --cache-control "max-age=2592000, public"
```

### 5. **Invalidation Path Optimization**

```bash
# If >100 files changed: use /* (single invalidation)
if [ changed_files > 100 ]; then
  paths="/*"
else
  # Build specific paths
  paths=$(printf "/%s\n" "${changed_files[@]}" | head -100)
fi

aws cloudfront create-invalidation \
  --distribution-id E123ABC \
  --paths $paths
```

**Rationale**: /* is single invalidation; specific paths require enumeration

### 6. **DNS Resolution Optimization**

**Route 53 Alias Records** (not CNAME):
- No DNS query charges (vs. CNAME costs)
- Instant propagation (vs. 60s TTL delay)
- Health checking support (optional)
- Root domain support (CNAME cannot)

### 7. **Asset Loading Performance**

**CloudFront Edge Caching**:
- 200+ edge locations globally
- HTTP/2 and gzip compression enabled
- Automatic IPv6 support
- TLS session reuse (faster handshakes)

**Browser Caching** (via Cache-Control headers):
- Leverage browser cache for repeat visits
- HTTP ETag support (304 Not Modified responses)

### 8. **Monitoring & Metrics**

**Health Check Metrics Captured**:
- DNS resolution time (P50, P95, P99)
- TLS handshake time
- First byte time (TTFB)
- Total page load time
- Asset load times (HTML, CSS, JS, images)

**Example output**:
```
Health Check Results:
  DNS Resolution: 50ms (avg)
  TLS Handshake: 120ms (avg)
  TTFB (index.html): 45ms (avg)
  Total Load (index.html + assets): 320ms (P95)
  CloudFront Hit Ratio: 98.5%
```

---

## Testing Strategy

### Test Scope & Environment

**Test Environments**:
1. **Local (developer machine)**: Bash syntax validation, CLI parsing, mocking AWS calls
2. **AWS Staging**: Real AWS operations against staging account/region
3. **AWS Production**: Production deployment after staging validation

**Test Types**: Unit, Integration, E2E, Performance, Security

### Phase 1: Unit Tests (Bash Functions)

**Test Category 1: Argument Parsing**
```bash
test_parse_deploy_args_valid() {
  result=$(parse_args deploy --domain example.com --subdomain www)
  assert_equal "$result" "domain=example.com subdomain=www"
}

test_parse_deploy_args_missing_domain() {
  result=$(parse_args deploy --subdomain www 2>&1)
  assert_contains "$result" "Missing required parameter: --domain"
  assert_exit_code 2
}
```

**Test Category 2: File Validation**
```bash
test_validate_files_includes_html_css_js() {
  files=$(find_files_to_upload --include "*.html" --include "*.css")
  assert_contains "$files" "index.html"
  assert_contains "$files" "main.css"
  assert_not_contains "$files" "node_modules"
}

test_validate_files_excludes_git_env() {
  files=$(find_files_to_upload --exclude ".git" --exclude ".env")
  assert_not_contains "$files" ".env"
  assert_not_contains "$files" ".git"
}
```

**Test Category 3: Hash Comparison**
```bash
test_compare_file_hash_identical() {
  local_hash=$(sha256sum index.html)
  s3_hash=$(get_s3_object_etag s3://bucket/index.html)
  result=$(compare_hashes "$local_hash" "$s3_hash")
  assert_equal "$result" "identical"
}

test_compare_file_hash_different() {
  local_hash=$(sha256sum index.html)
  s3_hash=$(get_s3_object_etag s3://bucket/index-old.html)
  result=$(compare_hashes "$local_hash" "$s3_hash")
  assert_equal "$result" "different"
}
```

### Phase 2: Integration Tests (AWS Staging)

**Integration Test 1: Full Deploy Workflow**
```bash
test_deploy_creates_all_resources() {
  # Setup: Clean staging account
  cleanup_test_stack "website-test-example-com"
  
  # Execute
  result=$(./deploy.sh deploy \
    --domain test-example.com \
    --subdomain www \
    --region us-east-1 \
    --aws-profile staging)
  
  # Verify
  assert_exit_code 0
  assert_cloudformation_stack_exists "website-test-example-com"
  assert_s3_bucket_exists "website-test-example-com-s3bucket-*"
  assert_cloudfront_distribution_exists
  assert_route53_records_exist
  assert_acm_certificate_valid
  
  # Cleanup
  cleanup_test_stack "website-test-example-com"
}
```

**Integration Test 2: File Upload & Verification**
```bash
test_update_uploads_changed_files() {
  # Setup: Deploy initial version
  ./deploy.sh deploy --domain test-example.com --subdomain www
  
  # Modify files
  echo "<h1>Updated</h1>" > index.html
  
  # Execute update
  result=$(./deploy.sh update)
  assert_exit_code 0
  
  # Verify via S3
  s3_content=$(aws s3 cp s3://bucket/index.html -)
  assert_contains "$s3_content" "Updated"
  
  # Verify via CloudFront (with cache bypass)
  cf_content=$(curl https://d123abc.cloudfront.net/index.html -H "Cache-Control: no-cache")
  assert_contains "$cf_content" "Updated"
  
  # Cleanup
  cleanup_test_stack
}
```

**Integration Test 3: Idempotency**
```bash
test_redeploy_is_idempotent() {
  # Setup
  ./deploy.sh deploy --domain test-example.com --subdomain www
  initial_stack_id=$(get_stack_id "website-test-example-com")
  
  # Redeploy with same parameters
  result=$(./deploy.sh deploy --domain test-example.com --subdomain www)
  final_stack_id=$(get_stack_id "website-test-example-com")
  
  # Verify: Stack ID unchanged, no resources deleted
  assert_equal "$initial_stack_id" "$final_stack_id"
  assert_exit_code 0
  assert_cloudformation_stack_status "UPDATE_COMPLETE"
  
  # Cleanup
  cleanup_test_stack
}
```

**Integration Test 4: Rollback**
```bash
test_rollback_restores_previous_version() {
  # Setup: Deploy version 1
  ./deploy.sh deploy --domain test-example.com --subdomain www
  version1=$(get_current_version)
  
  # Update to version 2
  echo "Modified" > index.html
  ./deploy.sh update
  version2=$(get_current_version)
  
  # Verify version 2 is live
  content=$(curl https://test-example.com/index.html)
  assert_contains "$content" "Modified"
  
  # Rollback to version 1
  ./deploy.sh rollback --version "$version1"
  
  # Verify version 1 is restored
  content=$(curl https://test-example.com/index.html)
  assert_not_contains "$content" "Modified"
  
  # Cleanup
  cleanup_test_stack
}
```

### Phase 3: E2E Tests (Production-Like)

**E2E Test 1: Multi-Subdomain Deployment**
```bash
test_deploy_multiple_subdomains() {
  # Deploy www and blog subdomains
  ./deploy.sh deploy \
    --domain test-example.com \
    --subdomains www,blog
  
  # Verify each subdomain has distinct content
  www_content=$(curl https://www.test-example.com/)
  blog_content=$(curl https://blog.test-example.com/)
  
  assert_not_equal "$www_content" "$blog_content"
  assert_contains "$www_content" "www-specific-content"
  assert_contains "$blog_content" "blog-specific-content"
}
```

**E2E Test 2: Large File Deployment**
```bash
test_deploy_large_website() {
  # Create test directory with 500 files, 50MB total
  create_test_files 500 50MB
  
  # Deploy
  time_start=$(date +%s)
  result=$(./deploy.sh deploy \
    --domain test-example.com \
    --subdomain www \
    --source-dir ./test-files)
  time_end=$(date +%s)
  
  # Verify
  assert_exit_code 0
  assert_s3_file_count 500
  deployment_time=$((time_end - time_start))
  assert_less_than $deployment_time 600  # <10 minutes
}
```

### Phase 4: Error Handling Tests

**Error Test 1: Missing AWS Credentials**
```bash
test_error_missing_credentials() {
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  
  result=$(./deploy.sh deploy --domain example.com 2>&1)
  
  assert_exit_code 3
  assert_contains "$result" "AWS credentials not found"
  assert_contains "$result" "Set AWS_ACCESS_KEY_ID or configure ~/.aws/credentials"
}
```

**Error Test 2: Insufficient IAM Permissions**
```bash
test_error_insufficient_permissions() {
  # Use minimal IAM role (s3 only, no cloudfront)
  export AWS_PROFILE=minimal
  
  result=$(./deploy.sh deploy --domain example.com 2>&1)
  
  assert_exit_code 3
  assert_contains "$result" "AccessDenied"
  assert_contains "$result" "cloudfront:CreateInvalidation"
}
```

**Error Test 3: Invalid Domain Format**
```bash
test_error_invalid_domain() {
  result=$(./deploy.sh deploy --domain "invalid..domain" 2>&1)
  
  assert_exit_code 2
  assert_contains "$result" "Invalid domain format"
}
```

### Phase 5: Performance Tests

**Performance Test 1: Upload Speed**
```bash
test_performance_upload_speed() {
  # 100 files, 1MB each, 100MB total
  create_test_files 100 1MB
  
  time_start=$(date +%s%3N)
  aws s3 sync ./test-files s3://test-bucket/ --parallel 5
  time_end=$(date +%s%3N)
  
  elapsed_sec=$((($time_end - $time_start) / 1000))
  throughput=$((100 / elapsed_sec))  # MB/s
  
  assert_greater_than $throughput 10  # >10 MB/s expected
}
```

**Performance Test 2: Cache Invalidation Speed**
```bash
test_performance_invalidation_speed() {
  # Measure time from invalidation request to cache cleared
  time_start=$(date +%s%3N)
  
  aws cloudfront create-invalidation \
    --distribution-id E123ABC \
    --paths "/*"
  
  while [ $(get_invalidation_status) != "Completed" ]; do
    sleep 5
  done
  
  time_end=$(date +%s%3N)
  elapsed_sec=$((($time_end - $time_start) / 1000))
  
  assert_less_than $elapsed_sec 120  # <2 minutes expected
}
```

### Phase 6: Security Tests

**Security Test 1: No Secrets in Logs**
```bash
test_security_no_secrets_in_logs() {
  export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
  export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  
  ./deploy.sh deploy --domain example.com 2>&1 | tee deploy.log
  
  # Verify log contains no credential material
  grep -q "AKIA" deploy.log && exit 1  # Fail if AWS key found
  grep -q "wJalrXUtnFEMI" deploy.log && exit 1  # Fail if secret found
}
```

**Security Test 2: S3 Bucket is Private**
```bash
test_security_s3_bucket_private() {
  # Deploy website
  ./deploy.sh deploy --domain example.com
  bucket=$(get_s3_bucket_name)
  
  # Verify bucket blocks public access
  acl=$(aws s3api get-bucket-acl --bucket $bucket)
  assert_not_contains "$acl" "AllUsers"
  assert_not_contains "$acl" "AuthenticatedUsers"
  
  # Verify bucket policy restricts to CloudFront OAI
  policy=$(aws s3api get-bucket-policy --bucket $bucket)
  assert_contains "$policy" "cloudfront.amazonaws.com"
  assert_contains "$policy" "CanonicalUser"
}
```

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)
- [x] Create CloudFormation template (s3-static-website.yaml)
- [ ] Implement deploy command (create/update stack, upload files)
- [ ] Implement update command (diff, upload, invalidate)
- [ ] Basic error handling and validation

### Phase 2: Robustness (Week 3-4)
- [ ] Implement version snapshots and rollback
- [ ] Add dry-run mode
- [ ] Parallel file uploads with retry logic
- [ ] Comprehensive error messages

### Phase 3: Operational Excellence (Week 5-6)
- [ ] Health checks (DNS, HTTPS, content verification)
- [ ] Performance monitoring and metrics
- [ ] CloudFormation drift detection
- [ ] Audit logging

### Phase 4: Documentation & Testing (Week 7-8)
- [ ] Integration tests against staging AWS
- [ ] E2E tests (multi-subdomain, rollback, etc.)
- [ ] Performance tests (upload speed, cache invalidation)
- [ ] Security audit and penetration tests
- [ ] README and runbooks

### Phase 5: Polish & Release (Week 9-10)
- [ ] Code review and refactoring
- [ ] Documentation updates
- [ ] Production staging validation
- [ ] Release v1.0

---

## Success Metrics & Validation

### Deployment Performance
- ✅ Initial deployment: <10 minutes (target: 6-9 minutes)
- ✅ Content update: <5 minutes (target: 2-3 minutes)
- ✅ Rollback: <2 minutes
- ✅ First-attempt success rate: >95%

### Operational Reliability
- ✅ Idempotent operations (safe re-execution)
- ✅ Graceful error recovery (retry logic, clear messages)
- ✅ Network resilience (retry on transient failures)
- ✅ File integrity (etag validation, atomic uploads)

### Security Posture
- ✅ S3 bucket private with no public access
- ✅ HTTPS/TLS enforced for all traffic
- ✅ IAM least-privilege role configured
- ✅ No secrets in logs or repository
- ✅ CloudTrail audit logging enabled

### Cost Efficiency
- ✅ <$1/month for websites <10GB
- ✅ S3 versioning enabled (low incremental cost)
- ✅ CloudFront aliases (no Route 53 query charges)
- ✅ Intelligent caching (reduce egress charges)

### User Experience
- ✅ Single command for full lifecycle (deploy, update, rollback)
- ✅ Clear, actionable error messages
- ✅ Status output with resource details
- ✅ Dry-run validation before actual changes

---

## References & Dependencies

**CloudFormation Template**:
- Location: `./CloudFormation/s3-static-website.yaml`
- Resources: S3 bucket, CloudFront distribution, Route 53 hosted zone, ACM certificate, CloudFront OAI
- Parameters: Domain, Subdomain(s), Region, ACM certificate settings

**External Dependencies**:
- AWS CLI v2 (install via `brew install awscli` or `pip install awscliv2`)
- jq (optional, install via `brew install jq` or `apt-get install jq`)
- Bash 4.0+ (macOS 10.15+ includes Bash 5.x)

**Project Assets**:
- Website content: `./assets/` and root directory files
- Deployment script: `./deploy.sh` (to be created)
- Configuration: `.deployrc` (optional, user-created)

**Constitutional Alignment**:
- Infrastructure-as-Code First: ✅ CloudFormation only
- Security by Default: ✅ Private S3, HTTPS enforced
- Idempotency: ✅ Safe re-execution via CloudFormation updates
- Observability: ✅ CloudTrail, S3 logs, CloudFront logs
- Documentation: ✅ README, inline comments, error messages

