# PerfectLiturgy mobile API — authentication

Contract for the Android (and later iOS) Account flow. Pack download/sync routes are in [`api-mobile-packs.md`](./api-mobile-packs.md). One Account must work for web and mobile.

---

## Hosts and config

| Setting | Production default | Role |
| :--- | :--- | :--- |
| `AUTH_BASE_URL` (app) | `https://api.perfectliturgy.com` | Host the mobile client calls for auth HTTP |
| `BASE_URL` (app) | `https://api.perfectliturgy.com` | Content API (`/v1/...`) |
| `NEON_AUTH_BASE_URL` (server) | Branch Auth URL from Neon Console | Real Better Auth origin; **not** set in the APK |
| App deep link | `perfectliturgy://auth` | Where the device lands after sign-in (same in prod and dev) |

`api.perfectliturgy.com` is **production only**. For local API work, override both bases with a tunnel URL (ngrok) via `api.local.properties` — see [Dev testing with ngrok](#dev-testing-with-ngrok).

Do **not** put the Neon Auth host or `perfectliturgy://auth` in `AUTH_BASE_URL`. The app always appends `/api/auth/...` to `AUTH_BASE_URL`.

Current Neon Auth URL for project **perfectliturgy**, branch **main** (confirm in Console; prefer a **dev** Neon branch for tunnels):

```text
https://ep-autumn-dust-b90642nf.neonauth.c-7.eu-central-1.aws.neon.tech/neondb/auth
```

JWKS (for verifying JWTs on the API):

```text
https://ep-autumn-dust-b90642nf.neonauth.c-7.eu-central-1.aws.neon.tech/neondb/auth/.well-known/jwks.json
```

---

## Architecture

```text
Mobile app
  │  POST/GET  AUTH_BASE_URL + /api/auth/...
  ▼
AUTH_BASE_URL host  (prod: api.perfectliturgy.com · dev: https://….ngrok-free.app)
  │  forwards to Managed Auth (or self-hosted Better Auth)
  ▼
NEON_AUTH_BASE_URL  (.../neondb/auth)  ← use a Neon *dev* branch when testing
```

After OAuth or magic link, Managed Auth redirects to a **trusted https `callbackURL`**. That https page must then open the app scheme with a token the client can store. Neon’s trusted-domain allowlist accepts `http`/`https` origins only — not `perfectliturgy://`.

Recommended mobile bridge (host = current `AUTH_BASE_URL`):

| Step | URL |
| :--- | :--- |
| `callbackURL` sent by the app (or rewritten by the API) | `{AUTH_BASE_URL}/auth/mobile` |
| Bridge page redirects to | `perfectliturgy://auth?session_token=<token>` |

Examples: `https://api.perfectliturgy.com/auth/mobile` (prod) or `https://abc123.ngrok-free.app/auth/mobile` (dev).

Fragment form is also accepted: `perfectliturgy://auth#token=<token>`.

---

## Dev testing with ngrok

Use this so a debug build never hits production while you exercise Account + packs against a machine running the API.

### 1. Run the API locally

Start the API (or Next proxy) on a local port, e.g. `3000`. Point that process at a **Neon development branch** (`neon checkout …`, `neon env pull`) so Auth users and content are not production.

### 2. Expose it with ngrok

```bash
ngrok http 3000
```

Copy the https forwarding URL, e.g. `https://abc123.ngrok-free.app` (no trailing slash). Free ngrok hosts change each session unless you have a reserved domain.

### 3. Point the Android app at the tunnel

Create or edit root `api.local.properties` (gitignored; see `api.local.properties.example`):

```properties
# Dev only — do not commit. Defaults without this file are production.
BASE_URL=https://abc123.ngrok-free.app
AUTH_BASE_URL=https://abc123.ngrok-free.app
```

Set both to the same ngrok origin so packs and auth stay on one host. Rebuild the app after changing the file (`BuildConfig` is generated at compile time):

```bash
./gradlew :app:assembleDebug
```

Confirm in logcat or a debug screen that requests go to the ngrok host, not `api.perfectliturgy.com`.

### 4. Trust the ngrok origin in Neon (dev branch)

Neon must allow redirects to the bridge page. On the **dev** Auth branch:

```bash
neon neon-auth domain add https://abc123.ngrok-free.app
neon neon-auth domain list
```

When the ngrok host changes, add the new origin (and delete the old one if you like):

```bash
neon neon-auth domain delete https://old.ngrok-free.app
neon neon-auth domain add https://new.ngrok-free.app
```

Reserved / static ngrok domains avoid repeating this every session.

### 5. Bridge and callback rewrite on the **local** API

The local server must serve `GET /auth/mobile` and rewrite mobile `callbackURL` values to:

```text
https://abc123.ngrok-free.app/auth/mobile
```

not `https://api.perfectliturgy.com/auth/mobile`. Derive the public origin from the request `Host` / `X-Forwarded-Host` or an env such as `PUBLIC_APP_URL=https://abc123.ngrok-free.app`.

### 6. Optional: Google OAuth for the tunnel

Google’s authorized redirect URI is still **Neon’s** callback (`{NEON_AUTH_BASE_URL}/callback/google`), which does not change when ngrok changes. You only need a new Google redirect URI when the **Neon Auth base URL** changes (new branch / new Auth endpoint).

If Google shows a confusing consent host, that is expected: it is the Neon Auth hostname, not ngrok.

### 7. Ngrok free-tier interstitial

Some free ngrok plans inject a browser interstitial. Custom Tabs may need one tap through “Visit Site” before OAuth continues. A paid/static domain or `ngrok-skip-browser-warning` header on API requests (where applicable) reduces friction; the interstitial mainly affects the browser, not OkHttp.

### 8. Dev checklist

- [ ] `api.local.properties` points at ngrok; production URLs are not in that file while testing
- [ ] Local API uses a Neon **dev** branch (`NEON_AUTH_BASE_URL` / `DATABASE_URL` from that branch)
- [ ] Trusted domain on that branch includes the exact ngrok https origin
- [ ] `{AUTH_BASE_URL}/auth/mobile` opens `perfectliturgy://auth?session_token=…`
- [ ] Debug APK rebuilt after URL change
- [ ] Remove or comment out ngrok overrides (or delete `api.local.properties`) before a production-minded build

---

## Endpoints the API host must expose

All paths below are relative to `AUTH_BASE_URL`. Same Account as the web app.

### `GET /auth/mobile/start?provider=google|apple`

Preferred mobile social entry. The app opens this **https** URL in a Chrome Custom Tab (not an OkHttp-only `POST`).

The API calls Neon `sign-in/social` with `callbackURL` = `{AUTH_BASE_URL}/auth/mobile`, copies Neon’s `session_challenge` cookie onto the API/ngrok host (`SameSite=Lax`, no foreign `Domain`), and **302**s the tab to Google/Apple.

Starting social sign-in only via OkHttp leaves the challenge cookie off the Custom Tab; return to `/auth/mobile` then fails with `session_exchange_failed`.

**Success (302):** `Location` = provider URL; `Set-Cookie` may include the rewritten challenge cookie.

### `POST /api/auth/sign-in/social`

Still proxied for web and debugging. Mobile should prefer [`GET /auth/mobile/start`](#get-authmobilestartprovidergoogleapple).

**Request**

```json
{
  "provider": "google",
  "callbackURL": "perfectliturgy://auth",
  "newUserCallbackURL": "perfectliturgy://auth",
  "errorCallbackURL": "perfectliturgy://auth",
  "disableRedirect": true
}
```

`provider` is `google` or `apple`.

Because Neon cannot trust the app scheme, the API **must** rewrite `callbackURL` / `newUserCallbackURL` / `errorCallbackURL` to `{AUTH_BASE_URL}/auth/mobile` before calling Neon.

**Success (200)**

```json
{
  "url": "https://accounts.google.com/..."
}
```

Relative `url` / `redirect` values are resolved against `AUTH_BASE_URL`. A `Location` header is also accepted.

---

### `POST /api/auth/sign-in/magic-link`

Sends an email sign-in link.

**Request**

```json
{
  "email": "user@example.com",
  "callbackURL": "perfectliturgy://auth"
}
```

Same `callbackURL` rewrite rule as social sign-in. Magic Link must be enabled on the Neon Auth branch (or equivalent on self-hosted Better Auth).

**Success (200):** empty or JSON success body. The app shows “Check your email for a sign-in link.”

---

### `GET /api/auth/get-session`

Auth: `Authorization: Bearer <token>`.

Returns the current user/session. Used after the deep-link return and on launch when a token is stored.

**Success (200)** — accept either nested or flat user:

```json
{
  "user": {
    "id": "user_…",
    "email": "user@example.com",
    "name": "Jane"
  },
  "session": {
    "token": "…"
  }
}
```

If `session.token` / `session.sessionToken` is omitted, the client keeps the Bearer token it already stored.

**401 / 403:** clear local session; treat as signed out.

---

### `POST /api/auth/sign-out`

Auth: `Authorization: Bearer <token>` when available.

**Request body:** `{}`

Always clear the local session on the device even if the network call fails.

---

### `GET /auth/mobile` (bridge page — required)

Not called by OkHttp; opened by the browser after Neon finishes OAuth / magic link.

**Requirements**

1. The `{AUTH_BASE_URL}` origin must be on Neon’s trusted domains for the Auth branch you are using (prod host on **main**; ngrok host on a **dev** branch).
2. Page receives the session (cookie from the proxy, or token query params from Neon).
3. Redirect the browser to:

```text
perfectliturgy://auth?session_token=<token>
```

On error:

```text
perfectliturgy://auth?error=<code>
```

Token query/fragment keys the app accepts: `session_token`, `sessionToken`, `token`, `better-auth.session_token`.

---

## Session token contract

| Concern | Requirement |
| :--- | :--- |
| Storage | App stores the token in the Android session store; sends `Authorization: Bearer <token>` on authenticated calls |
| Content API | `/v1/packs/...` and `/v1/bookmarks` must accept the same Bearer token (or a JWT minted from it) |
| Web parity | Same user id / Account as the website |
| Preferred mobile token | Long-lived Better Auth **session** token (from Set-Cookie / get-session body). Short-lived JWTs (`set-auth-jwt`, `/token`) expire in ~15 minutes and leave Account looking signed in while pack download returns 401 |

Cookie-only web sessions are not enough for the native client. The bridge page must put a bearer-usable **session** token into the deep link. The content API resolves the Account via Neon `get-session` using the same public `Origin` as `/api/auth/*` (from `PUBLIC_APP_URL` / `x-forwarded-host`, not `localhost`) and sends the Bearer token both as `Authorization` and as `__Secure-neon-auth.session_token`.

---

## Neon configuration checklist

Project: **perfectliturgy** (`rough-fire-60854193`). Configure per branch (each branch has its own Auth URL).

### 1. Trusted domains

Console: **Auth → Configuration → Domains**, or:

```bash
# Production (main / prod Auth branch)
neon neon-auth domain add https://api.perfectliturgy.com
neon neon-auth domain add https://perfectliturgy.com

# Dev tunnel — exact host from the current ngrok session (dev Auth branch)
neon neon-auth domain add https://abc123.ngrok-free.app

neon neon-auth domain list
```

Rules from Neon: include scheme, omit trailing slash. Localhost ports are optional (`neon neon-auth domain allow-localhost enable` if needed).

Do **not** expect `perfectliturgy://auth` to be accepted as a trusted domain.

| Domain | Environment | Why |
| :--- | :--- | :--- |
| `https://api.perfectliturgy.com` | Production | Mobile bridge + API |
| `https://perfectliturgy.com` | Production | Web Account |
| `https://….ngrok-free.app` (exact) | Dev only | Tunnel bridge while testing |
| Preview hosts as needed | Preview | e.g. `https://*.preview…` wildcards |

Keep ngrok origins on a **dev** Neon branch. Do not add ephemeral tunnel hosts to production Auth unless you intend temporary prod debugging.

### 2. OAuth providers

Managed Auth supports **Google**, **GitHub**, and **Vercel** only.

Google (already configured on **main**):

```bash
neon neon-auth oauth-provider add \
  --provider-id google \
  --oauth-client-id <client-id> \
  --oauth-client-secret <client-secret>
```

Provider authorized redirect URI (register in Google Cloud Console) is **Neon’s** callback, not the app:

```text
{NEON_AUTH_BASE_URL}/callback/google
```

Example for the current main Auth URL:

```text
https://ep-autumn-dust-b90642nf.neonauth.c-7.eu-central-1.aws.neon.tech/neondb/auth/callback/google
```

### 3. Magic link

Enable Magic Link on the branch in Neon Auth (off by default on Managed Auth). Production email uses the branch SMTP (this project uses Resend via `noreply@perfectliturgy.com`).

### 4. Apple Sign In — not on Managed Auth

Managed Neon Auth **cannot** add Apple. Stage 10 still requires Apple on mobile.

Options:

1. **Self-hosted Better Auth** on `api.perfectliturgy.com` (recommended for Google + Apple + magic link in one place), still using Neon Postgres for the auth tables, or  
2. Keep Managed Auth for Google/magic link and add a separate Apple path — avoid unless necessary; one Account is harder.

Self-hosted Apple setup (Better Auth):

- Apple Developer: App ID with Sign in with Apple + Service ID (`clientId`)
- Return URL: `https://api.perfectliturgy.com/api/auth/callback/apple`
- Generate client-secret JWT from Team ID, Key ID, and `.p8`
- Add `https://appleid.apple.com` to Better Auth `trustedOrigins`
- Android uses the same Custom Tab + `/api/auth/sign-in/social` with `"provider": "apple"`

### 5. Proxy on the API host

Whether Managed or self-hosted, the public paths the app calls must remain:

```text
/api/auth/sign-in/social
/api/auth/sign-in/magic-link
/api/auth/get-session
/api/auth/sign-out
```

For Managed Auth with a Next-style handler, that is typically `app/api/auth/[...path]` forwarding to Neon. Env on the server:

| Variable | Purpose |
| :--- | :--- |
| `NEON_AUTH_BASE_URL` | Branch Auth URL (includes `/neondb/auth`) |
| `NEON_AUTH_JWKS_URL` | JWT verification for gated `/v1` routes |
| `NEON_AUTH_COOKIE_SECRET` | Cookie secret for the web proxy (32+ chars) |

Pull with `neon env pull` after linking the branch.

---

## Client call map

| User action | Request / navigation |
| :--- | :--- |
| Continue with Google | Open `{AUTH_BASE_URL}/auth/mobile/start?provider=google` in a Custom Tab → Google → bridge → `perfectliturgy://auth?session_token=` → `GET /api/auth/get-session` |
| Continue with Apple | Same with `provider=apple` |
| Email magic link | `POST /api/auth/sign-in/magic-link` → user opens email → bridge → deep link → `get-session` |
| App launch (signed in) | `GET /api/auth/get-session` with stored Bearer |
| Sign out | `POST /api/auth/sign-out`; clear local token; stop gated sync |
| After sign-in | `PUT` then `GET /v1/bookmarks` (see packs doc) |

---

## Acceptance checks

### Production

- [ ] Default (no `api.local.properties`) uses `https://api.perfectliturgy.com`; Neon URL never shipped in the APK as auth base
- [ ] Social sign-in returns a usable absolute `url` when `disableRedirect: true`
- [ ] Google completes and lands in the app with a bearer-usable token
- [ ] Magic link email completes the same deep-link path
- [ ] Apple works (requires self-hosted Better Auth until Neon adds Apple)
- [ ] `get-session` with Bearer restores user id / email / name
- [ ] Same Account appears on web after mobile sign-in (and the reverse)
- [ ] Gated pack sync (`/v1/packs/...`) accepts the mobile Bearer token
- [ ] Trusted domains include `https://api.perfectliturgy.com`; bridge page opens `perfectliturgy://auth`

### Dev (ngrok)

- [ ] Debug build with `api.local.properties` hits only the tunnel host
- [ ] Neon **dev** branch trusts that ngrok origin; local API rewrites callback to `{ngrok}/auth/mobile`
- [ ] Full Google (and magic link) flow returns into the app without calling production
