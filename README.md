# mykosreward.com

The website for *Myko's Reward: The Original Power* by Keith B. Still (ALLnALL Publishing).

It's a single-page static site with no build step: plain HTML, CSS and JavaScript, with the fonts and images included. Everything that goes live is in `site/`.

```
site/
  index.html     the page
  styles.css     look and feel
  main.js        wires up buy buttons and the share button
  config.js      store links (edit this to change where "Buy" buttons go)
  assets/        cover, background, social-share image, icons
  fonts/         self-hosted fonts and their licences
```

## Change a store link

Edit `site/config.js`, commit, and push to `main`. A link left as `""` shows **Coming soon** instead of a broken button. `social` sets where the footer's `@mykosreward` links to (it's plain text until you fill it in).

## Preview locally

```
npx serve site
```

## Deploy to AWS

Two GitHub Actions workflows do everything; nothing needs to be installed locally.

**One-time setup**

1. In AWS, create an IAM user for deploys (IAM → Users → Create user, e.g. `mykosreward-deploy`) and attach the policies `AmazonS3FullAccess`, `CloudFrontFullAccess` and `AWSCertificateManagerFullAccess`. Create an access key for it (Security credentials → Create access key → "Application running outside AWS").
2. In GitHub → Settings → Secrets and variables → Actions → **New repository secret**, add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from that key.
3. Actions → **Set up AWS for the site** → Run workflow. It creates a private S3 bucket, a CloudFront distribution and an HTTPS certificate request (`scripts/provision-aws.sh`). The run summary lists two DNS records to add in Squarespace (Domains → mykosreward.com → DNS → Custom records): the certificate check CNAME and `www` → the CloudFront address.
4. When the certificate is issued (usually 5–30 minutes after the records are in), run **Set up AWS for the site** again. It attaches www.mykosreward.com to CloudFront.
5. For the bare domain, add a Squarespace forwarding rule (Domain Forwarding → Manage rules): `mykosreward.com` → `https://www.mykosreward.com`, permanent (301). Keep the four A records and the MX/TXT email records.

**Every update**

**Deploy site to AWS** runs on every push that changes `site/` (or by hand from the Actions tab). It uploads `site/` to the bucket and refreshes CloudFront. It finds the bucket and distribution on its own; the optional repository variables `S3_BUCKET`, `CLOUDFRONT_DISTRIBUTION_ID` and `AWS_REGION` override that. An `AWS_ROLE_ARN` secret (GitHub OIDC) can be used instead of access keys.
