# Deployment Operations Guide

**Last Updated**: 2026-05-02  
**Feature**: AWS Static Website with Unified CloudFormation Deployment

See [performance.md](performance.md) for detailed timing breakdowns and optimization strategies.

---

## Deployment Operations

### Initial Deployment

```bash
./deploy.sh deploy \
  --domain example.com \
  --subdomain www \
  --region us-east-1 \
  --source-dir ./website \
  --dry-run

# Execute: remove --dry-run flag
```

### Content Update

```bash
./deploy.sh update --dry-run
./deploy.sh update
```

### Multi-Subdomain Deployment

```bash
./deploy.sh deploy \
  --domain example.com \
  --subdomains www,blog,docs \
  --source-dir ./website \
  --region us-east-1
```

---

## Version Management

### List Versions

```bash
./deploy.sh versions list
./deploy.sh versions list --limit 50 --json
```

### Rollback

```bash
./deploy.sh rollback
./deploy.sh rollback --version 20260501-143022
./deploy.sh rollback --version 20260501-143022 --confirm
```

---

## Monitoring & Validation

### Validate Configuration

```bash
./deploy.sh validate --domain example.com
./deploy.sh validate --domain example.com --json
```

### CloudFormation Status

```bash
aws cloudformation describe-stacks \
  --stack-name website-www-example-com-stack \
  --query 'Stacks[0].StackStatus'

aws cloudformation describe-stack-events \
  --stack-name website-www-example-com-stack \
  --max-results 20
```

### CloudFront Invalidations

```bash
aws cloudfront list-invalidations --distribution-id D123ABC456
aws cloudfront get-invalidation --distribution-id D123ABC456 --id I1ABC2D3E4F5
```

---

## Troubleshooting

**CloudFormation timeout** → Check stack events, common causes: ACM cert validation, Route53 permissions, S3 bucket conflict. Retry with same command (idempotent).

**File upload fails** → Resume operation; checkpoint system auto-detects completed uploads. Check network: `curl -I https://s3.amazonaws.com`. Verify IAM permissions (see security.md).

**CloudFront cache not updating** → Verify invalidation: `aws cloudfront list-invalidations --distribution-id D123ABC456`. Usually completes within 1-2 minutes.

**Domain validation fails** → Valid: `example.com`, `www.example.com`. Invalid: `example` (no TLD), `.com` (no domain), `example.com.` (trailing dot).

**No Route53 zone found** → Create one: `aws route53 create-hosted-zone --name example.com --caller-reference $(date +%s)`. Update domain registrar DNS servers to Route53 nameservers.

**ACM certificate timeout** → Certificate validation in background (5-15 min typical). Check: `aws acm describe-certificate --certificate-arn arn:...`

---

## See Also

- [security.md](security.md) - Credentials, S3 access, HTTPS, IAM permissions
- [performance.md](performance.md) - Timing, optimization, scaling limits
