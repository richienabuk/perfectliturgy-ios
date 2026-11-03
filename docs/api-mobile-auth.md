# PerfectLiturgy mobile API — authentication

Contract for the Android (and later iOS) Account flow. Pack download/sync routes are in [`api-mobile-packs.md`](./api-mobile-packs.md). One Account must work for web and mobile.

---

## Hosts and config

| Setting | Production | Dev | Role |
| :--- | :--- | :--- | :--- |
| `AUTH_BASE_URL` (app) | `https://api.perfectliturgy.com` | `https://perfectliturgyapi.richienabuk.top` | Host the mobile client calls for auth HTTP |
| `BASE_URL` (app) | `https://api.perfectliturgy.com` | `https://perfectliturgyapi.richienabuk.top` | Content API (`/v1/...`) |
| `NEON_AUTH_BASE_URL` (server) | Branch Auth URL from Neon Console | Dev branch Auth URL from Neon Console | Real Better Auth origin; **not** set in the APK |
| App deep link | `perfectliturgy://auth` | `perfectliturgy://auth` | Where the device lands after sign-in |

`api.perfectliturgy.com` is **production only**. Dev is `https://perfectliturgyapi.richienabuk.top`. Point a debug build at it with `api.local.properties`. See [Dev](#dev).

Do **not** put the Neon Auth host or `perfectliturgy://auth` in `AUTH_BASE_URL`. The app always appends `/api/auth/...` to `AUTH_BASE_URL`.

Current Neon Auth URL for project **perfectliturgy**, branch **main** (confirm in Console; the dev API uses its own Neon branch):

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
AUTH_BASE_URL host  (prod: api.perfectliturgy.com · dev: perfectliturgyapi.richienabuk.top)
  │  forwards to Managed Auth (or self-hosted Better Auth)
  ▼
NEON_AUTH_BASE_URL  (.../neondb/auth)  ← use a Neon *dev* branch when testing
```

After OAuth or magic link, Managed Auth redirects to a **trusted https `callbackURL`**. That page mints a one-time code bound to the Neon session, the app's `state`, and the PKCE `code_challenge`. The session token is not put in the URL, the fragment, or the HTML. The app exchanges the code at `POST /auth/mobile/token` with the code verifier it kept. Neon’s trusted-domain allowlist accepts `http`/`https` origins only — not `perfectliturgy://`.

Recommended mobile bridge (host = current `AUTH_BASE_URL`):

| Step | URL |
| :--- | :--- |
| `callbackURL` sent by the app (or rewritten by the API) | `{AUTH_BASE_URL}/auth/mobile` |
| Production bridge (`api.perfectliturgy.com`) | `https://api.perfectliturgy.com/auth/mobile/return?code=<code>&state=<state>` |
| Any other host (dev, ngrok, local) | `perfectliturgy://auth?code=<code>&state=<state>` |
| App exchanges the code | `POST {AUTH_BASE_URL}/auth/mobile/token` → `{ "token": "<session>" }` |

Examples: `https://api.perfectliturgy.com/auth/mobile` (prod) or `https://perfectliturgyapi.richienabuk.top/auth/mobile` (dev). The app scheme `perfectliturgy://auth` is claimable by any app, so it never carries the session token.

---

## Dev

Dev is `https://perfectliturgyapi.richienabuk.top`. A debug build uses that host for Account and packs, and does not call `api.perfectliturgy.com`.

### 1. Point the app at dev

Create or edit root `api.local.properties` (gitignored; see `api.local.properties.example`):

```properties
# Dev only. Do not commit. Defaults without this file are production.
BASE_URL=https://perfectliturgyapi.richienabuk.top
AUTH_BASE_URL=https://perfectliturgyapi.richienabuk.top
```

Set both to that origin so packs and auth stay on one host. Rebuild the app after changing the file (`BuildConfig` is generated at compile time):

```bash
./gradlew :app:assembleDebug
```

Confirm in logcat or a debug screen that requests go to `perfectliturgyapi.richienabuk.top`, not `api.perfectliturgy.com`.

### 2. Trust the dev origin in Neon

Neon must allow redirects to the bridge page. On the **dev** Auth branch:

```bash
neon neon-auth domain add https://perfectliturgyapi.richienabuk.top
neon neon-auth domain list
```

The bridge is `https://perfectliturgyapi.richienabuk.top/auth/mobile`. On that deployment, `PUBLIC_APP_URL` is the same origin.

### 3. Dev checklist

- [ ] `api.local.properties` points at `https://perfectliturgyapi.richienabuk.top`; production URLs are not in that file while testing
- [ ] The dev API uses a Neon **dev** branch (`NEON_AUTH_BASE_URL` / `DATABASE_URL` from that branch)
- [ ] Trusted domain on that branch includes `https://perfectliturgyapi.richienabuk.top`
- [ ] `https://perfectliturgyapi.richienabuk.top/auth/mobile` opens `perfectliturgy://auth?code=…&state=…`, and `POST /auth/mobile/token` returns the session token
- [ ] Debug APK rebuilt after URL change
- [ ] Remove or comment out the dev overrides (or delete `api.local.properties`) before a production-minded build

### Optional: API on your machine

To exercise Account and packs against a process on your computer, run the API on a local port (for example `3000`) pointed at a Neon **dev** branch, then expose it:

```bash
ngrok http 3000
```

Put that https origin in `BASE_URL` and `AUTH_BASE_URL`, add the same origin with `neon neon-auth domain add`, and set `PUBLIC_APP_URL` to it. The bridge must be `{that origin}/auth/mobile`, not the production or dev host above. Free ngrok hosts change each session. Some free plans show a browser interstitial before OAuth continues. Google’s authorized redirect URI stays Neon’s callback (`{NEON_AUTH_BASE_URL}/callback/google`).

---

## Endpoints the API host must expose

All paths below are relative to `AUTH_BASE_URL`. Same Account as the web app.

### `POST /api/auth/sign-in/social`

Starts Google or Apple **browser** sign-in. The app opens the returned URL in a Chrome Custom Tab (or `ASWebAuthenticationSession` on iPhone).

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

`provider` is `google` or `apple`. Prefer `GET /auth/mobile/start` on mobile so PKCE is stored on this host before the provider redirect.

A body that includes a native `idToken` is **400** with `error: "use_mobile_apple"`. Native Sign in with Apple on iPhone must use `POST /auth/mobile/apple` (then `POST /auth/mobile/token`), not this route.

Because Neon cannot trust the app scheme, the API **must** either:

1. Rewrite `callbackURL` / `newUserCallbackURL` / `errorCallbackURL` to `{AUTH_BASE_URL}/auth/mobile` before calling Neon (prod or dev), and have that page open `perfectliturgy://auth`, or  
2. Document that the app will send the https bridge URL once the client is updated to match.

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
  "email": "user@yahoo.com",
  "callbackURL": "perfectliturgy://auth",
  "state": "<app-generated>",
  "codeChallenge": "<pkce-s256-base64url>",
  "codeChallengeMethod": "S256"
}
```

Same `callbackURL` rewrite rule as social sign-in: the API rewrites it to `{AUTH_BASE_URL}/auth/mobile` before calling Neon. `state` and `codeChallenge` are stored on the magic-link record. A cookie from this POST is not enough, because the person may open the email in another browser. Missing `state` or `codeChallenge` is **400** and no email is sent. Magic Link must be enabled on the Neon Auth branch (or equivalent on self-hosted Better Auth).

The address must be Gmail, Googlemail, Yahoo, Outlook, Hotmail, Live, MSN, or `perfectliturgy.com`. Any other domain is refused with **400** and no email is sent:

```json
{
  "error": "DOMAIN_BLOCKED",
  "message": "Use a Gmail, Yahoo, Outlook, Hotmail, Live, MSN, or perfectliturgy.com address."
}
```

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

### `GET /auth/mobile/start`

Custom Tab entry for Google and Apple. Query params, all required:

| Param | Value |
| :--- | :--- |
| `provider` | `google` or `apple` |
| `state` | Unguessable value from the app |
| `code_challenge` | PKCE S256, base64url, no padding |
| `code_challenge_method` | `S256` |

Missing `state` or `code_challenge` is **400**, not a redirect. The API stores `state` and `code_challenge` in a `SameSite=Lax` cookie on this host, copies Neon’s `session_challenge` cookie onto this host, and **302**s to Google or Apple. `callbackURL` sent to Neon is `{AUTH_BASE_URL}/auth/mobile`.

### `GET /auth/mobile` (bridge page — required)

Not called by OkHttp; opened by the browser after Neon finishes OAuth / magic link.

**Requirements**

1. The `{AUTH_BASE_URL}` origin must be on Neon’s trusted domains for the Auth branch you are using (prod host on **main**; `https://perfectliturgyapi.richienabuk.top` on a **dev** branch).
2. Page receives the Neon session (cookie, verifier, or token query param). It also loads the pending `state` and `code_challenge` from the social cookie, or from the magic-link record when that cookie is absent.
3. Create a single-use code that lives about 60 seconds, bound to that session token, `state`, and `code_challenge`.
4. Send the browser to:

```text
https://api.perfectliturgy.com/auth/mobile/return?code=<code>&state=<state>
```

on `api.perfectliturgy.com`, and on any other host:

```text
perfectliturgy://auth?code=<code>&state=<state>
```

Safari and Android get a custom-scheme URL as a 302. Chrome, Firefox, and Edge on iPhone ignore a custom-scheme redirect, so they get an HTML page with the same URL as a link. The person taps **Open PerfectLiturgy**. The session token is never in that URL, the fragment, or the HTML.

On error:

```text
perfectliturgy://auth?error=<code>
```

Include `state` when the attempt is known. Error codes: `session_exchange_failed`, `missing_session`, `auth_not_configured`, `access_denied`, `invalid_provider`, `auth_failed`.

### `GET /auth/mobile/return`

Production page behind the Android App Link. If Android does not intercept `https://api.perfectliturgy.com/auth/mobile/return?code=<code>&state=<state>`, the page may link to `perfectliturgy://auth` with the same `code` and `state`. It must not exchange the code or show the session token.

`GET /.well-known/assetlinks.json` is `application/json`:

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.perfectliturgy",
    "sha256_cert_fingerprints": ["<from ANDROID_SHA256_CERT_FINGERPRINTS>"]
  }
}]
```

Those fingerprints are the Play App Signing SHA-256 and the debug keystore SHA-256. If the env is empty, the list is empty. Do not write placeholder certificates. How to copy each value, and what the iPhone app uses instead, is in [`mobile-app-link-keys.md`](./mobile-app-link-keys.md).

### `POST /auth/mobile/apple`

Native Sign in with Apple on iPhone (API ready; **iOS app uses Custom Tab Apple for now**). Same security model as Google: the response is a one-time `code` + `state`; the long-lived session token comes only from `POST /auth/mobile/token` with the PKCE verifier.

**Request**

```json
{
  "idToken": {
    "token": "<Apple identityToken JWT>",
    "nonce": "<same nonce sent to Apple, if any>"
  },
  "state": "<app-generated>",
  "codeChallenge": "<pkce-s256-base64url>",
  "codeChallengeMethod": "S256"
}
```

`idToken` may also be the JWT string alone. Missing `state`, `codeChallenge`, or `idToken` is **400**. The API posts the idToken to Neon `sign-in/social`, stores a single-use code bound to that session and the PKCE challenge (about 60 seconds), and never returns the session token in this response.

**Success (200)**

```json
{
  "code": "<one-time>",
  "state": "<echo of app state>"
}
```

Then call `POST /auth/mobile/token` exactly as after Google.

Neon’s Apple OAuth provider must accept the iPhone app’s **bundle id** as an audience for native idTokens (Services ID alone is for the web / Custom Tab flow). Configure that on the Neon Auth branch if native Apple returns `session_exchange_failed`.

### `POST /auth/mobile/token`

No `Authorization` header.

```json
{
  "code": "<one-time>",
  "state": "<app-generated>",
  "codeVerifier": "<pkce verifier>"
}
```

Accepted only when the code matches an unexpired single-use row, `state` equals that row, and `base64url(SHA-256(codeVerifier))` equals the stored `code_challenge` (no padding). The row is then deleted.

**200**

```json
{ "token": "<long-lived Better Auth session token>" }
```

That token is `Authorization: Bearer` on `GET /api/auth/get-session`, `/v1/packs`, and `/v1/bookmarks`. **400** for a bad, reused, or expired code, with no token in the body.

---

## Session token contract

| Concern | Requirement |
| :--- | :--- |
| Storage | App stores the token from `POST /auth/mobile/token` and sends `Authorization: Bearer <token>` on authenticated calls |
| Content API | `/v1/packs/...` and `/v1/bookmarks` must accept the same Bearer token |
| Web parity | Same user id / Account as the website for Google, Apple, and magic link |
| Handoff | One-time code and `state` in the link. The long-lived session token is returned only to the app that holds the PKCE verifier |
| Preferred mobile token | Long-lived Better Auth session token (the session cookie value), not the short-lived JWT |

Cookie-only web sessions are not enough for the native client. The bridge must not put that token in the app link.

---

## Neon configuration checklist

Project: **perfectliturgy** (`rough-fire-60854193`). Configure per branch (each branch has its own Auth URL).

### 1. Trusted domains

Console: **Auth → Configuration → Domains**, or:

```bash
# Production (main / prod Auth branch)
neon neon-auth domain add https://api.perfectliturgy.com
neon neon-auth domain add https://perfectliturgy.com

# Dev API (dev Auth branch)
neon neon-auth domain add https://perfectliturgyapi.richienabuk.top

neon neon-auth domain list
```

Rules from Neon: include scheme, omit trailing slash. Localhost ports are optional (`neon neon-auth domain allow-localhost enable` if needed).

Do **not** expect `perfectliturgy://auth` to be accepted as a trusted domain.

| Domain | Environment | Why |
| :--- | :--- | :--- |
| `https://api.perfectliturgy.com` | Production | Mobile bridge + API |
| `https://perfectliturgy.com` | Production | Web Account |
| `https://perfectliturgyapi.richienabuk.top` | Dev | Mobile bridge + API |
| Preview hosts as needed | Preview | e.g. `https://*.preview…` wildcards |

A laptop tunnel origin, if you add one, belongs on the **dev** Neon branch. Do not add it to production Auth.

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

### 4. Apple Sign In (Managed Auth)

Managed Neon Auth supports Apple as an OAuth provider. Configure it on each Auth branch (Services ID, `.p8` key, Team ID, Key ID).

**Web / Custom Tab / `ASWebAuthenticationSession` (current iPhone Apple path)**

- Apple **Services ID** is the OAuth `client_id` in Neon (a Services ID such as `com.perfectliturgy.web`, not the App ID / bundle id alone)
- Return URL on the Services ID: `{NEON_AUTH_BASE_URL}/callback/apple` (not `api.perfectliturgy.com`)
- Domain: the Neon Auth host only (no `https://`, no path)
- Mobile entry: `GET /auth/mobile/start?provider=apple&…` then `POST /auth/mobile/token`

**Native Sign in with Apple (iPhone sheet) — deferred**

Managed Neon Auth does not yet turn a native Apple identity token into a session. Until that works, iPhone uses the Custom Tab / `ASWebAuthenticationSession` path above (`provider=apple`). Keep `POST /auth/mobile/apple` on the API for later; the iOS app does not call it yet.

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
| `ANDROID_SHA256_CERT_FINGERPRINTS` | Play App Signing SHA-256 and debug keystore SHA-256, comma-separated. `assetlinks.json` stays empty until these are set |

Pull with `neon env pull` after linking the branch.

---

## Client call map

| User action | Request / navigation |
| :--- | :--- |
| Continue with Google | `GET /auth/mobile/start?provider=google&state=&code_challenge=&code_challenge_method=S256` → provider → bridge → code + state → `POST /auth/mobile/token` → `GET /api/auth/get-session` |
| Continue with Apple | Same as Google with `provider=apple` (`ASWebAuthenticationSession`). Native sheet / `POST /auth/mobile/apple` deferred until Managed Auth accepts iPhone idTokens |
| Email magic link | `POST /api/auth/sign-in/magic-link` with `state`, `codeChallenge`, `codeChallengeMethod` → user opens email → bridge → code + state → `POST /auth/mobile/token` → `get-session` |
| Play review sign-in | On the device browser, open `https://perfectliturgyapi.richienabuk.top/auth/review?code=…` → `perfectliturgy://auth?session_token=` |
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
- [ ] Apple works via Custom Tab / `ASWebAuthenticationSession` (`/auth/mobile/start?provider=apple` → `/auth/mobile/token`)
- [ ] `get-session` with Bearer restores user id / email / name
- [ ] Same Account appears on web after mobile sign-in (and the reverse)
- [ ] Gated pack sync (`/v1/packs/...`) accepts the mobile Bearer token
- [ ] Trusted domains include `https://api.perfectliturgy.com`; the production bridge opens `/auth/mobile/return?code=&state=` and `assetlinks.json` lists the real certificate fingerprints
- [ ] A production build ignores `perfectliturgy://auth?session_token=`
- [ ] The Play production artifact is built without `api.local.properties`

### Play review on the dev API

Dev is `https://perfectliturgyapi.richienabuk.top`, and the closed-test build calls that host. The reviewer opens `GET /auth/review?code=` in the device browser. There is no review button in the app. The code is `REVIEW_LOGIN_CODE`, and that same value is the password for `reviewer@perfectliturgy.com` on the dev Auth branch. The route opens `perfectliturgy://auth?session_token=…`. It is 404 on every other host, and 404 when the code is unset or `PUBLIC_APP_URL` is a different origin.

This is the only path that places the session token in the app link. The closed-test build accepts `session_token` only when its compiled auth host is exactly `https://perfectliturgyapi.richienabuk.top`, then calls `GET /api/auth/get-session` before saving the token. A production build, whose host is `https://api.perfectliturgy.com`, ignores `session_token`. Any other host is not dev. Build the Play production artifact without `api.local.properties`.

Email and password stays off on the production Auth branch. Magic link delivery is unchanged on both branches. Sign-up with a password stays off on the dev branch.

### Dev

- [ ] The closed-test build accepts `perfectliturgy://auth?session_token=` only when its auth host is exactly `https://perfectliturgyapi.richienabuk.top`, then calls `get-session` before saving the token
- [ ] Debug build with `api.local.properties` hits only `https://perfectliturgyapi.richienabuk.top`
- [ ] Neon **dev** branch trusts that origin; the dev API rewrites the callback to `https://perfectliturgyapi.richienabuk.top/auth/mobile`
- [ ] Full Google (and magic link) flow returns into the app without calling production
