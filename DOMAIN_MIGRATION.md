# Move www.mykosreward.com from Blogger to Google Sites

`www.mykosreward.com` currently points to a Blogger blog. This guide unhooks it
from Blogger and points it at the Google Site instead.

All of the changes happen in three web dashboards: Blogger, Google Sites, and
the place where the domain is registered (where you manage its DNS — e.g.
Squarespace Domains (formerly Google Domains), GoDaddy, Namecheap, Cloudflare).
Nothing in this repository changes how the domain resolves.

**Do the steps in order.** Google does not let one domain be connected to two
Google products at once, so Google Sites will reject the domain until Blogger
releases it.

---

## Step 1 — Disconnect the domain from Blogger

1. Go to <https://www.blogger.com> and sign in with the account that owns the blog.
2. Pick the blog that shows at www.mykosreward.com (top-left blog menu).
3. Open **Settings** → section **Publishing** → **Custom domain**.
4. Remove `www.mykosreward.com` (delete the domain or clear the field), then **Save**.
5. If **Redirect domain** (the setting that sends `mykosreward.com` to `www.`) is on, turn it off.

The blog stays online at its `*.blogspot.com` address. Nothing is deleted.
If you want the blog gone completely, use **Settings → Manage blog → Remove your blog**
(optional; you can do this later).

## Step 2 — Clean up the old Blogger DNS records

At your domain registrar's DNS settings for `mykosreward.com`, **delete**:

| Type  | Host / Name                                | Value (old Blogger)                          |
|-------|--------------------------------------------|----------------------------------------------|
| CNAME | `www`                                      | `ghs.google.com`                             |
| CNAME | a random string (e.g. `abcd1234efgh`)      | `gv-xxxxxxxx.dv.googlehosted.com`            |
| A     | `@` (the bare domain)                      | `216.239.32.21`                              |
| A     | `@`                                        | `216.239.34.21`                              |
| A     | `@`                                        | `216.239.36.21`                              |
| A     | `@`                                        | `216.239.38.21`                              |

Leave any **MX** records (email) and any **TXT** records you don't recognize alone.

## Step 3 — Verify you own the domain (one time)

Google Sites only accepts domains you've proved you own in Google Search Console.

1. Go to <https://search.google.com/search-console> with the **same Google
   account that owns the Google Site**.
2. **Add property** → **Domain** → enter `mykosreward.com` → Continue.
3. Copy the `google-site-verification=...` TXT record it gives you.
4. At your registrar, add a **TXT** record: Host `@`, Value = that string.
5. Back in Search Console, click **Verify** (can take a few minutes to a few hours).

If it already shows as verified for this account, skip this step.

## Step 4 — Connect the domain in Google Sites

1. Open your site at <https://sites.google.com>.
2. Click the **gear (Settings)** icon → **Custom domains** → **Start setup**.
3. Choose **Use a domain from a third-party provider**.
4. Enter `www.mykosreward.com` → **Next** → **Done**.
5. Click **Publish** at the top right so the site is live.

## Step 5 — Point the domain at Google Sites

At your registrar, add:

| Type  | Host / Name | Value                   |
|-------|-------------|-------------------------|
| CNAME | `www`       | `ghs.googlehosted.com.` |

(Some registrars want the trailing dot, some don't; both are fine.)

### The bare domain (`mykosreward.com` without `www`)

Google Sites cannot serve a bare domain. To make `mykosreward.com` work, use
your registrar's **Domain forwarding / URL redirect** feature:

- Forward `mykosreward.com` → `https://www.mykosreward.com`
- Type: **Permanent (301)**, forward path on, SSL/HTTPS on if offered

## Step 6 — Wait and check

- DNS changes usually take effect within an hour, but can take up to 48 hours.
- Google issues the HTTPS certificate automatically. You may see a certificate
  warning for a little while after the CNAME starts working; this clears on its own.
- Test in a private/incognito window: <https://www.mykosreward.com> and
  <http://mykosreward.com> should both show the Google Site.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Google Sites says the domain is "already in use" / "already mapped" | Blogger still has it. Repeat Step 1 and wait ~15 minutes. |
| Google Sites says you don't own the domain | Finish Step 3 with the same Google account that owns the Site. |
| Still shows the Blogger blog | Old `www → ghs.google.com` CNAME still exists (Step 2), or your browser/DNS is cached. Try another device or network. |
| "Server not found" at `www.mykosreward.com` | The `www` CNAME to `ghs.googlehosted.com` is missing or mistyped (Step 5). |
| Bare `mykosreward.com` doesn't load | Set up forwarding (Step 5) and remove the old `@` A records (Step 2). |
