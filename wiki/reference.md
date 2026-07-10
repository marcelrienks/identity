# Reference

This page is the command and configuration reference for the deployment tool.

## Commands

### deploy

```bash
./deploy.sh deploy [OPTIONS]
```

Supported options:

- `--domain DOMAIN` (required)
- `--subdomain SUBDOMAIN` (default: `www`)
- `--region REGION` (default: `us-east-1`)
- `--source-dir PATH` (default: `./`)
- `--aws-profile PROFILE` (default: `default`)
- `--certificate-arn ARN`
- `--s3-bucket-name NAME`
- `--cloudfront-distribution-id ID`
- `--dry-run`
- `-v`, `--verbose`
- `-h`, `--help`

Example:

```bash
./deploy.sh deploy --domain example.com --subdomain www
```

### update

```bash
./deploy.sh update [OPTIONS]
```

Supported options:

- `--subdomain SUBDOMAIN`
- `--source-dir PATH`
- `--version major|minor`
- `--dry-run`
- `-v`, `--verbose`

Example:

```bash
./deploy.sh update --version major
```

### rollback

```bash
./deploy.sh rollback [OPTIONS]
```

Supported options:

- `--version VERSION`
- `--confirm`
- `-h`, `--help`

Example:

```bash
./deploy.sh rollback --version 1.0.0
```

### versions

```bash
./deploy.sh versions [list|show] [OPTIONS]
```

Supported options:

- `list` (default)
- `show VERSION`
- `--limit N`
- `--json`
- `-h`, `--help`

Example:

```bash
./deploy.sh versions list --limit 10
```

### validate

```bash
./deploy.sh validate [OPTIONS]
```

Supported options:

- `--domain DOMAIN` (required)
- `--subdomain SUBDOMAIN`
- `--region REGION`
- `--source-dir PATH`
- `--aws-profile PROFILE`
- `--json`
- `-h`, `--help`

Example:

```bash
./deploy.sh validate --domain example.com
```

## Configuration precedence

The deployment script resolves settings in this order:

1. Command-line arguments
2. Environment variables such as `DEPLOY_DOMAIN` and `DEPLOY_SUBDOMAIN`
3. `.deployrc`
4. Built-in defaults

## Environment variables

Useful environment variables include:

```bash
export DEPLOY_DOMAIN="example.com"
export DEPLOY_SUBDOMAIN="www"
export DEPLOY_REGION="us-east-1"
export DEPLOY_AWS_PROFILE="default"
export DEPLOY_DRY_RUN="1"
export LOG_LEVEL="DEBUG"
```

## Operational notes

- `update` uses the current deployment state from `.deploy/state.json` and creates a new version manifest after a successful publish.
- `rollback` restores a prior version from the manifest history.
- `validate` performs pre-flight checks without making changes to AWS resources.

## CloudFormation templates

The repository currently uses two active templates under [cloud](cloud):

- [cloud/s3-static-website-deploy.yaml](cloud/s3-static-website-deploy.yaml) — this is the template used when you run the actual deployment flow: `./deploy.sh deploy` and `./deploy.sh update`. It is the simpler, production-oriented choice for this project and provisions the S3 bucket, CloudFront distribution, OAC, Route 53 record, and HTTPS wiring.
- [cloud/s3-static-website-validate.yaml](cloud/s3-static-website-validate.yaml) — this is the template checked by `./deploy.sh validate`. It is broader and more configurable, and is used as a validation/reference template rather than the default deployment path.

In other words, the deploy/update path uses the simple template, while validation uses the broader template. There is no separate flag to choose a different template at runtime.

The older cloud/minimal.yaml file has been removed because it was not referenced by the deployment or validation scripts.

For the short command summary, see [quickref.md](quickref.md).

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
