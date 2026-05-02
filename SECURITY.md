# SECURITY.md - AWS Static Website Deployment Security Guide

**Last Updated**: 2026-05-02  
**Feature**: AWS Static Website with Unified CloudFormation Deployment

---

## Security Overview

This deployment system prioritizes security by default with automatic protections for credential handling, S3 access control, and TLS/HTTPS enforcement. All infrastructure components follow AWS security best practices.

---

## 1. Credential Handling

### ✅ Best Practices Implemented

**Environment Variables** - No hardcoded credentials
```bash
export AWS_PROFILE=my-profile
./deploy.sh deploy --domain example.com
```

**AWS IAM Roles** - Recommended for production
- Deploy from EC2 instance with IAM role attached
- Deploy from GitHub Actions with OIDC provider
- Deploy from ECS task with execution role
- Deploy from Lambda with execution role

**AWS Credentials File** - Local development
```bash
# ~/.aws/credentials
[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# Use with: export AWS_PROFILE=default
```

### ⚠️ What NOT to Do

❌ Commit `.aws/credentials` file to Git  
❌ Hardcode AccessKey/SecretKey in scripts  
❌ Share credentials in Slack, email, or GitHub issues  
❌ Store credentials in `.deployrc` configuration file  
❌ Upload credential files to S3

### 🔐 Secrets Scanning

The deployment system automatically scans files for secret patterns before upload:

**Detected Patterns**:
- `*.pem`, `*.key` (private key files)
- `*.env`, `.env*` (environment files)
- Lines containing: `api_key`, `password`, `secret`, `token`, `credential`

**What Happens**:
1. Pre-upload scan runs automatically
2. If secrets detected → deployment STOPS
3. Error message: `"File 'config.env' contains secret patterns. Remove or add to .deployignore"`

**How to Fix**:
```bash
# Option 1: Remove sensitive files
rm .env config.key

# Option 2: Create .deployignore to exclude files
echo ".env*" >> .deployignore
echo "*.key" >> .deployignore
```

---

## 2. S3 Security Configuration

### ✅ Default Protections

All S3 buckets created by this deployment have:

- **Public Access Block**: ✅ ENABLED
  - BlockPublicAcls: true
  - BlockPublicPolicy: true
  - IgnorePublicAcls: true
  - RestrictPublicBuckets: true

- **Bucket Versioning**: ✅ ENABLED
  - All object versions retained for rollback capability
  - Can restore any previous deployment version

- **Encryption**: ✅ DEFAULT (AWS-managed)
  - Server-side encryption enabled
  - All objects encrypted at rest

- **Logging**: ✅ OPTIONAL (can be enabled)
  - S3 access logs can be written to separate audit bucket
  - CloudFront logs stored in S3

### 🔐 Access Control via CloudFront

**Architecture**:
```
S3 Bucket (Private)
    ↓
    ← OAI (Origin Access Identity) / OAC (Origin Access Control)
    ↓
CloudFront Distribution (Public)
    ↓
End Users (via HTTPS)
```

**How it Works**:
- S3 bucket is completely private
- Only CloudFront distribution can access S3 objects via OAC
- Users cannot access S3 directly
- All traffic forced through CloudFront HTTPS

### 🛡️ Recommended Additional Protections

**Enable Versioning Retention**:
```bash
# Add to CloudFormation template or apply manually
aws s3api put-bucket-versioning \
  --bucket <bucket-name> \
  --versioning-configuration Status=Enabled
```

**Enable MFA Delete** (requires root credentials):
```bash
aws s3api put-bucket-versioning \
  --bucket <bucket-name> \
  --versioning-configuration Status=Enabled,MFADelete=Enabled \
  --mfa "arn:aws:iam::123456789012:mfa/root" <mfa-serial-number>
```

---

## 3. CloudFront & HTTPS/TLS Security

### ✅ Default Protections

- **HTTPS/TLS Enforcement**: Redirect HTTP → HTTPS (all traffic encrypted)
- **TLS Version**: TLS 1.2+ required (no insecure protocols)
- **Certificate**: AWS Certificate Manager (ACM) auto-provisioned & auto-renewed
- **DNS Validation**: Automatic validation via Route53

### 🔐 Certificate Management

**Automatic Certificate Provisioning**:
```
1. CloudFormation creates ACM certificate for subdomain.domain.com
2. Route53 DNS validation record created automatically
3. Certificate validation completed automatically
4. Certificate auto-renews 30 days before expiration
5. No manual renewal required
```

**Custom Domain Requirements**:
- Domain must have Route53 hosted zone (public or private)
- DNS must be accessible for ACM validation
- Certificate provisioning takes 5-15 minutes

### 🛡️ Additional Security Headers (Recommended)

Add to CloudFormation template for enhanced security:

```yaml
SecurityHeadersFunction:
  Type: AWS::CloudFront::Function
  Properties:
    Name: security-headers
    Runtime: cloudfront-js-1.0
    Code:
      InlineCode: |
        function handler(event) {
          var response = event.response;
          response.headers['strict-transport-security'] = {
            value: 'max-age=31536000; includeSubdomains'
          };
          response.headers['x-content-type-options'] = {
            value: 'nosniff'
          };
          response.headers['x-frame-options'] = {
            value: 'DENY'
          };
          response.headers['x-xss-protection'] = {
            value: '1; mode=block'
          };
          return response;
        }
    AutoPublish: true
```

---

## 4. IAM Permission Model - Least Privilege

### ✅ Minimum Required Permissions

**Policy Template** for deployment role:

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
      "Action": [
        "iam:PassRole"
      ],
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

### 🔍 How to Verify Permissions

```bash
# Test deployment with dry-run to validate permissions
./deploy.sh deploy --domain example.com --dry-run

# Simulate IAM policy
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/deploy-role \
  --action-names s3:PutObject cloudformation:CreateStack cloudfront:CreateInvalidation \
  --profile my-profile
```

---

## 5. Audit Logging & CloudTrail

### ✅ Recommended Configuration

**Enable CloudTrail for Deployment Auditing**:

```bash
# Create CloudTrail trail for deployment operations
aws cloudtrail create-trail \
  --name deployment-trail \
  --s3-bucket-name audit-logs \
  --include-global-service-events

# Enable logging
aws cloudtrail start-logging --trail-name deployment-trail
```

**CloudTrail Captures**:
- All CloudFormation stack operations (who, when, what changed)
- S3 object uploads/deletions (audit trail)
- Route53 DNS changes
- ACM certificate requests
- CloudFront invalidations

### 📊 View Audit Logs

```bash
# Get recent CloudFormation events
aws cloudformation describe-stack-events \
  --stack-name website-www-example-com-stack

# Get S3 access logs
aws s3 cp s3://audit-logs/ ./logs/ --recursive

# View CloudTrail events
aws cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceName,AttributeValue=example.com
```

---

## 6. Network Security

### ✅ Default Protections

- **HTTPS/TLS Only**: All traffic encrypted in transit
- **No Direct S3 Access**: Only via CloudFront
- **CloudFront Edge Locations**: DDoS protection at edge
- **Query String Filtering**: Optional CORS configuration

### 🔐 DDoS Protection

CloudFront provides free DDoS protection at the edge:
- Automatic attack mitigation
- Rate limiting
- IP reputation filtering

For additional protection:
```bash
# Enable AWS Shield Standard (free)
# Included with CloudFront

# Optional: AWS Shield Advanced ($3,000/month)
# - Dedicated support
# - Cost protection guarantee
# - Advanced threat analytics
```

---

## 7. Secrets in Configuration

### ✅ Safe Configuration Pattern

**✓ Safe in .deployrc**:
```yaml
domain: example.com
region: us-east-1
source_dir: ./website
```

**✗ Never in .deployrc**:
```yaml
aws_access_key_id: AKIAIOSFODNN7EXAMPLE  # ✗ WRONG
aws_secret_access_key: wJalrXUtnFEMI...  # ✗ WRONG
password: mySecretPassword               # ✗ WRONG
api_token: sk-1234567890abcdef          # ✗ WRONG
```

**✓ Correct Credential Handling**:
```bash
# Use IAM role (recommended in production)
./deploy.sh deploy --domain example.com

# Use AWS profile (for local development)
export AWS_PROFILE=dev-profile
./deploy.sh deploy --domain example.com

# Use environment variables (for CI/CD)
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
./deploy.sh deploy --domain example.com
```

---

## 8. Deployment Security Checklist

Before production deployment:

- [ ] **Credentials**: Using IAM role or AWS profile (not hardcoded keys)
- [ ] **S3 Bucket**: Versioning enabled, public access blocked
- [ ] **CloudFront**: HTTPS required, TLS 1.2+
- [ ] **Certificate**: ACM certificate validated and auto-renewal enabled
- [ ] **IAM Role**: Has only minimum required permissions
- [ ] **Secrets Scanning**: Deployment aborts if secrets detected
- [ ] **CloudTrail**: Enabled for audit logging
- [ ] **Domain DNS**: Route53 hosted zone configured
- [ ] **Dry-Run Test**: Pass `./deploy.sh deploy --dry-run` without errors
- [ ] **Health Checks**: Post-deployment health checks pass

---

## 9. Incident Response

### 🚨 Compromised Credentials

If AWS credentials are compromised:

```bash
# 1. Immediately deactivate compromised key
aws iam update-access-key --access-key-id AKIA... --status Inactive

# 2. Create new credentials
aws iam create-access-key --user-name my-user

# 3. Update deployment environment with new credentials

# 4. Review CloudTrail for unauthorized activity
aws cloudtrail lookup-events --lookup-attributes AttributeKey=Username,AttributeValue=my-user

# 5. Rotate all relevant credentials
```

### 🔄 Unauthorized Changes

If unauthorized changes detected:

```bash
# 1. Perform rollback to known-good version
./deploy.sh rollback --version 20260501-143022 --confirm

# 2. Review CloudFormation events
aws cloudformation describe-stack-events --stack-name website-www-example-com-stack

# 3. Review CloudTrail for unauthorized access
aws cloudtrail lookup-events

# 4. Audit CloudFront logs
aws s3 cp s3://<bucket>/cloudfront-logs/ ./logs/ --recursive
```

### 🔍 Audit Compromised Data

```bash
# List all S3 objects in bucket
aws s3 ls s3://<bucket>/ --recursive

# Get object metadata (upload time, user)
aws s3api head-object --bucket <bucket> --key <object-key>

# Check versioning history
aws s3api list-object-versions --bucket <bucket>
```

---

## 10. Compliance & Standards

### 📋 Aligned With

- **AWS Well-Architected Framework** - Security pillar
- **OWASP Cloud Security** - Top 10 risks
- **CIS AWS Foundations Benchmark** - Level 1 controls
- **PCI DSS** - For payment information (if applicable)

### 🔒 Security Features By Standard

| Standard | Feature | Status |
|----------|---------|--------|
| OWASP | Encryption in Transit | ✅ TLS 1.2+ |
| OWASP | Encryption at Rest | ✅ AWS-managed |
| OWASP | Authentication | ✅ IAM roles |
| OWASP | Access Control | ✅ Least privilege |
| OWASP | Audit Logging | ✅ CloudTrail |
| CIS | Public Access | ✅ Blocked |
| CIS | Versioning | ✅ Enabled |
| CIS | Logging | ✅ Supported |

---

## 11. Reporting Security Issues

If you discover a security vulnerability:

1. **Do NOT** create a public GitHub issue
2. Email security details to: security@example.com
3. Include:
   - Description of vulnerability
   - Steps to reproduce
   - Impact assessment
   - Suggested fix (if applicable)

---

## 12. Security References

- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
- [S3 Security Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [CloudFront Security](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/security.html)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

---

**Version**: 1.0.0  
**Last Updated**: 2026-05-02  
**Status**: Production Ready
