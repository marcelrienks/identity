# Feature Specification: AWS Static Website with Unified CloudFormation Deployment

**Feature Branch**: `001-aws-static-website-cfn`  
**Created**: 2026-05-02  
**Status**: Complete  
**Input**: User description: "Static website with unified CloudFormation deployment and update script. End result: static website deployed to AWS S3 with Route 53 domain and custom subdomain. Ability to provision infrastructure and upload initial files via CloudFormation. Ability to update static site content post-deployment. Both deployment and updates achieved through same unified script with deploy and update commands. No Terraform or other deployment tools."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Infrastructure Provisioning with Initial Content Deployment (Priority: P1)

A DevOps engineer provisions the complete production infrastructure for a static website portfolio hosted on AWS. The engineer runs a single command to automatically create all necessary AWS resources (S3 bucket, CloudFront distribution, Route 53 DNS records) and deploys initial HTML, CSS, JavaScript, and image files to S3.

**Why this priority**: This is the foundational capability. Without this, no website exists. This is the MVP upon which all other features depend and delivers complete, testable value.

**Independent Test**: Can be fully tested by running deploy command against a staging AWS account and verifying that: (1) all required AWS resources are created via CloudFormation, (2) initial website files are uploaded to S3, (3) CloudFront is serving the content, (4) custom subdomain resolves to CloudFront distribution.

**Acceptance Scenarios**:

1. **Given** no AWS resources exist for the website, **When** engineer executes `./deploy.sh deploy --domain example.com --subdomain www`, **Then** CloudFormation stack creates S3 bucket, CloudFront distribution, Route 53 hosted zone/records, and all initial website files appear in S3.
2. **Given** CloudFormation has provisioned infrastructure, **When** engineer navigates to `https://www.example.com`, **Then** the homepage loads successfully with all assets (CSS, JS, images) rendering correctly via CloudFront.
3. **Given** a partially failed deployment, **When** engineer re-runs the deploy command, **Then** CloudFormation updates existing stack (idempotent operation) and missing files are uploaded without data loss.

---

### User Story 2 - Static Content Updates Post-Deployment (Priority: P1)

After the initial website is live, the engineer needs to update website content (HTML files, images, CSS) without rebuilding infrastructure. A single unified command allows quick content updates to the live site while preserving all CloudFormation-managed infrastructure.

**Why this priority**: This is equally critical as deployment. The ability to push content updates is essential for maintaining a live website and delivers immediate value without requiring infrastructure changes.

**Independent Test**: Can be fully tested by: (1) provisioning infrastructure with initial content (P1), (2) modifying local website files, (3) running update command, (4) verifying updated content is live on CloudFront within 5 minutes (accounting for CDN invalidation).

**Acceptance Scenarios**:

1. **Given** website is deployed and live, **When** engineer updates `index.html` locally and runs `./deploy.sh update`, **Then** updated file is uploaded to S3 and CloudFront cache is invalidated so new content appears within 5 minutes.
2. **Given** multiple files are modified (HTML, CSS, images), **When** engineer runs `./deploy.sh update`, **Then** all modified files are uploaded in a single atomic operation and changes appear live without manual cache invalidation.
3. **Given** an update is in progress and network fails, **When** engineer re-runs `./deploy.sh update`, **Then** only missing/changed files are uploaded (no redundant uploads) and operation completes successfully.

---

### User Story 3 - Multi-Subdomain Support (Priority: P2)

Engineer needs to host related static websites on different subdomains (e.g., `www.example.com`, `blog.example.com`, `docs.example.com`) using CloudFront to serve different S3 prefixes or separate buckets, all managed by a single deployment script.

**Why this priority**: This is valuable for organizations that need multiple properties but want unified infrastructure management. It extends the core MVP without blocking the primary value proposition.

**Independent Test**: Can be tested by provisioning infrastructure for multiple subdomains and verifying each subdomain resolves to CloudFront and serves distinct content.

**Acceptance Scenarios**:

1. **Given** deploy configuration specifies multiple subdomains, **When** engineer runs `./deploy.sh deploy --domain example.com --subdomains www,blog`, **Then** Route 53 creates DNS records for each subdomain, CloudFront behaviors route each to appropriate S3 prefix, and content loads separately for each.
2. **Given** `blog.example.com` content is updated, **When** engineer runs `./deploy.sh update --subdomain blog`, **Then** only blog content is updated and www.example.com remains unaffected.

---

### User Story 4 - Rollback and Versioning (Priority: P2)

Engineer needs to quickly revert to a previous version of the website if a content update introduces breaking changes or issues. Previous versions are preserved with timestamps for easy rollback.

**Why this priority**: Essential for production stability. Provides safety net for updates but is not required for initial deployment MVP.

**Independent Test**: Can be tested by deploying version 1, updating to version 2, then rolling back and confirming version 1 content is restored.

**Acceptance Scenarios**:

1. **Given** website has been updated multiple times, **When** engineer runs `./deploy.sh rollback --version 20260501-143022`, **Then** S3 content reverts to the specified timestamp and CloudFront cache is invalidated.
2. **Given** no version is specified, **When** engineer runs `./deploy.sh rollback`, **Then** site reverts to immediately previous version.

---

### User Story 5 - Deployment Validation and Dry-Run (Priority: P3)

Engineer wants confidence that a deployment or update will succeed before actually executing it. A dry-run mode validates all resources, permissions, and files without making any AWS changes.

**Why this priority**: Nice-to-have safety feature. Reduces production incidents but not critical for MVP.

**Independent Test**: Can be tested by running dry-run against various configurations and verifying all validation checks pass before actual deployment.

**Acceptance Scenarios**:

1. **Given** engineer wants to validate a deployment, **When** running `./deploy.sh deploy --dry-run --domain example.com`, **Then** script validates AWS credentials, checks for naming conflicts, verifies all local files exist, and reports results without modifying any AWS resources.
2. **Given** dry-run detects a permission issue, **When** results are displayed, **Then** error message is clear and actionable (e.g., "IAM role missing s3:PutObject permission").

---

### Edge Cases

- What happens when AWS S3 bucket already exists but CloudFormation stack doesn't? (Handled by checking for existing resources before creating)
- How does the system handle extremely large websites (100GB+)? (Batched uploads, timeout-resilient)
- What if Route 53 hosted zone already exists for the domain? (Script checks and uses existing zone)
- What happens if an engineer accidentally deploys with wrong domain configuration? (CloudFormation rollback and confirmation prompts)
- How does the system handle files that should NOT be deployed (node_modules, .git, .env)? (Explicit inclusion list with sensible defaults)
- What if subdomain is already in use by another service? (Validation check prevents overwrite with confirmation prompt)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST accept a unified deployment command (`./deploy.sh deploy`) that provisions all AWS infrastructure via CloudFormation in a single operation
- **FR-002**: System MUST accept an update command (`./deploy.sh update`) that uploads modified website files to S3 without rebuilding infrastructure
- **FR-003**: System MUST support custom domain and subdomain configuration via command-line arguments or configuration file
- **FR-004**: System MUST automatically create S3 bucket with versioning enabled for content preservation and rollback capability
- **FR-005**: System MUST configure CloudFront distribution to serve S3 content with proper caching headers and cache invalidation on updates
- **FR-006**: System MUST create Route 53 DNS records mapping domain/subdomains to CloudFront distribution
- **FR-007**: System MUST support HTTPS/TLS with ACM certificate provisioning for custom domains
- **FR-008**: System MUST validate all local website files before deployment and report missing or invalid files
- **FR-009**: System MUST implement idempotent operations so re-running deploy/update commands does not cause failures or data loss
- **FR-010**: System MUST exclude non-deployable files (node_modules, .git, .env files, temporary files) based on configurable exclusion patterns
- **FR-011**: System MUST support rollback to previous website versions with timestamp-based version tracking
- **FR-012**: System MUST provide detailed status output showing which resources are being created/updated and their current state
- **FR-013**: System MUST support dry-run mode that validates all operations without making AWS changes
- **FR-014**: System MUST preserve existing CloudFormation stack parameters when updating to prevent unintended resource changes
- **FR-015**: System MUST require explicit AWS credentials (via environment variables or IAM role) and never embed secrets in code. Script MUST scan all files before upload for secrets patterns (*.pem, *.key, *.env*, credentials, api_key, password) and reject files matching patterns with actionable error message.
- **FR-016**: System MUST use CloudFormation exclusively for infrastructure provisioning with no external tools (Terraform, Ansible, etc.)
- **FR-017**: System MUST support automatic retry logic for file uploads and CloudFront invalidations (3 retries with exponential backoff: 2s, 4s, 8s). Resume uploads from last successfully uploaded file; do not re-upload unchanged files.

### Key Entities

- **Website Stack**: A CloudFormation stack representing all AWS resources for a single website domain (S3 bucket, CloudFront, Route 53 records). Attributes: domain name, subdomains, region, creation timestamp, stack ID.
- **Content Version**: A timestamped snapshot of website files. Attributes: version ID, timestamp, file manifest, S3 prefix, rollback-able status.
- **Deployment Configuration**: User-provided settings for a deployment. Attributes: domain, subdomains, region, S3 bucket naming convention, ACM certificate settings, file exclusion patterns, CloudFront behaviors.
- **CloudFront Distribution**: AWS CDN resource serving website content. Relationships: connected to one S3 origin, mapped to domain via Route 53.
- **S3 Bucket**: AWS object storage for website files. Relationships: contains website content organized by version or subdomain prefix.
- **Route 53 Hosted Zone**: AWS DNS managed zone for custom domain. Relationships: contains A records mapping domain/subdomains to CloudFront distribution.
- **CloudFormation Stack**: Infrastructure-as-code template describing all website resources. Attributes: stack name, outputs (S3 bucket, CloudFront domain, hosted zone ID).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Initial website deployment from code checkout to live HTTPS endpoint completes in under 10 minutes with zero manual AWS console steps
- **SC-002**: Content updates publish to live website within 5 minutes of running update command (including CloudFront cache invalidation)
- **SC-003**: Redeployment of identical infrastructure is idempotent and completes without errors (CloudFormation stack update succeeds)
- **SC-004**: 95% of deploy and update commands succeed on first invocation, excluding user configuration errors (invalid domain format, missing credentials, insufficient IAM permissions). AWS transient service errors are counted as failures and drive retry logic.
- **SC-005**: Error messages are actionable and guide users to resolution within 2 attempts (measured via error taxonomy and user feedback)
- **SC-006**: Rollback to previous version completes in under 2 minutes and restores correct content
- **SC-007**: Script handles network interruptions gracefully and resumes from where it failed without data loss or duplication
- **SC-008**: Infrastructure costs remain under $1/month for websites under 10GB with <1TB/month global traffic. Cost breakdown: S3 storage (~$0.05), CloudFront data transfer (~$0.50), Route53 DNS (~$0.50), ACM (free). Estimate scales linearly with traffic.
- **SC-009**: All website assets (HTML, CSS, JS, images) load successfully via HTTPS with zero TLS errors
- **SC-010**: 100% of specified files are uploaded correctly with no missing or corrupted content
- **SC-011**: Network failures during upload are retried automatically; 95% of interrupted uploads resume successfully from last checkpoint without data loss

## Assumptions

- AWS account is already provisioned and credentials are available via environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY) or IAM role
- Route 53 hosted zone must either be newly created or already exist (script will not migrate existing domains from other DNS providers)
- Domain registrar (GoDaddy, Route 53 Registrar, etc.) is configured to use AWS Route 53 nameservers for DNS delegation
- Website files are in a local directory (default: `./` or configurable via `--source-dir` parameter)
- ACM certificate can be auto-created and auto-validated via Route 53 DNS validation (no manual email validation required)
- CloudFront origin access is restricted to S3 bucket (no direct S3 web hosting endpoint used)
- Website content does NOT require server-side processing (static assets only; Node.js, PHP, Python backends out of scope)
- Deployment is performed by users with sufficient AWS IAM permissions (s3:*, cloudfront:*, route53:*, cloudformation:*, acm:*, iam:PassRole)
- CloudFormation stack naming convention is predictable and collision-free (e.g., `identity-website-www-example-com`)
- Initial deployment provisions a single website; multi-tenant/multi-organization scenarios are out of scope for v1
- **PRODUCTION-ONLY**: v1 supports single AWS account for production deployments. Multi-account support (staging/production separation) is deferred to v2 roadmap.
- Website traffic is expected to be moderate (not millions of concurrent users) within CloudFront default quotas

## Dependencies

### External Systems

- **AWS CloudFormation**: Required for infrastructure provisioning; must be available in target region
- **AWS S3**: Required for static file storage; must support versioning and CORS (enabled by default)
- **AWS CloudFront**: Required for CDN/caching; must support Lambda@Edge (optional, not required for v1)
- **AWS Route 53**: Required for DNS; must support alias records pointing to CloudFront distributions
- **AWS ACM**: Required for HTTPS certificate provisioning; must auto-validate via DNS (Route 53 integration)

### System Dependencies

- **Bash/Shell**: Script must run on macOS, Linux (Ubuntu, CentOS, Amazon Linux); Windows PowerShell support is out of scope for v1
- **AWS CLI v2**: Must be installed and configured with valid credentials
- **jq** (JSON query tool): Optional but recommended for parsing CloudFormation outputs
- **curl or wget**: For basic HTTP health checks during deployment
- **Git** (optional): For version control and tracking deployment history in repository

### Existing Project Assets

- [CloudFormation template](./CloudFormation/s3-static-website.yaml): Contains S3, CloudFront, Route 53, ACM resource definitions
- Website content files (HTML, CSS, JS, images): Located in `./assets/` and root directory
- Local configuration file support (`.deployrc` or similar)

## Scope Boundaries

### In Scope

- Provisioning S3 bucket, CloudFront distribution, Route 53 DNS records via single CloudFormation stack
- Uploading website files to S3 with intelligent diff (only changed files uploaded)
- CloudFront cache invalidation on content updates
- HTTPS/TLS certificate provisioning and renewal via ACM
- Custom domain and subdomain routing via Route 53
- Version history and rollback capability
- Dry-run validation mode
- Configuration via CLI arguments and configuration files
- Error handling and idempotency
- IAM permission validation
- AWS credential handling (environment variables, IAM roles, credential profiles)

### Out of Scope

- Multi-region failover or disaster recovery (single region deployment)
- Database or backend API integration (static assets only)
- Continuous deployment/CI-CD integration (manual trigger only for v1)
- Custom Lambda@Edge functions or routing rules (basic CloudFront caching only)
- S3 object-level encryption beyond default (default SSE-S3 is sufficient)
- DDoS protection (CloudFlare, AWS Shield Advanced - out of scope)
- Content delivery to multiple AWS regions (single region)
- Monitoring, metrics, alerting dashboards (can be added in v2)
- Cost optimization recommendations (auto-scaling, reserved capacity)
- Terraform, Ansible, or other IaC tools (CloudFormation exclusive)
- Windows Server PowerShell scripts (Bash/Linux only)
- Support for static site generators (Jekyll, Hugo, etc.) - deployment assumes pre-built files

## Constitution Compliance *(mandatory for infrastructure features)*

- **Infrastructure-as-Code First**: ✅ All AWS resources are defined declaratively in CloudFormation template, version controlled in repository, no manual AWS console provisioning required.
- **Idempotency**: ✅ Redeploying with identical parameters updates existing CloudFormation stack safely; no duplicate resources created.
- **Security by Default**: ✅ S3 bucket is private with no public ACL; CloudFront provides only access point; ACM enables HTTPS/TLS by default; no secrets in code or repository; IAM role required for execution.
- **Least Privilege Access**: ✅ Script requires minimal IAM permissions (S3 bucket access, CloudFront invalidation, Route 53 records, CloudFormation describe/create/update); unused services not accessed.
- **Observability**: ✅ CloudFormation events logged; S3 access logging enabled; CloudFront access logs optional but recommended; CloudTrail captures all API calls; deployment outputs include resource IDs and status.
- **Performance and Availability**: ✅ CloudFront CDN edge locations provide global distribution; S3 provides 99.99% availability; Route 53 health checks supported (optional); typical response time <1 second via CDN.
- **Cost Governance**: ✅ Resource limits documented (CloudFront data transfer limits, S3 storage); script can report estimated monthly costs; CloudFormation drift detection available.
- **Documentation**: ✅ README with deployment runbook included; inline script comments explain key operations; CloudFormation template includes parameter descriptions; error messages are actionable.
- **Disaster Recovery**: ✅ S3 versioning enabled for content preservation; previous versions recoverable via rollback; CloudFormation stack can be deleted and recreated from code.
