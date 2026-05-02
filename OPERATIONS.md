# OPERATIONS.md - Deployment Operations Guide

**Last Updated**: 2026-05-02  
**Feature**: AWS Static Website with Unified CloudFormation Deployment

---

## Operations Overview

This guide covers operational tasks for managing static website deployments on AWS using the unified CloudFormation deployment system.

---

## 1. Deployment Operations

### Initial Deployment

```bash
# 1. Configure deployment parameters
export AWS_PROFILE=production
export AWS_REGION=us-east-1

# 2. Dry-run validation (no AWS changes)
./deploy.sh deploy \
  --domain example.com \
  --subdomain www \
  --region us-east-1 \
  --source-dir ./website \
  --dry-run

# 3. Perform actual deployment
./deploy.sh deploy \
  --domain example.com \
  --subdomain www \
  --region us-east-1 \
  --source-dir ./website

# Expected duration: 6-10 minutes
# - CloudFormation stack creation: 3-5 minutes
# - File upload: 1-2 minutes
# - CloudFront cache: 1-2 minutes
```

### Content Update

```bash
# 1. Modify local files
nano website/index.html
nano website/css/main.css

# 2. Dry-run update
./deploy.sh update --dry-run

# 3. Execute update
./deploy.sh update

# Expected duration: 2-5 minutes
# - File change detection: <1 second
# - File upload: 1-2 minutes
# - CloudFront invalidation: 1-2 minutes

# Note: Changes typically live within 1-2 minutes
```

### Multi-Subdomain Deployment

```bash
# Deploy to multiple subdomains (www, blog, docs)
./deploy.sh deploy \
  --domain example.com \
  --subdomains www,blog,docs \
  --source-dir ./website \
  --region us-east-1

# Update specific subdomain
./deploy.sh update --subdomain blog

# Update all subdomains
./deploy.sh update
```

---

## 2. Version Management

### List Available Versions

```bash
# Show recent 20 versions
./deploy.sh versions list

# Show recent 50 versions
./deploy.sh versions list --limit 50

# Output as JSON for scripting
./deploy.sh versions list --json | jq '.[] | {version_id, timestamp}'
```

### View Version Details

```bash
# Show all files in a specific version
./deploy.sh versions show 20260501-143022

# Output as JSON
./deploy.sh versions show 20260501-143022 --json
```

### Rollback to Previous Version

```bash
# Rollback to immediately previous version
./deploy.sh rollback

# Rollback to specific version
./deploy.sh rollback --version 20260501-143022

# Rollback without confirmation (for automation)
./deploy.sh rollback --version 20260501-143022 --confirm
```

---

## 3. Monitoring & Validation

### Validate Deployment Configuration

```bash
# Run comprehensive validation without making changes
./deploy.sh validate --domain example.com

# Validate with specific configuration
./deploy.sh validate \
  --domain example.com \
  --subdomain www \
  --region us-east-1 \
  --source-dir ./website

# Output JSON for monitoring systems
./deploy.sh validate --domain example.com --json
```

### Check CloudFormation Stack Status

```bash
# View current stack status
aws cloudformation describe-stacks \
  --stack-name website-www-example-com-stack \
  --query 'Stacks[0].StackStatus'

# List recent stack events
aws cloudformation describe-stack-events \
  --stack-name website-www-example-com-stack \
  --max-results 20

# Get stack outputs (S3 bucket, CloudFront domain, etc.)
aws cloudformation describe-stacks \
  --stack-name website-www-example-com-stack \
  --query 'Stacks[0].Outputs'
```

### Monitor CloudFront Invalidations

```bash
# List active invalidations
aws cloudfront list-invalidations \
  --distribution-id D123ABC456

# Check specific invalidation status
aws cloudfront get-invalidation \
  --distribution-id D123ABC456 \
  --id I1ABC2D3E4F5
```

### Check DNS Resolution

```bash
# Verify domain resolves to CloudFront
nslookup www.example.com

# Verify specific Route53 record
aws route53 list-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --query 'ResourceRecordSets[?Name==`www.example.com.`]'

# Check HTTPS certificate
openssl s_client -connect www.example.com:443
```

---

## 4. Troubleshooting

### Deployment Failures

#### Error: "CloudFormation stack creation timeout"

**Symptoms**: Deployment hangs for >15 minutes

**Resolution**:
```bash
# 1. Check CloudFormation stack status
aws cloudformation describe-stacks \
  --stack-name website-www-example-com-stack \
  --query 'Stacks[0].StackStatus'

# 2. Review stack events for errors
aws cloudformation describe-stack-events \
  --stack-name website-www-example-com-stack

# 3. If stack creation failed, delete stack and retry
aws cloudformation delete-stack \
  --stack-name website-www-example-com-stack

# 4. Wait for deletion completion
aws cloudformation wait stack-delete-complete \
  --stack-name website-www-example-com-stack

# 5. Retry deployment
./deploy.sh deploy --domain example.com --subdomain www
```

#### Error: "Permission denied" on S3 upload

**Symptoms**: Files fail to upload, "Access Denied" errors

**Resolution**:
```bash
# 1. Verify IAM permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/my-role \
  --action-names s3:PutObject \
  --resource-arns "arn:aws:s3:::website-*-static/*"

# 2. Check S3 bucket policy
aws s3api get-bucket-policy --bucket website-www-example-com-static

# 3. Verify bucket exists
aws s3 ls | grep website-www-example-com-static

# 4. Check for account/region mismatches
aws s3 ls --profile my-profile
```

#### Error: "Invalid domain format"

**Symptoms**: Domain validation fails

**Resolution**:
```bash
# Valid domain formats:
./deploy.sh deploy --domain example.com           # ✓ OK
./deploy.sh deploy --domain www.example.com       # ✓ OK
./deploy.sh deploy --domain sub.domain.example.com # ✓ OK

# Invalid formats:
./deploy.sh deploy --domain example              # ✗ Not FQDN
./deploy.sh deploy --domain .com                 # ✗ No domain
./deploy.sh deploy --domain example.com.         # ✗ Trailing dot
./deploy.sh deploy --domain "example.com"        # ✓ OK (quotes OK)
```

#### Error: "No Route53 hosted zone found"

**Symptoms**: "Hosted zone not found for domain"

**Resolution**:
```bash
# 1. List all hosted zones
aws route53 list-hosted-zones

# 2. Verify hosted zone exists for domain
aws route53 list-hosted-zones-by-name \
  --query 'HostedZones[?Name==`example.com.`]'

# 3. Create hosted zone if missing
aws route53 create-hosted-zone \
  --name example.com \
  --caller-reference $(date +%s)

# 4. Update domain registrar DNS servers to point to Route53
# Get Route53 nameservers from hosted zone details
aws route53 get-hosted-zone --id Z1234567890ABC
```

#### Error: "ACM certificate validation timeout"

**Symptoms**: CloudFormation stuck waiting for certificate validation

**Resolution**:
```bash
# 1. Check certificate status
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/12345678

# 2. Verify Route53 DNS validation record was created
aws route53 list-resource-record-sets \
  --hosted-zone-id Z1234567890ABC | \
  jq '.ResourceRecordSets[] | select(.Type=="CNAME")'

# 3. If validation record is missing, create it manually
# Get pending validation from certificate details

# 4. Wait for validation to complete (5-15 minutes typically)
aws acm wait certificate-validated \
  --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/12345678
```

### Update Failures

#### Error: "File change detection failed"

**Symptoms**: Update command cannot detect which files changed

**Resolution**:
```bash
# 1. Check local version manifest
cat .deploy/state.json | jq '.current_version'

# 2. Verify version file exists
ls -la .deploy/versions/

# 3. Force full re-upload (treat all as changed)
rm .deploy/versions/*
./deploy.sh update

# 4. Or specify source directory explicitly
./deploy.sh update --source-dir ./website
```

#### Error: "CloudFront invalidation timeout"

**Symptoms**: "Invalidation still in progress after 5 minutes"

**Resolution**:
```bash
# This is usually just a warning - invalidation continues in background
# Check invalidation status manually
aws cloudfront list-invalidations \
  --distribution-id D123ABC456 \
  --query 'InvalidationList.Items[0]'

# In most cases, invalidation completes within 1-2 minutes
# Content is live even though warning was displayed
```

### Rollback Issues

#### Error: "Version not found"

**Symptoms**: "Version file not found: 20260501-143022"

**Resolution**:
```bash
# 1. List available versions
./deploy.sh versions list

# 2. Use correct version ID
./deploy.sh rollback --version 20260501-143022

# 3. If version is missing, check S3
aws s3 ls s3://website-www-example-com-static/versions/

# 4. If version missing in S3, restore from local backup
ls -la .deploy/versions/
```

### Performance Issues

#### Slow file uploads

**Symptoms**: Upload taking >10 minutes for small files

**Analysis**:
```bash
# 1. Check network connectivity
ping -c 3 s3.amazonaws.com

# 2. Check AWS API rate limits
# Default S3 rate: 3,500 PUT/COPY/POST/DELETE requests per second per partition

# 3. Monitor CloudFront distribution health
aws cloudfront get-distribution --id D123ABC456 \
  --query 'Distribution.DistributionConfig'

# 4. Check for large files slowing upload
du -sh website/* | sort -h
```

**Resolution**:
```bash
# Increase concurrent upload batches (advanced)
# Edit lib/s3.sh and change parallel batch size from 5 to 10
# Note: May cause throttling if hitting rate limits

# Or optimize file size
gzip website/css/main.css
minify website/js/main.js
```

#### Slow content propagation

**Symptoms**: Updated files not live within 5 minutes

**Analysis**:
```bash
# 1. Check if file was actually uploaded
aws s3 ls s3://website-www-example-com-static/index.html

# 2. Verify file timestamp is recent
aws s3api head-object \
  --bucket website-www-example-com-static \
  --key index.html | jq '.LastModified'

# 3. Check CloudFront cache behavior
aws cloudfront get-distribution \
  --id D123ABC456 | jq '.Distribution.DistributionConfig.DefaultCacheBehavior'

# 4. Force cache clear
./deploy.sh update --force-invalidate
```

---

## 5. Cost Monitoring

### Current Costs

```bash
# S3 Storage
# - Typical: <$0.10/month for <1GB
# - 50GB: ~$1.16/month
# - 1TB: ~$23/month

# CloudFront Data Transfer
# - Typical: <$0.10/month for low traffic
# - 100GB/month: ~$8.50
# - 1TB/month: ~$85

# Route53 Hosted Zone
# - $0.50/month per zone
# - Queries: $0.40 per million queries

# ACM Certificate
# - Free when used with CloudFront
# - Auto-renewal included
```

### Optimize Costs

```bash
# 1. Reduce file sizes
gzip index.html
minify javascript
optimize images

# 2. Cache static assets longer (in CloudFormation template)
# Set Cache-Control: max-age=31536000 for images

# 3. Monitor unused versions
./deploy.sh versions list

# 4. Delete old versions if needed
aws s3 rm s3://website-www-example-com-static/versions/old-version.json
```

### Set up Billing Alerts

```bash
# In AWS CloudWatch, create alarm for monthly AWS bill
aws cloudwatch put-metric-alarm \
  --alarm-name deployment-billing-alert \
  --alarm-description "Alert if monthly bill exceeds $50" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --threshold 50 \
  --comparison-operator GreaterThanThreshold
```

---

## 6. Logs & Debugging

### Enable Verbose Logging

```bash
# Deploy with verbose output
./deploy.sh deploy --domain example.com --verbose

# Update with debug output
DEBUG=1 ./deploy.sh update
```

### Access Deployment Logs

```bash
# Local deployment logs
cat .deploy/deployments/2026-05-02.log

# Recent deployment summary
tail -50 .deploy/deployments/2026-05-02.log | jq '.'
```

### CloudFront Logs

```bash
# Download CloudFront access logs
aws s3 sync s3://website-logs/cloudfront/ ./cf-logs/

# Analyze CloudFront logs
zcat ./cf-logs/*.gz | head -20

# Common queries
# - Cache hit ratio: grep "Hit" | wc -l
# - Cache miss ratio: grep "Miss" | wc -l
# - 4xx errors: grep " 4[0-9][0-9] " | wc -l
# - 5xx errors: grep " 5[0-9][0-9] " | wc -l
```

### CloudTrail Audit Logs

```bash
# Query CloudTrail for deployment operations
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=website-www-example-com-stack

# Find all S3 object uploads
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=PutObject

# Find all CloudFormation changes
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=UpdateStack
```

---

## 7. Maintenance Tasks

### Weekly

- [ ] Review version history: `./deploy.sh versions list`
- [ ] Check CloudFront cache statistics
- [ ] Monitor CloudWatch alarms

### Monthly

- [ ] Review CloudTrail logs for unauthorized access
- [ ] Verify ACM certificate will auto-renew
- [ ] Optimize large files/images
- [ ] Review CloudFront costs

### Quarterly

- [ ] Security audit (credentials, permissions)
- [ ] Backup version history locally
- [ ] Update deployment script to latest version
- [ ] Test rollback to oldest available version

### Annually

- [ ] Complete security audit
- [ ] Capacity planning review
- [ ] Disaster recovery test
- [ ] Cost optimization review

---

## 8. Emergency Recovery

### Complete Data Loss Scenario

```bash
# 1. Assess situation
./deploy.sh versions list

# 2. If recent version available, restore it
./deploy.sh rollback --version 20260501-143022

# 3. If all versions lost, redeploy from source control
git checkout website/
./deploy.sh deploy --domain example.com --subdomain www
```

### Compromised Domain/Stack

```bash
# 1. Take immediate action
aws cloudformation delete-stack \
  --stack-name website-www-example-com-stack

# 2. Investigate compromised content
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=website-www-example-com-stack

# 3. Clean source files
rm -rf website/
git checkout website/

# 4. Restore from backup
tar xzf website-backup-2026-05-01.tar.gz

# 5. Redeploy with clean configuration
./deploy.sh deploy --domain example.com --subdomain www
```

---

## 9. Automation & CI/CD

### GitHub Actions Integration

```yaml
name: Deploy Website

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-deployment-role
          aws-region: us-east-1
      
      - name: Validate deployment
        run: |
          ./deploy.sh validate --domain example.com
      
      - name: Deploy website
        run: |
          ./deploy.sh deploy \
            --domain example.com \
            --subdomain www \
            --source-dir ./website
```

---

## 10. References & Resources

- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [S3 Operations Guide](https://docs.aws.amazon.com/AmazonS3/latest/userguide/)
- [CloudFront Admin Guide](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/)
- [Route53 Admin Guide](https://docs.aws.amazon.com/route53/)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)

---

**Version**: 1.0.0  
**Last Updated**: 2026-05-02  
**Status**: Production Ready
