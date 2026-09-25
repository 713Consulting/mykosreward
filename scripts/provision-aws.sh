#!/usr/bin/env bash
# One-time (and safe to re-run) AWS setup for www.mykosreward.com:
#   1. a private S3 bucket for the site files
#   2. a CloudFront distribution in front of it (HTTPS, compression, caching)
#   3. an HTTPS certificate for www.mykosreward.com (validated by a DNS record)
#   4. once the certificate is issued, www.mykosreward.com attached to CloudFront
# Every step checks what already exists first, so running it again only does
# what is still missing. Needs AWS credentials in the environment.
set -euo pipefail

DOMAIN="${DOMAIN:-www.mykosreward.com}"
TAG="mykosreward.com site"          # CloudFront comment used to find the distribution
OAC_NAME="mykosreward-oac"
export AWS_DEFAULT_REGION=us-east-1 # CloudFront certificates must live in us-east-1
CACHING_OPTIMIZED=658327ea-f89d-4fab-a63d-7e88639e58f6  # AWS managed cache policy

summary() { echo "$*"; [ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "$*" >> "$GITHUB_STEP_SUMMARY" || true; }

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
BUCKET="${S3_BUCKET:-mykosreward-site-$ACCOUNT}"
echo "AWS account $ACCOUNT, bucket $BUCKET"

# 1. Bucket (private; only CloudFront may read it)
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "Bucket exists"
else
  aws s3api create-bucket --bucket "$BUCKET" >/dev/null
  echo "Created bucket"
fi
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# 2a. Origin access control (lets CloudFront sign its requests to the private bucket)
OAC_ID=$(aws cloudfront list-origin-access-controls \
  --query "OriginAccessControlList.Items[?Name=='$OAC_NAME'].Id | [0]" --output text)
if [ "$OAC_ID" = "None" ] || [ -z "$OAC_ID" ]; then
  OAC_ID=$(aws cloudfront create-origin-access-control --origin-access-control-config \
    "Name=$OAC_NAME,SigningProtocol=sigv4,SigningBehavior=always,OriginAccessControlOriginType=s3" \
    --query OriginAccessControl.Id --output text)
  echo "Created origin access control $OAC_ID"
fi

# 2b. Distribution
DIST_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='$TAG'].Id | [0]" --output text)
if [ "$DIST_ID" = "None" ] || [ -z "$DIST_ID" ]; then
  cat > /tmp/dist.json <<JSON
{
  "CallerReference": "mykosreward-$(date +%s)",
  "Comment": "$TAG",
  "Enabled": true,
  "DefaultRootObject": "index.html",
  "PriceClass": "PriceClass_100",
  "HttpVersion": "http2and3",
  "IsIPV6Enabled": true,
  "Origins": { "Quantity": 1, "Items": [{
    "Id": "site-bucket",
    "DomainName": "$BUCKET.s3.us-east-1.amazonaws.com",
    "OriginAccessControlId": "$OAC_ID",
    "S3OriginConfig": { "OriginAccessIdentity": "" }
  }]},
  "DefaultCacheBehavior": {
    "TargetOriginId": "site-bucket",
    "ViewerProtocolPolicy": "redirect-to-https",
    "CachePolicyId": "$CACHING_OPTIMIZED",
    "Compress": true,
    "AllowedMethods": { "Quantity": 2, "Items": ["GET", "HEAD"],
      "CachedMethods": { "Quantity": 2, "Items": ["GET", "HEAD"] } }
  }
}
JSON
  DIST_ID=$(aws cloudfront create-distribution --distribution-config file:///tmp/dist.json \
    --query Distribution.Id --output text)
  echo "Created CloudFront distribution $DIST_ID"
fi
DIST_DOMAIN=$(aws cloudfront get-distribution --id "$DIST_ID" --query Distribution.DomainName --output text)

# 2c. Bucket policy: only this distribution may read the files
cat > /tmp/policy.json <<JSON
{ "Version": "2012-10-17", "Statement": [{
  "Sid": "CloudFrontRead", "Effect": "Allow",
  "Principal": { "Service": "cloudfront.amazonaws.com" },
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::$BUCKET/*",
  "Condition": { "StringEquals": { "AWS:SourceArn": "arn:aws:cloudfront::$ACCOUNT:distribution/$DIST_ID" } }
}]}
JSON
aws s3api put-bucket-policy --bucket "$BUCKET" --policy file:///tmp/policy.json

# 3. Certificate for the domain
CERT_ARN=$(aws acm list-certificates \
  --certificate-statuses PENDING_VALIDATION ISSUED \
  --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn | [0]" --output text)
if [ "$CERT_ARN" = "None" ] || [ -z "$CERT_ARN" ]; then
  CERT_ARN=$(aws acm request-certificate --domain-name "$DOMAIN" --validation-method DNS \
    --query CertificateArn --output text)
  echo "Requested certificate $CERT_ARN"
fi
for _ in $(seq 1 20); do   # the validation record takes a few seconds to appear
  REC=$(aws acm describe-certificate --certificate-arn "$CERT_ARN" \
    --query "Certificate.DomainValidationOptions[0].ResourceRecord" --output json)
  [ "$REC" != "null" ] && break
  sleep 3
done
CERT_STATUS=$(aws acm describe-certificate --certificate-arn "$CERT_ARN" --query Certificate.Status --output text)
REC_NAME=$(echo "$REC" | python3 -c 'import sys,json; print(json.load(sys.stdin)["Name"])')
REC_VALUE=$(echo "$REC" | python3 -c 'import sys,json; print(json.load(sys.stdin)["Value"])')

# 4. Attach the domain once the certificate is issued
ALIASES=$(aws cloudfront get-distribution-config --id "$DIST_ID" \
  --query "DistributionConfig.Aliases.Items" --output text)
if [ "$CERT_STATUS" = "ISSUED" ] && ! echo "$ALIASES" | grep -qw "$DOMAIN"; then
  aws cloudfront get-distribution-config --id "$DIST_ID" > /tmp/current.json
  ETAG=$(python3 -c 'import json; print(json.load(open("/tmp/current.json"))["ETag"])')
  DOMAIN="$DOMAIN" CERT_ARN="$CERT_ARN" python3 - <<'PY'
import json, os
cfg = json.load(open("/tmp/current.json"))["DistributionConfig"]
cfg["Aliases"] = {"Quantity": 1, "Items": [os.environ["DOMAIN"]]}
cfg["ViewerCertificate"] = {
    "ACMCertificateArn": os.environ["CERT_ARN"],
    "SSLSupportMethod": "sni-only",
    "MinimumProtocolVersion": "TLSv1.2_2021",
}
json.dump(cfg, open("/tmp/updated.json", "w"))
PY
  aws cloudfront update-distribution --id "$DIST_ID" --if-match "$ETAG" \
    --distribution-config file:///tmp/updated.json >/dev/null
  ALIASES="$DOMAIN"
  echo "Attached $DOMAIN to CloudFront"
fi

summary "## mykosreward.com on AWS"
summary ""
summary "| | |"
summary "|---|---|"
summary "| S3 bucket | \`$BUCKET\` |"
summary "| CloudFront | \`$DIST_ID\` — https://$DIST_DOMAIN |"
summary "| Certificate | $CERT_STATUS |"
summary "| Domain attached | $( [ "$ALIASES" = "None" ] && echo no || echo "$ALIASES" ) |"
summary ""
if [ "$CERT_STATUS" != "ISSUED" ]; then
  summary "### Add these in Squarespace (Domains → mykosreward.com → DNS → Custom records)"
  summary ""
  summary "1. Certificate check — **CNAME**, name \`${REC_NAME%.mykosreward.com.}\`, data \`$REC_VALUE\`"
  summary "2. Website — **CNAME**, name \`www\`, data \`$DIST_DOMAIN\`"
  summary ""
  summary "Then run this workflow again once the certificate shows ISSUED (usually 5–30 minutes after the records are added)."
else
  summary "Make sure Squarespace has **CNAME** \`www\` → \`$DIST_DOMAIN\`."
fi
