# Project Context: Identity Portfolio Website

**Last Read:** 2 May 2026 (rescanned — docs updated)  
**Status:** Cache miss — new scan + hash update

---

## Project Purpose

Professional portfolio website for Marcel Rienks showcasing 20+ years IT Service Delivery Management + software engineering expertise. Static site → fast, secure, no server dependencies. AWS-deployable via CloudFormation + Terraform IaC.

---

## Architecture & Tech Stack

### Frontend
- **HTML5** — semantic markup
- **CSS3** — variables, animations, custom color scheme (#6DB1D8, #FFFFFF, #272727)
- **Bootstrap 5.3.3** — responsive framework
- **JavaScript** — interactive features
- **Libraries:** AOS (scroll animations), Typed.js (text typing), Isotope (portfolio filtering)

### Hosting
- **S3** — static file hosting
- **CloudFront** — global CDN, HTTPS/SSL
- **Route 53** — DNS + custom domain
- **ACM** — free SSL certificates
- **Terraform** — infrastructure as code (deploy scripts present)

### Deployment
- **CloudFormation** — AWS stack provisioning (template in `CloudFormation/s3-static-website.yaml`)
- **CLI Scripts** — `deploy-terraform.sh`, `update-website.sh` for automation

---

## Key Workflows

1. **Local Development** → Edit HTML/CSS/JS in `./assets/`
2. **Deploy Infrastructure** → Run CloudFormation template (must be in us-east-1 for ACM)
3. **Upload Content** → `aws s3 sync ./assets s3://bucket-name/assets` + main `index.html`
4. **Cache Invalidation** → CloudFront invalidation for immediate changes (uses distribution ID from CF stack outputs)

---

## Directory Structure

```
/ (root)
├── index.html                          # Main portfolio page
├── Readme.md                           # Project documentation
├── assets/
│   ├── css/main.css                   # Custom styles
│   ├── js/main.js                     # Interactive features
│   ├── img/portfolio/                 # Portfolio images
│   └── vendor/                        # Third-party libraries (AOS, Bootstrap, Isotope, Typed.js, Waypoints)
├── CloudFormation/
│   └── s3-static-website.yaml         # AWS CF template (S3, CloudFront, Route53, ACM)
├── deploy-terraform.sh                # Terraform deployment script
└── update-website.sh                  # Website update script
```

---

## Documentation Map

| Info | Location |
|------|----------|
| Project overview, features, tech stack | Readme.md (lines 1–100+) |
| AWS CloudFormation deployment | Readme.md (Quick Start Guide section) |
| S3 upload instructions | Readme.md (Uploading Website Files section) |
| Template attribution | Readme.md (bottom) |
| Infrastructure template | CloudFormation/s3-static-website.yaml |
| Deployment automation | deploy-terraform.sh, update-website.sh |

---

## Key Notes

- **Must deploy to us-east-1** — ACM certificates for CloudFront require this region
- **S3 bucket naming:** `{subdomain}-{domain}-static` (e.g., www-example.com-static)
- **Mobile-first responsive** — Bootstrap-based, no breakpoint hacks needed
- **Performance optimized** — CDN caching, minified assets, browser caching via CloudFront
- **SEO ready** — structured content, meta tags in place
- **Easy customization** — CSS variables for colors, modular structure

---

## Document Hashes (for change detection)

| File | MD5 |
|------|-----|
| Readme.md | 13569c9696047e54f2321c538cadc35e |

---

**Ready for queries on project structure, deployment, or customization.**
