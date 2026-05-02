#!/bin/bash

# Unified deployment and update script for static portfolio website
# Usage: ./deploy.sh deploy [parameters] OR ./deploy.sh update

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

COMMAND=${1:-}
STACK_NAME=${2:-my-portfolio-site}
HOSTED_ZONE=${3:-}
DOMAIN_NAME=${4:-}
SUBDOMAIN=${5:-www}
REGION="us-east-1"

# Function to display usage
usage() {
    cat << EOF
${BLUE}Static Portfolio Website - Deployment Script${NC}

${YELLOW}Usage:${NC}
  ${BLUE}Deploy:${NC}
    ./deploy.sh deploy <stack-name> <hosted-zone> <domain-name> <subdomain>
    
    Example:
    ./deploy.sh deploy my-portfolio-site example.com. example.com www
    
  ${BLUE}Update:${NC}
    ./deploy.sh update <stack-name>
    
    Example:
    ./deploy.sh update my-portfolio-site

${YELLOW}Parameters:${NC}
  stack-name    CloudFormation stack name (default: my-portfolio-site)
  hosted-zone   Route 53 hosted zone WITH trailing dot (e.g., example.com.)
  domain-name   Domain name WITHOUT trailing dot (e.g., example.com)
  subdomain     Subdomain to provision (default: www)

${YELLOW}Important:${NC}
  - Deploy must be in us-east-1 region (ACM certificate requirement for CloudFront)
  - Hosted zone must already exist in Route 53
  - For updates, only stack-name is required
EOF
    exit 1
}

# Function to deploy infrastructure with CloudFormation
deploy() {
    if [ -z "$HOSTED_ZONE" ] || [ -z "$DOMAIN_NAME" ]; then
        echo -e "${RED}❌ Error: Missing parameters for deploy${NC}"
        usage
    fi

    echo -e "${BLUE}🚀 Deploying infrastructure with CloudFormation...${NC}"
    echo -e "${BLUE}Stack: ${STACK_NAME}${NC}"
    echo -e "${BLUE}Domain: ${SUBDOMAIN}.${DOMAIN_NAME}${NC}"
    echo -e "${BLUE}Region: ${REGION}${NC}"
    echo ""

    aws cloudformation deploy \
        --template-file CloudFormation/s3-static-website.yaml \
        --stack-name "${STACK_NAME}" \
        --parameter-overrides \
            HostedZoneName="${HOSTED_ZONE}" \
            DomainName="${DOMAIN_NAME}" \
            Subdomain="${SUBDOMAIN}" \
        --region "${REGION}" \
        --capabilities CAPABILITY_IAM

    echo ""
    echo -e "${GREEN}✅ CloudFormation stack deployed successfully!${NC}"
    echo ""

    # Retrieve stack outputs
    echo -e "${BLUE}📋 Stack Outputs:${NC}"
    aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME}" \
        --region "${REGION}" \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table

    echo ""
    echo -e "${YELLOW}📤 Uploading website files to S3...${NC}"
    
    # Get S3 bucket name from CloudFormation outputs
    BUCKET_NAME=$(aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME}" \
        --region "${REGION}" \
        --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
        --output text)

    if [ -z "$BUCKET_NAME" ]; then
        echo -e "${RED}❌ Could not retrieve S3 bucket name from CloudFormation${NC}"
        exit 1
    fi

    # Sync files to S3
    aws s3 sync . "s3://${BUCKET_NAME}/" \
        --exclude "CloudFormation/*" \
        --exclude "*.sh" \
        --exclude ".git/*" \
        --exclude ".github/*" \
        --exclude ".specify/*" \
        --exclude ".vscode/*" \
        --exclude ".cel/*" \
        --exclude ".gitignore" \
        --exclude "Readme.md" \
        --exclude ".DS_Store" \
        --delete

    echo ""
    echo -e "${BLUE}🔄 Invalidating CloudFront cache...${NC}"
    
    # Get CloudFront distribution ID from CloudFormation outputs
    DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME}" \
        --region "${REGION}" \
        --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
        --output text)

    if [ -z "$DISTRIBUTION_ID" ]; then
        echo -e "${RED}⚠️  Could not retrieve CloudFront distribution ID${NC}"
    else
        aws cloudfront create-invalidation \
            --distribution-id "${DISTRIBUTION_ID}" \
            --paths "/*" \
            --region "${REGION}" \
            --output table
    fi

    echo ""
    echo -e "${GREEN}✅ Infrastructure deployment complete!${NC}"
    echo -e "${YELLOW}Note: DNS and CDN changes may take 1-5 minutes to propagate globally.${NC}"
}

# Function to update existing website
update() {
    echo -e "${BLUE}📦 Updating website files...${NC}"
    echo -e "${BLUE}Stack: ${STACK_NAME}${NC}"
    echo ""

    # Verify CloudFormation stack exists
    if ! aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME}" \
        --region "${REGION}" \
        --output text &>/dev/null; then
        echo -e "${RED}❌ CloudFormation stack '${STACK_NAME}' not found${NC}"
        echo -e "${YELLOW}Did you deploy with ./deploy.sh deploy first?${NC}"
        exit 1
    fi

    # Get S3 bucket name from CloudFormation outputs
    BUCKET_NAME=$(aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME}" \
        --region "${REGION}" \
        --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
        --output text)

    if [ -z "$BUCKET_NAME" ]; then
        echo -e "${RED}❌ Could not retrieve S3 bucket name from CloudFormation${NC}"
        exit 1
    fi

    echo -e "${BLUE}Bucket: ${BUCKET_NAME}${NC}"
    echo ""

    # Sync files to S3
    echo -e "${YELLOW}📤 Uploading files to S3...${NC}"
    aws s3 sync . "s3://${BUCKET_NAME}/" \
        --exclude "CloudFormation/*" \
        --exclude "*.sh" \
        --exclude ".git/*" \
        --exclude ".github/*" \
        --exclude ".specify/*" \
        --exclude ".vscode/*" \
        --exclude ".cel/*" \
        --exclude ".gitignore" \
        --exclude "Readme.md" \
        --exclude ".DS_Store" \
        --delete

    echo ""
    echo -e "${BLUE}🔄 Invalidating CloudFront cache...${NC}"

    # Get CloudFront distribution ID from CloudFormation outputs
    DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME}" \
        --region "${REGION}" \
        --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
        --output text)

    WEBSITE_URL=$(aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME}" \
        --region "${REGION}" \
        --query 'Stacks[0].Outputs[?OutputKey==`WebsiteUrl`].OutputValue' \
        --output text)

    if [ -z "$DISTRIBUTION_ID" ]; then
        echo -e "${RED}⚠️  Could not retrieve CloudFront distribution ID${NC}"
    else
        aws cloudfront create-invalidation \
            --distribution-id "${DISTRIBUTION_ID}" \
            --paths "/*" \
            --region "${REGION}" \
            --output table
    fi

    echo ""
    echo -e "${GREEN}✅ Website updated successfully!${NC}"
    if [ -n "$WEBSITE_URL" ]; then
        echo -e "${GREEN}URL: ${WEBSITE_URL}${NC}"
    fi
    echo -e "${YELLOW}Note: Changes may take 1-5 minutes to propagate globally.${NC}"
}

# Main logic
case "$COMMAND" in
    deploy)
        deploy
        ;;
    update)
        update
        ;;
    *)
        echo -e "${RED}❌ Invalid command: $COMMAND${NC}"
        usage
        ;;
esac
