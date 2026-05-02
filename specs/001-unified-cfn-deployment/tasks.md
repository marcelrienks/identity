---
description: "Implementation tasks for AWS Static Website with Unified CloudFormation Deployment"
feature: "001-aws-static-website-cfn"
plan: "plan.md"
spec: "aws-static-website-cfn-deployment.md"
---

# Tasks: AWS Static Website with Unified CloudFormation Deployment

**Feature Branch**: `001-aws-static-website-cfn`  
**Created**: 2026-05-02  
**Input**: Feature spec at [aws-static-website-cfn-deployment.md](aws-static-website-cfn-deployment.md) | Implementation plan at [plan.md](plan.md)

---

## 📋 Task Format Reference

- **[ID]**: Unique task identifier (T### format)
- **[P]**: Task can run in parallel (no dependencies between parallel tasks)
- **[Story]**: User story this task belongs to (US1, US2, US3, US4, US5)
- **[Priority]**: Story priority (P1, P2, P3)
- **Description**: WHAT needs to be done, WHERE (file paths), and WHY - NOT HOW to code

---

## 🎯 MVP Scope Recommendation

**MVP = Phase 1 + Phase 2 + Phase 3 (User Story 1 & 2 only)**

**MVP Deliverables**:
- Deploy command: Provisions infrastructure + uploads initial content
- Update command: Uploads modified files + invalidates CloudFront cache
- Dry-run mode: Validates configuration without making AWS changes
- Basic rollback: Reverts to previous version via S3 versioning

**MVP Excludes**:
- Multi-subdomain support (Phase 5)
- Explicit version tagging UI (Phase 6)
- Advanced deployment validation (Phase 7)
- Monitoring dashboards (Phase 8)

**MVP Success Criteria**:
- [ ] Initial deployment <10 min from code checkout to live HTTPS endpoint
- [ ] Content updates <5 min from file change to live website
- [ ] 95% of deployments succeed on first attempt
- [ ] Redeployment with same parameters is safe (idempotent)
- [ ] All website assets load correctly via CloudFront

**Estimated MVP Timeline**: 5-6 weeks with 1 engineer

---

## 📊 Phase Summary

| Phase | Goal | Task Count | Stories Covered | Duration Est. |
|-------|------|-----------|-----------------|---------------|
| **Phase 1** | Setup | 5 | — | 3-4 days |
| **Phase 2** | Foundational | 8 | — | 5-7 days |
| **Phase 3** | US1 Deploy (P1) | 12 | Infrastructure Provisioning | 7-10 days |
| **Phase 4** | US2 Update (P1) | 10 | Content Updates | 5-7 days |
| **Phase 5** | US3 Multi-Subdomain (P2) | 8 | Multi-Subdomain Support | 5-7 days |
| **Phase 6** | US4 Rollback (P2) | 7 | Rollback & Versioning | 4-6 days |
| **Phase 7** | US5 Validation (P3) | 6 | Deployment Validation | 3-5 days |
| **Phase 8** | Polish | 10 | Cross-cutting | 5-7 days |
| | **TOTAL** | **66** | | **6-8 weeks** |

---

## Phase 1: Setup (Project Initialization & Environment)

**Purpose**: Establish project structure and development environment  
**Prerequisite**: None  
**Completion Criteria**: Project skeleton ready for foundational work

### Tasks (5 total, all parallel)

- [ ] **T001** **[P]** Create project structure per implementation plan in `./deploy.sh` directory
  - Include directory structure: `./lib/` (functions), `./tests/` (unit/integration), `./.deploy/` (state), `./CloudFormation/` (templates)
  - Create `.gitignore` to exclude: `.deployrc` (credentials), `.deploy/` (state), `*.log`, `.aws/` (credentials)
  - File: [deploy.sh](../../../deploy.sh) (new), [.gitignore](../../../.gitignore) (update)

- [ ] **T002** **[P]** Initialize Bash script skeleton with error handling, logging, and argument parsing framework
  - Implement: Logging functions (info/warn/error), exit code handlers, signal traps (SIGINT, SIGTERM)
  - Implement: Global constants (SCRIPT_DIR, LOG_DIR, DEPLOY_DIR, AWS CLI v2 detection)
  - File: [deploy.sh](../../../deploy.sh) (main), [lib/logging.sh](../../../lib/logging.sh) (new), [lib/common.sh](../../../lib/common.sh) (new)

- [ ] **T003** **[P]** Create command routing structure for subcommands (deploy, update, rollback, validate, status, versions, destroy)
  - Implement: Subcommand parser with `case` statement
  - Implement: Help/usage output for each subcommand
  - File: [deploy.sh](../../../deploy.sh) (main control flow), [lib/cli.sh](../../../lib/cli.sh) (new)

- [ ] **T004** **[P]** Set up configuration management system (layered: defaults → config file → CLI args → env vars)
  - Implement: `.deployrc` YAML parser (using `jq` fallback if YAML parser unavailable)
  - Implement: CLI argument parsing for all flags (--domain, --subdomain, --region, --source-dir, --aws-profile, --dry-run)
  - Implement: Environment variable resolution with priority order
  - File: [lib/config.sh](../../../lib/config.sh) (new), `.deployrc` example (new)

- [ ] **T005** **[P]** Create AWS credential and permission validation framework
  - Implement: Functions to detect AWS CLI v2 installation and version
  - Implement: Functions to verify AWS credentials (AccessKey, assumed role, IAM role)
  - Implement: IAM permission checker (simulate policy evaluation for required permissions)
  - File: [lib/aws-common.sh](../../../lib/aws-common.sh) (new)

- [ ] **T004a** **[P]** Create .deployrc schema and validation framework
  - Implement: YAML schema definition (.deployrc.schema.json) with required fields (domain, region, source_dir)
  - Implement: Validation function to check .deployrc against schema (required fields, type checking, bounds validation)
  - Implement: Error reporting for schema violations (e.g., "domain must be valid FQDN")
  - File: [.deployrc.schema.json](.deployrc.schema.json) (new), [lib/config.sh](../../../lib/config.sh) (update)

- [ ] **T005a** **[P]** Implement secrets pattern detection and file scanning
  - Implement: `scan_file_for_secrets()` function detecting patterns: *.pem, *.key, *.env*, api_key, password, secret, token, credential
  - Implement: `validate_files_for_secrets()` scanning all files before upload; reject files matching patterns
  - Implement: Actionable error messages (e.g., "File 'config.env' contains secret patterns. Remove or add to .deployignore")
  - File: [lib/validation.sh](../../../lib/validation.sh) (update)

**Checkpoint**: Project skeleton with CLI framework + security foundation ready; Phase 2 can begin

---

## Phase 2: Foundational Infrastructure (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST exist before ANY user story implementation  
**Prerequisite**: Phase 1 complete  
**Completion Criteria**: All shared services initialized; all user stories can proceed in parallel

**⚠️ CRITICAL**: No Phase 3+ work can begin until Phase 2 is complete

### Tasks (8 total, tasks can be parallelized in two groups)

#### Group A: AWS API Wrappers & State Management

- [ ] **T006** **[P]** Implement AWS CloudFormation API wrapper functions
  - Implement: `cfn_stack_exists()`, `cfn_describe_stack()`, `cfn_get_stack_status()`, `cfn_create_stack()`, `cfn_update_stack()`
  - Implement: Stack output parser (extract S3 bucket, CloudFront domain, Route53 zone ID from stack outputs)
  - Implement: Stack event poller (monitor CREATE/UPDATE progress, report errors)
  - Error handling: Timeout after 10 minutes, retry logic with exponential backoff
  - File: [lib/cloudformation.sh](../../../lib/cloudformation.sh) (new)

- [ ] **T007** **[P]** Implement AWS S3 API wrapper functions for static site operations
  - Implement: `s3_bucket_exists()`, `s3_create_bucket()`, `s3_get_object_metadata()`, `s3_list_objects()`
  - Implement: `s3_upload_object()` with Content-Type and Cache-Control header support
  - Implement: File hash comparison (SHA256) for diff-based uploads
  - Implement: S3 versioning enable/disable
  - File: [lib/s3.sh](../../../lib/s3.sh) (new)

- [ ] **T008** **[P]** Implement AWS CloudFront API wrapper functions for cache invalidation
  - Implement: `cf_get_distribution()`, `cf_create_invalidation()`, `cf_describe_invalidation()`
  - Implement: Invalidation path optimizer (use `/*` for >100 files, else list specific paths)
  - Implement: Invalidation poller (monitor completion, timeout after 5 minutes)
  - File: [lib/cloudfront.sh](../../../lib/cloudfront.sh) (new)

- [ ] **T009** **[P]** Implement AWS Route 53 API wrapper functions for DNS management
  - Implement: `r53_zone_exists()`, `r53_get_zone_id()`, `r53_create_alias_record()`, `r53_list_records()`
  - Implement: DNS propagation checker (verify domain resolves to CloudFront)
  - File: [lib/route53.sh](../../../lib/route53.sh) (new)

#### Group B: File Operations & Version Management

- [ ] **T010** **[P]** Implement file discovery and filtering system with include/exclude patterns
  - Implement: `find_files_to_upload()` with include pattern matching (*.html, *.css, *.js, *.json, *.jpg, *.png, *.svg, *.webp, *.gif, *.ico, *.woff2, *.ttf)
  - Implement: Exclude pattern filtering (node_modules/, .git/, .env*, .DS_Store, *.md, *.tmp)
  - Implement: Configurable patterns via .deployrc
  - Implement: File inventory generator (list all files with sizes, hashes)
  - File: [lib/file-operations.sh](../../../lib/file-operations.sh) (new)

- [ ] **T011** **[P]** Implement version snapshot system using S3 metadata and local JSON manifests
  - Implement: `create_version_manifest()` (timestamp-based version ID: YYYYMMDD-HHMMSS)
  - Implement: Manifest storage in two locations: S3 (`versions/YYYYMMDD-HHMMSS.json`) and local (`.deploy/versions/YYYYMMDD-HHMMSS.json`)
  - Implement: `list_versions()`, `get_version_manifest()` for version history queries
  - Implement: Version metadata structure (version_id, timestamp, files[], subdomain, domain)
  - File: [lib/versioning.sh](../../../lib/versioning.sh) (new)

- [ ] **T012** **[P]** Implement health check and validation framework for post-deployment verification
  - Implement: `validate_aws_credentials()`, `validate_domain_format()`, `validate_source_directory()`, `validate_local_files_exist()`
  - Implement: `health_check_https_endpoint()` (verify HTTPS certificate valid, check TLS 1.2+)
  - Implement: `health_check_dns_resolution()` (verify domain resolves via Route53 to CloudFront)
  - Implement: `health_check_asset_loads()` (test loading 3-5 key assets via CloudFront)
  - Implement: Latency measurement (P50, P95, P99)
  - File: [lib/validation.sh](../../../lib/validation.sh) (new)

- [ ] **T013** **[P]** Implement state tracking system for tracking deployments and stack metadata
  - Implement: `.deploy/deployments/` directory for deployment records (YYYY-MM-DD.log, JSON outputs)
  - Implement: `.deploy/state.json` for tracking current stack info (domain, subdomain, region, stack ID, S3 bucket, CF distribution)
  - Implement: State persistence functions (`save_deployment_state()`, `load_deployment_state()`)
  - File: [lib/state.sh](../../../lib/state.sh) (new)

- [ ] **T041** **[SECURITY CRITICAL]** Integrate secrets scanning into deployment pipeline
  - Implement: Call `validate_files_for_secrets()` before any S3 upload (Phase 3 deploy/update)
  - Implement: Reject upload if secret patterns detected; display actionable error message
  - File: [lib/deploy-cmd.sh](../../../lib/deploy-cmd.sh) (update), [lib/update-cmd.sh](../../../lib/update-cmd.sh) (update)
  - **Note**: T005a must be complete before this task; security validation blocks Phase 3 start

**Checkpoint**: All foundational infrastructure ready; security framework in place; user story work can begin in parallel

---

## Phase 3: User Story 1 - Infrastructure Provisioning with Initial Content Deployment (Priority: P1)

**Goal**: Enable single command to provision all AWS infrastructure (S3, CloudFront, Route53, ACM) and deploy initial website content  
**Priority**: P1 (MVP-critical)  
**Independent Test**: Can deploy a complete website (all resources + files) to a new AWS account and access via HTTPS custom domain

**Acceptance Scenarios**:
1. Execute `./deploy.sh deploy --domain example.com --subdomain www` against empty AWS account → All resources created, website live, accessible via https://www.example.com
2. CloudFormation stack creates S3 bucket, CloudFront distribution, Route53 alias records, ACM certificate
3. All initial website files (HTML, CSS, JS, images) uploaded to S3 and served via CloudFront
4. Re-run deploy with same parameters → Stack updates idempotently (no duplicate resources)

### Tasks (12 total, organized in dependency order)

#### T014-T016: Deploy Command Framework

- [ ] **T014** **[P]** Implement `deploy` subcommand argument parsing and configuration loading
  - Parse and validate: --domain, --subdomain, --region (default: us-east-1), --source-dir (default: ./), --aws-profile, --dry-run
  - Load configuration from .deployrc (if exists) and merge with CLI arguments
  - Validate parameter combinations (domain format, subdomain format, region availability)
  - File: [lib/deploy-cmd.sh](../../../lib/deploy-cmd.sh) (new)

- [ ] **T015** **[P]** Implement pre-flight validation for deploy command
  - Validate: AWS credentials valid, IAM permissions sufficient (s3:*, cloudformation:*, cloudfront:*, route53:*, acm:*)
  - Validate: Domain name format (RFC 1123 compliance), subdomain format
  - Validate: Source directory exists and is readable
  - Validate: All local files to be deployed exist and are readable
  - Validate: S3 bucket name not already in use (check for existing bucket globally)
  - Validate: Route53 hosted zone exists for domain OR will be created by CloudFormation
  - Report: Clear error messages with actionable suggestions for each validation failure
  - File: [lib/deploy-cmd.sh](../../../lib/deploy-cmd.sh), [lib/validation.sh](../../../lib/validation.sh)

- [ ] **T016** **[P]** Implement stack naming and existence check logic
  - Generate predictable stack name: `{app-name}-website-{subdomain}-{domain}` (normalized, lowercase)
  - Query CloudFormation for existing stack with this name
  - If stack exists: determine mode (UPDATE_STACK) and verify parameters match
  - If stack doesn't exist: proceed with CREATE_STACK mode
  - Report: Clear message indicating which mode will execute
  - File: [lib/deploy-cmd.sh](../../../lib/deploy-cmd.sh), [lib/cloudformation.sh](../../../lib/cloudformation.sh)

#### T017-T019: CloudFormation Stack Provisioning

- [ ] **T017** Implement CloudFormation template generation/loading for static website infrastructure
  - Load existing template from [CloudFormation/s3-static-website.yaml](../../../CloudFormation/s3-static-website.yaml)
  - Validate template YAML syntax and CloudFormation compatibility
  - Verify template creates required resources: S3 bucket, CloudFront distribution, Route53 alias, ACM certificate, Origin Access Identity
  - Document template parameters: DomainName, SubdomainName, Environment, EnableLogging
  - File: [lib/deploy-cmd.sh](../../../lib/deploy-cmd.sh) (template loading), [CloudFormation/s3-static-website.yaml](../../../CloudFormation/s3-static-website.yaml) (verify/enhance)

- [ ] **T018** Implement CloudFormation stack creation workflow
  - Generate CloudFormation parameters from validated configuration (domain, subdomain, region, optional: ACM cert ARN)
  - Call `cfn_create_stack()` with generated parameters
  - If dry-run mode: validate parameters without executing create
  - Poll stack creation status every 10 seconds (timeout: 10 minutes)
  - Report resource creation progress (S3 bucket ARN, CloudFront distribution ID, Route53 zone ID, ACM certificate ARN)
  - Handle failures: Report CloudFormation events explaining why stack creation failed
  - File: [lib/deploy-cmd.sh](../../../lib/deploy-cmd.sh), [lib/cloudformation.sh](../../../lib/cloudformation.sh)

- [ ] **T019** Implement CloudFormation stack update workflow for existing stacks
  - Detect when stack already exists (CloudFormation UPDATE vs CREATE)
  - If parameters differ: warn user and require confirmation (prevent accidental infrastructure changes)
  - If parameters match: proceed with UPDATE (should report "no updates")
  - Poll stack update status (timeout: 10 minutes)
  - Report: Resource updates (if any), unchanged resources, any drift detection issues
  - File: [lib/deploy-cmd.sh](../../../lib/deploy-cmd.sh), [lib/cloudformation.sh](../../../lib/cloudformation.sh)

#### T020-T022: File Upload & Version Management

- [ ] **T020** **[P]** Implement initial file inventory and upload preparation
  - Scan source directory using include/exclude patterns
  - Calculate SHA256 hash for each file
  - Generate upload manifest (file path, hash, size, content-type)
  - Determine upload strategy: single batch vs. parallel batches (5 concurrent uploads)
  - If dry-run mode: report which files WOULD be uploaded (don't upload)
  - File: [lib/file-operations.sh](../../../lib/file-operations.sh), [lib/deploy-cmd.sh](../../../lib/deploy-cmd.sh)

- [ ] **T021** Implement parallel file upload to S3 with retry logic and resume capability
  - Upload files in batches of 5 concurrent uploads (balance throughput vs. connection limits)
  - Set appropriate headers per file type:
    - HTML: `Cache-Control: max-age=60` (60 seconds, fast updates)
    - CSS/JS: `Cache-Control: max-age=2592000` (30 days, assume fingerprinted)
    - Images: `Cache-Control: max-age=31536000` (1 year, immutable)
    - Manifests: `Cache-Control: max-age=0` (always fresh)
  - Implement retry logic: 3 attempts with exponential backoff (2s, 4s, 8s)
  - **Resume from checkpoint**: Track uploaded files in `.deploy/last-upload-state.json`; on re-run, skip already-uploaded files (verify via S3 etag)
  - Verify upload success: Compare local file hash with S3 object etag
  - Report progress every 10 files or every 5 seconds
  - Handle upload failures: Report which files failed, suggest retry with `--retry-uploads`
  - File: [lib/s3.sh](../../../lib/s3.sh), [lib/deploy-cmd.sh](../../../lib/deploy-cmd.sh)

- [ ] **T021a** Implement network failure recovery and upload resumption
  - Implement checkpoint system: `.deploy/last-upload-state.json` tracks successfully uploaded files (path, s3_key, etag, timestamp)
  - On deployment interruption: record which files uploaded before failure
  - On next run: Load checkpoint; skip files already uploaded (verify etag matches)
  - Implement rollback on verification failure: Delete uploaded files if manifest verification fails (all-or-nothing semantics)
  - File: [lib/s3.sh](../../../lib/s3.sh), [lib/state.sh](../../../lib/state.sh) (update)

- [ ] **T022** Implement version snapshot creation for initial deployment
  - Create version manifest JSON with: version_id (timestamp YYYYMMDD-HHMMSS), files[] (path, hash, size, s3_etag), domain, subdomain
  - Store version manifest in two locations:
    - S3: `s3://{bucket}/versions/{version_id}.json`
    - Local: `.deploy/versions/{version_id}.json`
  - Store deployment record: `.deploy/deployments/{YYYY-MM-DD}.log` with operation details
  - Generate deployment summary: files uploaded count, stack resources created, endpoints (S3, CloudFront, custom domain)
  - File: [lib/versioning.sh](../../../lib/versioning.sh), [lib/deploy-cmd.sh](../../../lib/deploy-cmd.sh)

#### T023-T025: Cache Invalidation & Health Checks

- [ ] **T023** **[P]** Implement CloudFront cache invalidation for initial deployment
  - Generate invalidation batch request: paths for all uploaded files (or `/*` if >100 files)
  - Submit invalidation request to CloudFront API
  - Poll invalidation status every 30 seconds (timeout: 5 minutes)
  - Report invalidation completion and cache clearing time
  - Handle failures: Log warning but don't fail deployment (cache will eventually expire)
  - File: [lib/cloudfront.sh](../../../lib/cloudfront.sh), [lib/deploy-cmd.sh](../../../lib/deploy-cmd.sh)

- [ ] **T024** **[P]** Implement post-deployment health checks (verify all resources working)
  - HTTP/HTTPS health check: GET https://www.{domain}/ → verify 200 status, valid TLS cert
  - DNS health check: resolve {domain} → verify resolves to CloudFront domain
  - Asset health checks: verify 3-5 key assets load (index.html, main.css, main.js, key image)
  - Measure latencies: DNS resolution, TLS handshake, TTFB, total page load
  - Report health check results: Pass/fail for each check, latency percentiles
  - If dry-run mode: skip health checks (they test actual resources)
  - File: [lib/validation.sh](../../../lib/validation.sh), [lib/deploy-cmd.sh](../../../lib/deploy-cmd.sh)

- [ ] **T025** **[P]** Implement deployment completion reporting and state persistence
  - Generate human-readable deployment summary:
    ```
    ✓ Infrastructure Deployment Complete
    Stack: website-www-example-com (arn:aws:cloudformation:...)
    S3 Bucket: website-www-example-com-s3bucket-abc123
    CloudFront: d123abc.cloudfront.net
    Custom Domain: www.example.com
    Version: 20260501-143022
    Files Deployed: 42
    Deployment Time: 3m 39s
    ```
  - Save deployment metadata to `.deploy/state.json` (current stack ID, domain, subdomain, region, S3 bucket, CF distribution, last deployed version)
  - Log full deployment record to `.deploy/deployments/2026-05-01.log`
  - Provide JSON output option (--json flag) for machine consumption
  - File: [lib/deploy-cmd.sh](../../../lib/deploy-cmd.sh), [lib/state.sh](../../../lib/state.sh)

- [ ] **T031a** **PERFORMANCE DESIGN** Verify parallel upload design meets <10 minute deploy target
  - Document parallel batch size: 5 concurrent uploads (justification: AWS throttle limits, typical latency ~1s per file)
  - Calculate typical deployment time: 50 files × 1s/file ÷ 5 parallel = 10s upload + 3m CF creation + 2m stack → ~6 min typical
  - Document optimization trade-offs: Larger batches (10) vs. connection stability
  - File: [lib/s3.sh](../../../lib/s3.sh) (add design comments), [PERFORMANCE.md](../../../PERFORMANCE.md) (new)

- [ ] **T036** Implement dry-run mode for deploy command (validate without AWS changes)
  - Flag: `./deploy.sh deploy --dry-run --domain example.com --subdomain www`
  - Behavior: Execute all validation steps (credentials, domain format, file existence, IAM permissions)
  - Report: Print what WOULD be created (CloudFormation stack resources, S3 files to upload) without creating anything
  - Skip: Skip health checks (they require actual deployed resources)
  - File: [lib/deploy-cmd.sh](../../../lib/deploy-cmd.sh) (update with --dry-run handling)
  - **Note**: T020 mentions dry-run; this task formalizes the feature

### Tests for User Story 1 (Integration/E2E)

- [ ] **T026** **[P]** [US1] Integration test: Deploy command creates all required resources
  - Test file: [tests/integration/test-us1-deploy-resources.sh](../../../tests/integration/test-us1-deploy-resources.sh) (new)
  - Verify: CloudFormation stack created with correct name
  - Verify: S3 bucket exists with versioning enabled
  - Verify: CloudFront distribution created
  - Verify: Route53 alias record points to CloudFront
  - Verify: ACM certificate provisioned for custom domain

- [ ] **T027** **[P]** [US1] Integration test: Initial files deployed and accessible via CloudFront
  - Test file: [tests/integration/test-us1-file-upload.sh](../../../tests/integration/test-us1-file-upload.sh) (new)
  - Verify: All files from source directory uploaded to S3
  - Verify: Files accessible via CloudFront distribution
  - Verify: HTTPS certificate valid for custom domain
  - Verify: Assets load with correct Content-Type headers
  - Measure: Page load time within acceptable range

**Checkpoint**: User Story 1 complete; website infrastructure provisioned and initial content deployed; Phase 4 can begin

---

## Phase 4: User Story 2 - Static Content Updates Post-Deployment (Priority: P1)

**Goal**: Enable rapid content updates (HTML, CSS, JS, images) without rebuilding infrastructure; updates published within 5 minutes  
**Priority**: P1 (MVP-critical)  
**Independent Test**: Can modify local files and run update command; changes appear live on CloudFront within 5 minutes

**Acceptance Scenarios**:
1. Execute `./deploy.sh update` after modifying index.html locally → Updated file uploaded to S3, CloudFront cache invalidated, changes live within 5 minutes
2. Modify multiple files (HTML, CSS, images) → All files uploaded in single atomic operation; changes appear simultaneously
3. Re-run update command without file changes → Only missing/changed files uploaded (no redundant uploads, idempotent)
4. Update interrupted by network error → Re-run update command, only failed files re-uploaded

### Tasks (10 total, organized in dependency order)

#### T028-T030: Update Command Framework

- [ ] **T028** **[P]** Implement `update` subcommand argument parsing and state loading
  - Parse optional arguments: --subdomain, --source-dir, --dry-run
  - Load saved deployment state from `.deploy/state.json` (domain, subdomain, region, S3 bucket, CF distribution)
  - If no saved state exists: prompt user to run deploy command first
  - Validate: Source directory exists, target stack exists in CloudFormation
  - File: [lib/update-cmd.sh](../../../lib/update-cmd.sh) (new)

- [ ] **T029** **[P]** Implement file change detection (diff between local files and S3 objects)
  - Load latest deployment version manifest from `.deploy/versions/{latest_version}.json`
  - Scan current local directory with include/exclude patterns
  - Calculate SHA256 hash for each local file
  - Query S3 for object metadata (etag, size, last-modified) for files in previous version
  - Compare hashes: identify added files, modified files, deleted files
  - Report: Which files changed, which will be uploaded, which were deleted
  - If no changes detected: report "No changes detected, skipping upload" and exit cleanly
  - File: [lib/update-cmd.sh](../../../lib/update-cmd.sh), [lib/file-operations.sh](../../../lib/file-operations.sh)

- [ ] **T030** **[P]** Implement selective file upload for changed files only
  - Upload only files identified as changed in T029
  - Reuse parallel upload logic from T021 (batches of 5 concurrent uploads, retry logic)
  - Verify: Upload success via etag comparison
  - Report progress: "Uploaded 3 files in 30 seconds"
  - If dry-run mode: report which files WOULD be uploaded (don't upload)
  - File: [lib/update-cmd.sh](../../../lib/update-cmd.sh), [lib/s3.sh](../../../lib/s3.sh)

#### T031-T033: CloudFront Invalidation & Version Management

- [ ] **T031** Implement selective CloudFront cache invalidation
  - Generate invalidation paths: only for changed files identified in T029
  - If >100 files changed: use `/*` (simpler invalidation)
  - If ≤100 files changed: list specific paths (more efficient)
  - Submit invalidation request to CloudFront API
  - Poll invalidation status (timeout: 5 minutes)
  - Report: Invalidation completed, cache will refresh in ~1-2 minutes
  - File: [lib/cloudfront.sh](../../../lib/cloudfront.sh), [lib/update-cmd.sh](../../../lib/update-cmd.sh)

- [ ] **T032** **[P]** Implement version snapshot creation for content updates
  - Generate new version manifest with: version_id (incremented timestamp), all current files (local state), changed file hashes
  - Store in two locations: S3 and local `.deploy/versions/`
  - Create deployment record: `.deploy/deployments/{YYYY-MM-DD}.log` with operation type (update), changed files count, timestamp
  - Update `.deploy/state.json` to reflect new current version
  - File: [lib/versioning.sh](../../../lib/versioning.sh), [lib/update-cmd.sh](../../../lib/update-cmd.sh)

- [ ] **T033** **[P]** Implement update completion reporting
  - Generate human-readable update summary:
    ```
    ✓ Content Update Complete
    Files Uploaded: 3 (index.html, main.css, image.png)
    CloudFront Invalidation: ID I1ABC2D3E4F5...
    Version: 20260501-144522 (previous: 20260501-143022)
    Update Time: 45s
    Changes live in: ~1-2 minutes
    ```
  - Save to deployment log
  - Provide JSON output option
  - File: [lib/update-cmd.sh](../../../lib/update-cmd.sh), [lib/state.sh](../../../lib/state.sh)

#### T034-T036: Health Checks & Rollback Preparation

- [ ] **T034** **[P]** Implement post-update health checks (spot-check key files)
  - HTTP health check: GET https://www.{domain}/ → verify 200 status
  - Asset health checks: verify 2-3 key changed files are accessible via CloudFront
  - Measure latencies: TTFB, page load time
  - Report: Verification results
  - If dry-run mode: skip health checks
  - File: [lib/validation.sh](../../../lib/validation.sh), [lib/update-cmd.sh](../../../lib/update-cmd.sh)

- [ ] **T035** **[P]** Implement rollback preparation (preserve current version for quick rollback)
  - Ensure current version manifest stored in S3 and locally
  - Verify version manifests include complete file list (needed for T037 rollback)
  - File: [lib/versioning.sh](../../../lib/versioning.sh), [lib/update-cmd.sh](../../../lib/update-cmd.sh)

- [ ] **T036** Implement idempotency for update command
  - Re-run update with no file changes → detect no changes, report "Up to date", exit 0
  - Re-run update after partial upload failure → resume upload from where it failed, complete successfully
  - Re-run update after CloudFront invalidation failure → retry invalidation
  - Ensure: No duplicate uploads, no data loss, consistent state
  - File: [lib/update-cmd.sh](../../../lib/update-cmd.sh)

### Tests for User Story 2 (Integration/E2E)

- [ ] **T037** **[P]** [US2] Integration test: Update command detects and uploads changed files
  - Test file: [tests/integration/test-us2-update-files.sh](../../../tests/integration/test-us2-update-files.sh) (new)
  - Verify: Only changed files uploaded (not all files)
  - Verify: File content in S3 matches local changes
  - Verify: Update completes in <5 minutes
  - Verify: CloudFront cache invalidated

- [ ] **T038** **[P]** [US2] Integration test: Update command is idempotent
  - Test file: [tests/integration/test-us2-idempotency.sh](../../../tests/integration/test-us2-idempotency.sh) (new)
  - Verify: Re-running update with no changes = no uploads
  - Verify: Re-running update after partial failure = resumes successfully

**Checkpoint**: User Stories 1 & 2 complete (MVP core); Phase 5 can begin (optional Phase 3+ features)

---

## Phase 5: User Story 3 - Multi-Subdomain Support (Priority: P2)

**Goal**: Support multiple subdomains (www, blog, docs) with separate content routing via CloudFront behaviors or separate S3 prefixes  
**Priority**: P2 (valuable, non-MVP)  
**Independent Test**: Can deploy to multiple subdomains; each serves distinct content; independent updates per subdomain

**Acceptance Scenarios**:
1. Deploy with `--subdomains www,blog` → CloudFront behaviors route www.example.com → s3://bucket/www/*, blog.example.com → s3://bucket/blog/*
2. Update blog content only: `./deploy.sh update --subdomain blog` → Only blog files uploaded, www content unaffected
3. Different subdomains have separate version histories and rollback capability

### Tasks (8 total)

- [ ] **T039** Implement multi-subdomain parameter validation
  - Extend deploy command to accept `--subdomains www,blog,docs` (comma-separated list)
  - Validate: Each subdomain is valid format, no duplicates, max 10 subdomains
  - Update CloudFormation template to accept SubdomainList parameter
  - File: [lib/deploy-cmd.sh](../../../lib/deploy-cmd.sh) (extend T014), [CloudFormation/s3-static-website.yaml](../../../CloudFormation/s3-static-website.yaml) (extend)

- [ ] **T040** **[P]** Implement CloudFront behavior generation for multi-subdomain routing
  - For each subdomain: create CloudFront behavior mapping subdomain → S3 prefix (subdomain name as prefix)
  - Example: www.example.com → s3://bucket/www/*, blog.example.com → s3://bucket/blog/*
  - Update CloudFormation template to generate behaviors dynamically
  - File: [CloudFormation/s3-static-website.yaml](../../../CloudFormation/s3-static-website.yaml), [lib/deploy-cmd.sh](../../../lib/deploy-cmd.sh)

- [ ] **T041** **[P]** Implement Route 53 alias record generation for multiple subdomains
  - Create Route 53 alias record for each subdomain pointing to CloudFront distribution
  - Update CloudFormation template to create multiple DNS records
  - Example: www.example.com, blog.example.com → all point to same CloudFront distribution
  - File: [CloudFormation/s3-static-website.yaml](../../../CloudFormation/s3-static-website.yaml)

- [ ] **T042** Implement multi-subdomain file upload with S3 prefix routing
  - Organize local files by subdomain: `./www/index.html`, `./blog/index.html` (or in separate directories)
  - When uploading: prepend subdomain prefix to S3 key (www/index.html → s3://bucket/www/index.html)
  - Support configuration: file structure (flat with prefix) or directory-based (subdomain directories)
  - File: [lib/file-operations.sh](../../../lib/file-operations.sh), [lib/deploy-cmd.sh](../../../lib/deploy-cmd.sh)

- [ ] **T043** **[P]** Implement multi-subdomain version tracking (separate histories per subdomain)
  - Version manifest per subdomain: `.deploy/versions/{version_id}-{subdomain}.json`
  - S3 storage: `s3://bucket/versions/{version_id}-{subdomain}.json`
  - Enable independent version tracking and rollback per subdomain
  - File: [lib/versioning.sh](../../../lib/versioning.sh)

- [ ] **T044** **[P]** Implement multi-subdomain update command (update specific subdomain only)
  - Extend update command: `./deploy.sh update --subdomain blog` → upload only blog files
  - Detect which subdomain files changed, upload only those with appropriate prefix
  - Update only the affected subdomain's version
  - File: [lib/update-cmd.sh](../../../lib/update-cmd.sh) (extend T028)

- [ ] **T045** Implement multi-subdomain CloudFront invalidation
  - When updating specific subdomain: invalidate paths for that subdomain only (e.g., `/blog/*`)
  - When updating all subdomains: invalidate `/*`
  - File: [lib/cloudfront.sh](../../../lib/cloudfront.sh), [lib/update-cmd.sh](../../../lib/update-cmd.sh)

- [ ] **T046** **[P]** [US3] Integration test: Multi-subdomain deployment and independent updates
  - Test file: [tests/integration/test-us3-multi-subdomain.sh](../../../tests/integration/test-us3-multi-subdomain.sh) (new)
  - Verify: Deploy creates alias records for all subdomains
  - Verify: Each subdomain serves distinct content
  - Verify: Update one subdomain without affecting others

**Checkpoint**: Multi-subdomain support complete; Phase 6 can begin

---

## Phase 6: User Story 4 - Rollback and Versioning (Priority: P2)

**Goal**: Rollback to previous website versions; preserve version history with timestamp-based identification  
**Priority**: P2 (important for production stability)  
**Independent Test**: Can rollback to any previous version; content restored correctly; previous version live within 2 minutes

**Acceptance Scenarios**:
1. Execute `./deploy.sh rollback --version 20260501-143022` → S3 objects restored to that version, CloudFront cache invalidated, previous version live
2. Execute `./deploy.sh rollback` (no version specified) → Rollback to immediately previous version
3. List versions: `./deploy.sh versions --list` → Shows all deployments with timestamps
4. Verify version before rollback: `./deploy.sh versions --show 20260501-143022` → Lists files in that version

### Tasks (7 total)

- [ ] **T047** Implement `rollback` subcommand argument parsing and version validation
  - Parse arguments: --version (optional, defaults to previous version), --confirm (skip confirmation prompt, required for CI/CD)
  - Load version manifest from `.deploy/versions/{version_id}.json`
  - Validate: Version exists locally and in S3
  - Report: What will be rolled back (file count, timestamp, affected domain/subdomain)
  - **SAFETY**: Always prompt user "Rollback will restore X files from version TIMESTAMP. Continue? (y/n)" unless --confirm flag provided
  - File: [lib/rollback-cmd.sh](../../../lib/rollback-cmd.sh) (new)

- [ ] **T048** **[P]** Implement version history querying
  - Implement `versions --list` subcommand to show all available versions
  - Output format: timestamp, version_id, file_count, subdomain
  - Sort by timestamp (newest first)
  - Support --limit parameter (default: 20 versions)
  - Support --json output
  - File: [lib/versioning.sh](../../../lib/versioning.sh), [lib/versions-cmd.sh](../../../lib/versions-cmd.sh) (new)

- [ ] **T049** **[P]** Implement detailed version information display
  - Implement `versions --show {version_id}` to display version details
  - Show: all files in version, hashes, sizes, timestamps
  - Support --json output for machine consumption
  - File: [lib/versions-cmd.sh](../../../lib/versions-cmd.sh), [lib/versioning.sh](../../../lib/versioning.sh)

- [ ] **T050** Implement atomic rollback restoration (all-or-nothing restore)
  - For each file in version manifest: copy from S3 versioned object to current key (or restore from version ID)
  - Ensure atomicity: if any file fails, rollback entire operation
  - Verify all files restored successfully
  - Report: Files restored count, timestamp of restored version
  - File: [lib/rollback-cmd.sh](../../../lib/rollback-cmd.sh), [lib/s3.sh](../../../lib/s3.sh)

- [ ] **T051** **[P]** Implement CloudFront cache invalidation after rollback
  - Invalidate `/*` to ensure all content refreshed
  - Poll invalidation completion (timeout: 5 minutes)
  - Report: Cache invalidation completed, content live in ~1-2 minutes
  - File: [lib/cloudfront.sh](../../../lib/cloudfront.sh), [lib/rollback-cmd.sh](../../../lib/rollback-cmd.sh)

- [ ] **T052** **[P]** Implement rollback completion reporting and audit logging
  - Generate rollback summary: from_version, to_version, files_restored, timestamp
  - Log rollback operation to `.deploy/deployments/` with details
  - Save new deployment state (current version = rolled-back version)
  - File: [lib/rollback-cmd.sh](../../../lib/rollback-cmd.sh), [lib/state.sh](../../../lib/state.sh)

- [ ] **T053** **[P]** [US4] Integration test: Rollback functionality
  - Test file: [tests/integration/test-us4-rollback.sh](../../../tests/integration/test-us4-rollback.sh) (new)
  - Verify: Rollback restores correct files
  - Verify: Rolled-back version is live within 2 minutes
  - Verify: Version history available and accurate

**Checkpoint**: Rollback and versioning complete; Phase 7 can begin

---

## Phase 7: User Story 5 - Deployment Validation and Dry-Run (Priority: P3)

**Goal**: Validate deployments before execution; dry-run mode shows what WILL be done without making AWS changes  
**Priority**: P3 (nice-to-have safety feature)  
**Independent Test**: Run dry-run against various configurations; verify validation errors reported clearly; verify no AWS resources modified

**Acceptance Scenarios**:
1. Execute `./deploy.sh deploy --dry-run --domain example.com` → Validates all checks without modifying AWS, reports results
2. Dry-run detects permission issue → Clear error message with suggestion for IAM policy update
3. Dry-run detects missing local files → Report which files not found, suggest solutions

### Tasks (6 total)

- [ ] **T054** Implement `--dry-run` flag handling across all commands
  - Add --dry-run flag to deploy, update, rollback, destroy commands
  - In dry-run mode: skip all AWS API calls that modify resources (create, update, delete, upload)
  - In dry-run mode: still query AWS for validation (describe, list operations)
  - Report: Summary of what WOULD happen (resources created/modified/deleted, files uploaded)
  - File: [lib/dry-run.sh](../../../lib/dry-run.sh) (new), extend all command files

- [ ] **T055** **[P]** Implement comprehensive pre-flight validation
  - Validate: AWS credentials exist and are valid (can connect to AWS)
  - Validate: IAM permissions sufficient for all planned operations
  - Validate: Domain format valid, not already in use by existing stack
  - Validate: Source directory and files exist and readable
  - Validate: CloudFormation template syntax valid
  - Validate: Naming conventions won't cause conflicts
  - Report: Each validation check result (pass/fail/warning)
  - File: [lib/validation.sh](../../../lib/validation.sh) (extend), [lib/deploy-cmd.sh](../../../lib/deploy-cmd.sh)

- [ ] **T056** **[P]** Implement policy simulation for IAM permission validation
  - Use AWS IAM `simulate-custom-policy` to test required permissions
  - Permissions needed: s3:*, cloudformation:*, cloudfront:*, route53:*, acm:*, iam:PassRole
  - Report: Which permissions are allowed, which are denied
  - Suggest: IAM policy changes needed if permissions missing
  - File: [lib/aws-common.sh](../../../lib/aws-common.sh), [lib/validation.sh](../../../lib/validation.sh)

- [ ] **T057** **[P]** Implement `validate` subcommand for standalone validation
  - Implement: `./deploy.sh validate --domain example.com --subdomain www`
  - Run all pre-flight checks without executing any deployment
  - Report: Summary of all validation results
  - Use --json flag for machine-readable output
  - File: [lib/validate-cmd.sh](../../../lib/validate-cmd.sh) (new)

- [ ] **T058** **[P]** Implement actionable error messages and suggestions
  - For each validation failure: provide clear reason + suggestion for resolution
  - Examples:
    - "IAM role missing s3:PutObject permission" → "Add this policy to your role: ..."
    - "Domain already exists in another stack" → "Use different domain or run `./deploy.sh destroy` on other stack"
    - "Local file missing: index.html" → "Create file at ./index.html or specify --source-dir"
  - File: [lib/validation.sh](../../../lib/validation.sh), error message library

- [ ] **T059** **[P]** [US5] Integration test: Dry-run and validation
  - Test file: [tests/integration/test-us5-validation.sh](../../../tests/integration/test-us5-validation.sh) (new)
  - Verify: Dry-run doesn't create/modify AWS resources
  - Verify: Dry-run reports what would be done
  - Verify: Validation detects missing files, permissions, format errors

**Checkpoint**: User Story 5 complete; all MVP and P2 features implemented; Phase 8 can begin

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Finalization, testing, documentation, performance optimization, error handling improvements  
**Prerequisite**: All user stories complete (Phases 3-7)  
**Completion Criteria**: Feature production-ready; comprehensive test coverage; documentation complete; performance meets targets

### Tasks (10 total, parallelizable in groups)

#### Group A: Documentation & Configuration

- [ ] **T060** **[P]** Create comprehensive README and usage documentation
  - File: [README.md](../../../README.md) (update with deployment guide)
  - Include: Quick start, command reference, parameter guide, examples, troubleshooting
  - Include: Architecture diagram, performance expectations, cost estimates
  - Include: Security considerations, IAM policy template

- [ ] **T061** **[P]** Create .deployrc template and configuration documentation
  - File: [.deployrc.example](../../../.deployrc.example) (new)
  - Document: All configuration options, defaults, examples
  - Document: File inclusion/exclusion patterns with examples
  - Include: Comments explaining each option

- [ ] **T062** **[P]** Create deployment script inline documentation (comments)
  - Add: Detailed function docstrings (purpose, parameters, return values, error handling)
  - Add: Inline comments explaining complex logic
  - File: [deploy.sh](../../../deploy.sh), [lib/*.sh](../../../lib/) (all)

#### Group B: Error Handling & Resilience

- [ ] **T063** Implement comprehensive error handling and recovery
  - Implement: Graceful handling of all identified error categories (T2-T6 from plan.md Error Handling Strategy)
  - Implement: Retry logic with exponential backoff for transient failures
  - Implement: Partial failure recovery (resume from where it failed)
  - Implement: Consistent exit codes (0=success, 1=general error, 2=validation, 3=AWS error, 4=CFN error, 5=file error, 6=network error, 7=config error)
  - File: [lib/error-handling.sh](../../../lib/error-handling.sh) (new), [deploy.sh](../../../deploy.sh)

- [ ] **T064** Implement timeout handling and graceful degradation
  - Implement: Configurable timeouts for CloudFormation (default 10 min), CloudFront (default 5 min), health checks (default 60 sec)
  - Implement: Health check degradation (deployment succeeds even if health checks fail; report warning)
  - Implement: CloudFront invalidation degradation (deployment succeeds even if invalidation times out; cache will expire eventually)
  - File: [lib/common.sh](../../../lib/common.sh), [lib/deploy-cmd.sh](../../../lib/deploy-cmd.sh)

#### Group C: Testing & Quality

- [ ] **T065** **[P]** Create unit test suite for Bash functions
  - Test file: [tests/unit/test-argument-parsing.sh](../../../tests/unit/test-argument-parsing.sh) (new)
  - Test file: [tests/unit/test-file-operations.sh](../../../tests/unit/test-file-operations.sh) (new)
  - Test file: [tests/unit/test-validation.sh](../../../tests/unit/test-validation.sh) (new)
  - Mock AWS CLI calls to avoid real AWS operations
  - Test 15-20 critical functions with happy path + error cases

- [ ] **T066** **[P]** Create end-to-end test suite for full workflows
  - Test file: [tests/e2e/test-deploy-update-rollback.sh](../../../tests/e2e/test-deploy-update-rollback.sh) (new)
  - Full workflow: deploy → update → verify → rollback → verify
  - Use staging AWS account for real AWS operations
  - Clean up test resources after each test run

#### Group D: Performance & Optimization

- [ ] **T067** **[P]** Optimize file upload parallelization and performance
  - Benchmark: Measure upload time for 50, 100, 500 files
  - Tune: Concurrent upload batch size (currently 5; test 3, 5, 10)
  - Optimize: Parallel health checks (run 3-5 checks concurrently)
  - Document: Performance metrics and tuning guide
  - File: [lib/s3.sh](../../../lib/s3.sh), performance benchmarking script

- [ ] **T068** **[P]** Implement progress reporting and status output enhancements
  - Implement: Progress bars for file uploads (X/Y files, percentage)
  - Implement: Timing information (elapsed time, ETA)
  - Implement: Verbose logging mode (--verbose flag for debugging)
  - Implement: Color-coded output (✓ success, ✗ error, ⊳ progress)
  - File: [lib/logging.sh](../../../lib/logging.sh), [deploy.sh](../../../deploy.sh)

#### Group E: Production Readiness

- [ ] **T069** **[P]** Create security audit checklist
  - File: [SECURITY.md](../../../SECURITY.md) (new)
  - Document: Credential handling practices, S3 security settings, CloudFront HTTPS enforcement
  - Document: IAM least-privilege policy template
  - Document: Logging and audit trail practices
  - Document: How to report security issues

- [ ] **T070** **[P]** Create operations guide and troubleshooting documentation
  - File: [OPERATIONS.md](../../../OPERATIONS.md) (new)
  - Document: Common issues and resolution steps
  - Document: How to monitor deployments, check CloudFormation events
  - Document: How to manually clean up failed deployments
  - Document: Cost monitoring and optimization tips

### Documentation Files Required

- [README.md](../../../README.md) - Updated with AWS deployment guide
- [.deployrc.example](../../../.deployrc.example) - Configuration template
- [SECURITY.md](../../../SECURITY.md) - Security practices and IAM policy
- [OPERATIONS.md](../../../OPERATIONS.md) - Operations guide and troubleshooting
- [ARCHITECTURE.md](../../../ARCHITECTURE.md) - Optional: detailed architecture documentation

**Checkpoint**: Feature production-ready; comprehensive documentation complete; all phases complete

---

## 📦 Dependency Graph: User Stories

```
        US1 (Deploy)
            ↓
            ├→ Creates infrastructure
            ├→ Uploads initial files
            └→ BLOCKS: US2, US3, US4, US5

        US2 (Update)
            ↓
            ├→ Depends on US1 infrastructure
            ├→ Uploads changed files
            └→ ENABLES: US4 (version history)

        US3 (Multi-Subdomain)
            ↓
            ├→ Extends US1 (multiple subdomains)
            ├→ Extends US2 (subdomain-specific updates)
            └→ Independent: can be implemented separately

        US4 (Rollback)
            ↓
            ├→ Depends on US2 (version tracking)
            ├→ Reverts to previous versions
            └→ Independent: no other stories depend on it

        US5 (Validation)
            ↓
            ├→ Supports all other stories
            ├→ Pre-flight validation
            └→ Dry-run mode
```

### Parallel Execution Opportunities

**Fully Parallel (no dependencies)**:
- T006-T009: All AWS API wrappers (CloudFormation, S3, CloudFront, Route53)
- T010-T013: File operations, versioning, health checks, state management
- T026-T027: US1 tests
- T037-T038: US2 tests
- T060-T062: Documentation tasks
- T065-T068: Testing and performance optimization

**Sequential Dependencies**:
- T017 → T018 (deploy creation needs template)
- T029 → T030 (detect changes before uploading)
- T050 → T051 (restore files before invalidating cache)

---

## 🎯 Success Metrics & Acceptance Criteria

### Per-Phase Acceptance

**Phase 1 Complete When**:
- [ ] CLI framework with subcommand routing working
- [ ] Configuration management system functional
- [ ] AWS credential detection working

**Phase 2 Complete When**:
- [ ] All AWS API wrappers functional (tested with mocks)
- [ ] File operations with include/exclude patterns working
- [ ] Version management system functional
- [ ] Health check framework ready

**Phase 3 Complete When**:
- [ ] Deploy command provisions infrastructure (S3, CloudFront, Route53, ACM)
- [ ] All initial files uploaded to S3
- [ ] Website accessible via HTTPS custom domain
- [ ] Idempotent redeployment works
- [ ] Both integration tests passing

**Phase 4 Complete When**:
- [ ] Update command detects changed files
- [ ] Changed files uploaded to S3
- [ ] CloudFront cache invalidated
- [ ] Updates live within 5 minutes
- [ ] Both integration tests passing

**Phase 5 Complete When**:
- [ ] Deploy supports --subdomains parameter
- [ ] CloudFront behaviors route subdomains correctly
- [ ] Route53 creates alias records for each subdomain
- [ ] Independent subdomain updates work
- [ ] Integration test passing

**Phase 6 Complete When**:
- [ ] Version history tracked and queryable
- [ ] Rollback command restores specific version
- [ ] Rollback completes in <2 minutes
- [ ] Content restored correctly
- [ ] Integration test passing

**Phase 7 Complete When**:
- [ ] Dry-run mode shows what would be done
- [ ] No AWS resources modified in dry-run
- [ ] Validation detects errors (missing files, permissions, format)
- [ ] Error messages actionable
- [ ] Integration test passing

**Phase 8 Complete When**:
- [ ] README and documentation comprehensive
- [ ] IAM policy template provided
- [ ] Unit tests cover 15+ functions
- [ ] E2E tests verify full workflows
- [ ] Performance benchmarks documented

### Feature-Level Success Criteria (from spec)

- [ ] SC-001: Initial deployment <10 min
- [ ] SC-002: Content updates <5 min
- [ ] SC-003: Redeployment idempotent
- [ ] SC-004: 95%+ first-attempt success rate
- [ ] SC-005: Error messages actionable
- [ ] SC-006: Rollback completes <2 min
- [ ] SC-007: Network interruptions handled gracefully
- [ ] SC-008: Costs <$1/month (under 10GB)
- [ ] SC-009: All assets load successfully
- [ ] SC-010: 100% of files uploaded correctly

---

## 📈 Estimation Summary

| Phase | Tasks | Estimated Duration | Dependencies | Parallelizable |
|-------|-------|-------------------|--------------|---|
| **Phase 1** | 5 | 3-4 days | None | 5/5 (fully) |
| **Phase 2** | 8 | 5-7 days | Phase 1 | 8/8 (fully) |
| **Phase 3** | 12 | 7-10 days | Phase 2 | 6/12 (T026-T027 parallel) |
| **Phase 4** | 10 | 5-7 days | Phase 3 | 6/10 (tests parallel) |
| **Phase 5** | 8 | 5-7 days | Phase 3 | 5/8 (tests parallel) |
| **Phase 6** | 7 | 4-6 days | Phase 4 | 6/7 (tests parallel) |
| **Phase 7** | 6 | 3-5 days | All stories | 5/6 (tests parallel) |
| **Phase 8** | 10 | 5-7 days | Phases 3-7 | 10/10 (fully) |
| | **66** | **37-53 days** | | |

**With 1 Engineer**: 6-8 weeks (assuming 5-7 working days/week, some parallel work)  
**With 2 Engineers**: 3-4 weeks (leverage full parallelization)

---

## 🔗 Cross-References

**Related Documents**:
- Feature Specification: [aws-static-website-cfn-deployment.md](aws-static-website-cfn-deployment.md)
- Implementation Plan: [plan.md](plan.md)
- CloudFormation Template: [CloudFormation/s3-static-website.yaml](../../../CloudFormation/s3-static-website.yaml)

**Key Files to Create/Update**:
- `deploy.sh` - Main deployment script
- `lib/*.sh` - Library modules (15 files)
- `tests/unit/*.sh` - Unit tests
- `tests/integration/*.sh` - Integration tests
- `tests/e2e/*.sh` - End-to-end tests
- `CloudFormation/s3-static-website.yaml` - Infrastructure template
- `README.md`, `SECURITY.md`, `OPERATIONS.md` - Documentation

