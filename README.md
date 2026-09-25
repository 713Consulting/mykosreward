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

`.github/workflows/deploy.yml` uploads `site/` to an S3 bucket and clears the CloudFront cache on every push to `main` that changes `site/`. You can also run it by hand from the **Actions** tab. It needs these settings under **Settings → Secrets and variables → Actions**:

| Kind | Name | Value |
|---|---|---|
| Variable | `S3_BUCKET` | bucket name, e.g. `www.mykosreward.com` |
| Variable | `AWS_REGION` | optional, defaults to `us-east-1` |
| Variable | `CLOUDFRONT_DISTRIBUTION_ID` | optional; if set, the cache is cleared after upload |
| Secret | `AWS_ROLE_ARN` | IAM role for GitHub OIDC login (recommended) |
| Secret | `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | use instead of the role if you don't have OIDC set up |

The IAM identity needs `s3:ListBucket`, `s3:PutObject`, `s3:DeleteObject` on the bucket and `cloudfront:CreateInvalidation` on the distribution.

Typical AWS setup: a private S3 bucket behind a CloudFront distribution, with `index.html` as the default root object, alternate domain names `www.mykosreward.com` and `mykosreward.com`, and an ACM certificate (in `us-east-1`) covering both.

## Point the domain at AWS (Squarespace Domains)

In Squarespace → Domains → mykosreward.com → DNS:

1. **Custom records → Add record:** `CNAME`, name `www`, data = the CloudFront domain (`dxxxxxxxx.cloudfront.net`).
2. **ACM validation:** add the CNAME records the certificate request gives you.
3. **Bare domain:** in **Squarespace Domain Forwarding → Manage rules**, forward `mykosreward.com` to `https://www.mykosreward.com` (301). Keep the four A records; the forwarding uses them.
4. **Leave the MX and TXT records alone.** They run Google Workspace email.
