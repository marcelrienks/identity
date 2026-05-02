# AWS Static Website Deployment Security Guide

**Last Updated**: 2026-05-02

---

## Credential Handling

### ✅ Best Practices

**AWS IAM Roles** - Recommended for production
- EC2 instance with attached IAM role
- GitHub Actions with OIDC provider
- ECS task with execution role
- Lambda with execution role

**Environment Variables** - Local development
```bash
export AWS_PROFILE=my-profile
./deploy.sh deploy --domain example.com
```

**AWS Credentials File** - `~/.aws/credentials`
```bash
[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/...
```

### ⚠️ Never Do

❌ Commit `.aws/credentials` to Git  
❌ Hardcode AccessKey/SecretKey in scripts  
❌ Share credentials in Slack/email/GitHub  
❌ Store credentials in `.deployrc`  
❌ Upload credential files to S3

### 🔐 Secrets Scanning

Deployment auto-scans files before upload. Detects: `*.pem`, `*.key`, `*.env`, lines with `api_key`, `password`, `secret`, `token`, `credential`.

If detected: Deployment STOPS. Fix: Remove file or add to `.deployignore`.

---

## S3 Security Configuration

### ✅ Default Protections (Auto-enabled)

| Setting | Value | Purpose |
|---------|-------|---------|
| Public Access Block | ENABLED | Prevents accidental public exposure |
| Versioning | ENABLED | Enables rollback to any version |
| Encryption | AWS-managed | Objects encrypted at rest |
| Logging | Optional | S3 access logs to audit bucket |

### 🔐 Access Control: CloudFront OAC

```
S3 Bucket (Private)
  ↓ (OAC)
CloudFront Distribution (Public)
  ↓ (HTTPS)
End Users
```

- S3 bucket completely private
- Only CloudFront can access via Origin Access Control
- Users cannot bypass CloudFront
- All traffic forced to HTTPS

---

## HTTPS/TLS Security

### ✅ Default Protections

- **HTTP → HTTPS**: Automatic redirect, all traffic encrypted
- **TLS 1.2+**: Enforced, no insecure protocols
- **ACM Certificate**: Auto-provisioned in CloudFormation
- **Auto-renewal**: 30 days before expiration
- **DNS Validation**: Automatic via Route53

**Certificate Requirements**:
- Domain must have Route53 hosted zone
- DNS accessible for ACM validation
- Provisioning: 5-15 minutes typical

---

## IAM Permissions - Least Privilege

### ✅ Minimum Required Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3StaticSite",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetBucketVersioning", "s3:PutBucketVersioning", "s3:GetObjectVersion"],
      "Resource": ["arn:aws:s3:::website-*-static", "arn:aws:s3:::website-*-static/*"]
    },
    {
      "Sid": "CloudFormationStack",
      "Effect": "Allow",
      "Action": ["cloudformation:CreateStack", "cloudformation:UpdateStack", "cloudformation:DeleteStack", "cloudformation:DescribeStacks", "cloudformation:ListStackEvents", "cloudformation:GetTemplate"],
      "Resource": "arn:aws:cloudformation:*:*:stack/website-*/*"
    },
    {
      "Sid": "CloudFrontCDN",
      "Effect": "Allow",
      "Action": ["cloudfront:CreateInvalidation", "cloudfront:GetDistribution", "cloudfront:ListDistributions"],
      "Resource": "*"
    },
    {
      "Sid": "Route53DNS",
      "Effect": "Allow",
      "Action": ["route53:ChangeResourceRecordSets", "route53:GetHostedZone", "route53:ListHostedZones", "route53:ListResourceRecordSets"],
      "Resource": "arn:aws:route53:::hostedzone/*"
    },
    {
      "Sid": "ACMCertificate",
      "Effect": "Allow",
      "Action": ["acm:RequestCertificate", "acm:DescribeCertificate", "acm:ListCertificates"],
      "Resource": "arn:aws:acm:*:*:certificate/*"
    },
    {
      "Sid": "IAMPassRole",
      "Effect": "Allow",
      "Action": ["iam:PassRole"],
      "Resource": "arn:aws:iam::*:role/*",
      "Condition": {"StringEquals": {"iam:PassedToService": "cloudformation.amazonaws.com"}}
    }
  ]
}
```

### Verify Permissions

```bash
./deploy.sh deploy --domain example.com --dry-run

aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/deploy-role \
  --action-names s3:PutObject cloudformation:CreateStack cloudfront:CreateInvalidation
```

---

## Audit Logging & CloudTrail

### ✅ Enable CloudTrail

```bash
aws cloudtrail create-trail \
  --name deployment-trail \
  --s3-bucket-name audit-logs \
  --include-global-service-events

aws cloudtrail start-logging --trail-name deployment-trail
```

**Captures**: CloudFormation operations, S3 uploads/deletions, Route53 changes, ACM requests, CloudFront invalidations.

### View Logs

```bash
aws cloudformation describe-stack-events \
  --stack-name website-www-example-com-stack

aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=example.com
```

---

## Network Security

### ✅ Default Protections

- **HTTPS/TLS Only**: All traffic encrypted
- **No Direct S3**: Only via CloudFront
- **DDoS Protection**: Free at CloudFront edge (AWS Shield Standard)

### Optional: AWS Shield Advanced

$3,000/month for dedicated support + cost protection guarantee.

---

## Safe Configuration Pattern

### ✓ Safe in .deployrc

```yaml
domain: example.com
region: us-east-1
source_dir: ./website
```

### ✗ Never in .deployrc

```yaml
aws_access_key_id: AKIA...        # ✗ WRONG
aws_secret_access_key: wJalr...   # ✗ WRONG
password: mySecret                # ✗ WRONG
api_token: sk-1234567890...       # ✗ WRONG
```

---

## Pre-Deployment Security Checklist

- [ ] Credentials: IAM role or AWS profile (not hardcoded)
- [ ] S3 Bucket: Versioning enabled, public access blocked
- [ ] CloudFront: HTTPS required, TLS 1.2+
- [ ] Certificate: ACM validated and auto-renewal enabled
- [ ] IAM Role: Only minimum required permissions
- [ ] Secrets Scanning: Deployment aborts if secrets detected
- [ ] CloudTrail: Enabled for audit logging
- [ ] DNS: Route53 hosted zone configured
- [ ] Dry-Run: Passes without errors
- [ ] Health Checks: Post-deployment verification passes

---

## Incident Response

### Compromised Credentials

```bash
# 1. Immediately deactivate compromised key
aws iam update-access-key --access-key-id AKIA... --status Inactive

# 2. Create new credentials
aws iam create-access-key --user-name my-user

# 3. Update deployment environment

# 4. Review CloudTrail for unauthorized activity
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=my-user

# 5. Rotate all relevant credentials
```

### Unauthorized Changes

```bash
# 1. Rollback to known-good version
./deploy.sh rollback --version 20260501-143022 --confirm

# 2. Review CloudFormation events
aws cloudformation describe-stack-events \
  --stack-name website-www-example-com-stack

# 3. Audit CloudTrail and CloudFront logs
aws cloudtrail lookup-events
aws s3 cp s3://<bucket>/cloudfront-logs/ ./logs/ --recursive
```

---

## Compliance

### 📋 Aligned With

- AWS Well-Architected Framework (Security pillar)
- OWASP Cloud Security (Top 10 risks)
- CIS AWS Foundations Benchmark (Level 1)
- PCI DSS (payment information, if applicable)

### 🔒 Feature Coverage

| Standard | Feature | Status |
|----------|---------|--------|
| OWASP | Encryption (transit) | ✅ TLS 1.2+ |
| OWASP | Encryption (rest) | ✅ AWS-managed |
| OWASP | Authentication | ✅ IAM roles |
| OWASP | Access Control | ✅ Least privilege |
| OWASP | Audit Logging | ✅ CloudTrail |
| CIS | Public Access | ✅ Blocked |
| CIS | Versioning | ✅ Enabled |
| CIS | Logging | ✅ Supported |

---

## See Also

- [operations.md](operations.md) - Deployment, monitoring, troubleshooting
- [performance.md](performance.md) - Timing breakdown, optimization, scaling
