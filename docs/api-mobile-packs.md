# PerfectLiturgy mobile API — packs, sync, downloads

Contract for the Android (and later iOS) clients. Production base: `https://api.perfectliturgy.com`. For local API work, override with an ngrok https origin in `api.local.properties` (see [`api-mobile-auth.md`](./api-mobile-auth.md#dev-testing-with-ngrok)).

Auth routes live under Better Auth (often the same host). Content routes are below.

---

## Rules the API must honour

| Rule | Detail |
| :--- | :--- |
| Categories are fixed in the app | `hymns`, `readings`, `order`, `rosary`, `litanies`, `stations`, `prayers`, `calendar` |
| Languages come from the catalog | A new language does **not** need an APK update |
| Every pack is removable | Including English and Latin. Re-install uses `/download` again |
| **Download** | First install for **every** pack type (hymns, readings, Order of Mass, Rosary, …) |
| **Sync** | Updates only for installed **live** packs (hymns + daily readings). Manual Sync button or Wi‑Fi background job. Requires `since` |
| Auth | `GET /v1/packs` is public. Download/sync honor `requires_sign_in` as a **real gate**. Bookmarks require a signed-in Account. The app seeds English/Latin as installed at first launch; removing and re-downloading them still follows the gate |
| No `ships_with_app` | Do not send that field. The client may seed English/Latin locally; the catalog does not mark packs as bundled |

---

## Pack identity

`pack_id` = `{type}-{language}` or `{type}-{country}` / `{type}-{translation}`.

Examples: `hymns-en`, `hymns-efi`, `readings-rsvce`, `order-la`, `rosary-es`, `stations-en`, `calendar-nigeria`.

The client uses this id in path segments. Keep ids stable.

---

## 1. Catalog

### `GET /v1/packs`

Auth: none.

Lists every pack available for download or sync. The app merges this with local seed rows (English Hymns when bundled).

**Response** — list envelope (`data` + pagination). Same shape for other list routes.

```json
{
  "data": [
    {
      "pack_id": "hymns-en",
      "type": "hymns",
      "language": "en",
      "display_name": "English Hymns",
      "revision": "2026-10-20T09:15:03.421Z",
      "size": 4200000,
      "requires_sign_in": true,
      "mode": "live"
    },
    {
      "pack_id": "readings-rsvce",
      "type": "readings",
      "language": "en",
      "display_name": "RSVCE",
      "revision": "2026-10-20T09:15:03.421Z",
      "size": 1200000,
      "requires_sign_in": false,
      "mode": "live",
      "metadata": {
        "display_window": "week"
      }
    },
    {
      "pack_id": "rosary-la",
      "type": "rosary",
      "language": "la",
      "display_name": "Rosary · Latin",
      "revision": "2026-10-01T12:00:00.000Z",
      "size": 180000,
      "requires_sign_in": true,
      "mode": "download"
    },
    { 
      "pack_id": "order-es",
      "type": "order",
      "language": "es",
      "display_name": "Order of Mass · Spanish",
      "revision": "2026-10-01T12:00:00.000Z",
      "size": 90000,
      "requires_sign_in": true,
      "mode": "download"
    },
    {
      "pack_id": "hymns-efi",
      "type": "hymns",
      "language": "efi",
      "display_name": "Efik Hymns",
      "revision": "2026-10-19T08:30:00.000Z",
      "size": 2800000,
      "requires_sign_in": true,
      "mode": "live"
    }
  ],
  "page": 1,
  "pageSize": 4,
  "total": 4
}
```

| Envelope field | Required | Notes |
| :--- | :---: | :--- |
| `data` | yes | Array of pack rows |
| `page` | yes | 1-based page index |
| `pageSize` | yes | Page size (full catalog may equal `total`) |
| `total` | yes | Total matching rows |

| Pack field | Required | Notes |
| :--- | :---: | :--- |
| `pack_id` | yes | Path id for download/sync |
| `type` | yes | One of the fixed category types above |
| `language` | usually | ISO-ish code; calendars may omit and use country in `pack_id` |
| `display_name` | yes | Shown in Downloads (full row title). The language control shows it when `language_name` is absent |
| `language_name` | no | The language's own name, such as `Efik`. The language control and the language sheet show it. The app has no language table, so a new language needs no app release |
| `revision` | yes | Empty on first pack create; UTC ISO-8601 after the first revise. Client stores it; send as `since` on sync when non-empty |
| `size` | no | Bytes; client shows e.g. `4.2 MB` |
| `requires_sign_in` | no | Real gate for download/sync. Default client assumption if omitted: `true`. Seeded EN/LA start installed without a network call |
| `mode` | yes | `live` → download then sync; `download` → download only |
| `metadata` | no | Object for type-specific extras. Unknown keys are ignored by older clients |


**`metadata` (known keys today)**

| Key | Used by | Notes |
| :--- | :--- | :--- |
| `display_window` | `readings` | `day` \| `week` \| `month` — how much verse text the sync body covers |

Add future readings-only (or other type-only) fields here instead of new top-level catalog properties.

**Order of Mass defaults:** the client seeds `order-en` and `order-la` as installed on first run (bundled assets). Catalog rows for those ids are optional. Every other Order language (`order-es`, `order-efi`, …) is `mode: "download"` and is installed only after `GET …/download`.

**Special Prayers defaults:** the client seeds `prayers-en` and `prayers-la` as installed on first run (bundled assets). **Rosary** English/Latin likewise seed as `rosary-en` / `rosary-la` (bundled assets). **Stations of the Cross** English/Latin likewise seed as `stations-en` / `stations-la` (bundled assets). Illustrations for the fourteen stations ship with the app and are shared across languages; they are not part of the download body. **Litanies** English/Latin ship as bundled screen assets (like Order of Mass bodies) without requiring catalog seed rows; other litany, prayer, rosary, and stations languages are `mode: "download"` only.


Do **not** send `ships_with_app`.

---

## 2. Download (first install)

### `GET /v1/packs/{pack_id}/download`

Auth: required when `requires_sign_in` is true (or omitted — client treats omitted as gated).

Used once from the Downloads screen for every pack type, including `hymns` and `readings`.
Used for downloading per language: `order`, `rosary`, `litanies`, `stations`, `prayers`, `calendar`.

**Path**

| Param | Example |
| :--- | :--- |
| `pack_id` | `hymns-en` |

**Response** — full body for that language (not a delta).

### Hymns (and readings when shipped)

```json
{
  "pack_id": "hymns-en",
  "type": "hymns",
  "language": "en",
  "revision": "2026-10-20T09:15:03.421Z",
  "data": [
    {
      "id": "uuid",
      "language": "en",
      "hymn_number": 42,
      "title": "…",
      "first_line": "…",
      "lyrics": "…",
      "sections": [
        { "id": "v1", "type": "verse", "label": "1", "content": "…" }
      ],
      "seasons": ["advent"],
      "mass_parts": ["entrance"],
      "meter": null,
      "tune_name": null,
      "key": null,
      "authors": null,
      "topics": [],
      "scripture_references": [],
      "video_url": [],
      "audio_url": [],
      "sheet_music_url": [],
      "is_public_domain": true,
      "permission_granted": false,
      "background_notes": null,
      "updated_at": "2026-10-19T12:00:00Z",
      "deleted_at": null
    }
  ]
}
```

Do not include admin-only fields (`import_source`, rights follow-up columns).

### Static packs (`order`, `rosary`, `litanies`, `stations`, `prayers`, `calendar`)

```json
{
  "pack_id": "rosary-la",
  "type": "rosary",
  "language": "la",
  "revision": "2026-10-01T12:00:00.000Z",
  "data": { }
}
```


### Order of Mass download body

`GET /v1/packs/order-{lang}/download`

Language belongs on the **envelope** only (`language: "es"`). Do not nest a language name in `data`. The catalog row carries the label (`language_name`, else `display_name`).

`data` is the list of major Mass parts (Introductory Rites, Liturgy of the Word, …). Each part has its own `items`. Sort by `order` ascending (do not rely on array position alone).

```json
{
  "pack_id": "order-es",
  "type": "order",
  "language": "es",
  "revision": "2026-10-01T12:00:00.000Z",
  "data": [
    {
      "order": 1,
      "title": "Introductory Rites",
      "summary": "Gather in prayer and prepare to celebrate Mass.",
      "items": [
        {
          "order": 1,
          "title": "Sign of the Cross",
          "rubric": "Priest · all make the Sign of the Cross",
          "text": "In the name of the Father, and of the Son, and of the Holy Spirit.",
          "response": "Amen."
        },
        {
          "order": 2,
          "title": "Entrance",
          "rubric": "Stand · Entrance Antiphon or a hymn",
          "text": "The Entrance Antiphon of the day may be said, or a hymn may be sung."
        },
        {
          "order": 3,
          "title": "Announcements",
          "rubric": "Announcements may be made"
        }
      ]
    },
    {
      "order": 2,
      "title": "Liturgy of the Word",
      "summary": "Listen to God’s word and join in prayer.",
      "items": []
    }
  ]
}
```

**Envelope**

| Field | Required | Notes |
| :--- | :---: | :--- |
| `pack_id` | yes | e.g. `order-es` |
| `type` | yes | Always `order` |
| `language` | yes | ISO-ish code (`es`, `efi`, …). Same as catalog / pack_id suffix |
| `revision` | yes | UTC ISO-8601 after first revise; stored locally (Order packs are not synced) |
| `data` | yes | Major parts of the Mass (array) |

**`data[]` (parts)**

| Field | Required | Notes |
| :--- | :---: | :--- |
| `order` | yes | 1-based sort key among parts |
| `title` | yes | Section heading (e.g. Introductory Rites) |
| `summary` | no | Short blurb under the title |
| `items` | yes | Liturgical items in this part (array; may be empty) |

**`data[].items[]`**

| Field | Required | Notes |
| :--- | :---: | :--- |
| `order` | yes | 1-based sort key within the part |
| `title` | yes | Item heading (e.g. Sign of the Cross) |
| `rubric` | no | Stage direction / who speaks / posture |
| `text` | no | Spoken or sung words. Omit when rubric-only |
| `response` | no | People’s reply when distinct from `text` |

Rules for editors / the API:

- Render by `order`, then fall back to array index if `order` ties.
- Newlines inside `text` / `response` / `rubric` are significant.
- English and Latin may appear in the catalog for re-install, but the app already ships them; other languages rely entirely on this download body.
- Order packs use `mode: "download"` only — never the Sync route.

### Rosary download body

`GET /v1/packs/rosary-{lang}/download`

Language belongs on the **envelope** only (`language: "es"`). The catalog row carries the label.

`data` is an object with `prayers` (fixed keys) and `mysteries` (the four sets). Sort mystery sets and titles by `order` ascending. The guided UI builds the traditional 81-step sequence from this pack (opening, five decades, closing).

```json
{
  "pack_id": "rosary-es",
  "type": "rosary",
  "language": "es",
  "revision": "2026-10-01T12:00:00.000Z",
  "data": {
    "prayers": {
      "sign": "En el nombre del Padre…",
      "creed": "Creo en Dios…",
      "our_father": "Padre nuestro…",
      "hail_mary": "Dios te salve, María…",
      "glory_be": "Gloria al Padre…",
      "fatima": "Oh Jesús mío…",
      "hail_holy_queen": "Dios te salve, Reina…",
      "closing": "Oh Dios, cuyo Hijo unigénito…"
    },
    "mysteries": [
      {
        "order": 1,
        "id": "joyful",
        "title": "Joyful",
        "days": "Monday & Saturday",
        "titles": [
          { "order": 1, "title": "La Anunciación" },
          { "order": 2, "title": "La Visitación" },
          { "order": 3, "title": "El Nacimiento de Jesús" },
          { "order": 4, "title": "La Presentación en el Templo" },
          { "order": 5, "title": "El Niño Jesús perdido y hallado en el Templo" }
        ]
      }
    ]
  }
}
```

**Envelope** — same as Order (`pack_id`, `type`, `language`, `revision`, `data`).

**`data.prayers`**

| Field | Required | Notes |
| :--- | :---: | :--- |
| `sign` | yes | Sign of the Cross |
| `creed` | yes | Apostles’ Creed |
| `our_father` | yes | Our Father |
| `hail_mary` | yes | Hail Mary |
| `glory_be` | yes | Glory Be |
| `fatima` | yes | Fatima Prayer (optional in devotion; still shipped) |
| `hail_holy_queen` | yes | Hail, Holy Queen |
| `closing` | yes | Concluding prayer after the decades |

**`data.mysteries[]`**

| Field | Required | Notes |
| :--- | :---: | :--- |
| `order` | yes | 1-based sort key among sets |
| `id` | no | Stable id; client falls back to a slug of `title` (`joyful`, `luminous`, …) |
| `title` | yes | Chip label (Joyful, Luminous, Sorrowful, Glorious) |
| `days` | no | Suggested days (e.g. Monday & Saturday) |
| `titles` | yes | Five mystery titles for that set |

**`data.mysteries[].titles[]`**

| Field | Required | Notes |
| :--- | :---: | :--- |
| `order` | yes | 1-based sort key within the set |
| `title` | yes | Mystery name announced before each decade |

Rosary packs use `mode: "download"` only — never the Sync route.

### Litanies download body

`GET /v1/packs/litanies-{lang}/download`

Language belongs on the **envelope** only (`language: "es"`). The catalog row carries the label.

`data` is the list of litanies. Sort by `order` ascending. Each litany has `lines` (call-and-response). A line may omit `response` for a full-width call-only row.

```json
{
  "pack_id": "litanies-es",
  "type": "litanies",
  "language": "es",
  "revision": "2026-10-01T12:00:00.000Z",
  "data": [
    {
      "order": 1,
      "id": "saints",
      "title": "Litany of the Saints",
      "summary": "For the Church and all people · traditional form",
      "category": "Traditional",
      "tags": ["traditional", "personal devotion"],
      "lines": [
        { "order": 1, "call": "Lord,", "response": "have mercy on us." },
        { "order": 2, "call": "Christ, hear us." },
        { "order": 3, "call": "Holy Mary,", "response": "pray for us." }
      ]
    }
  ]
}
```

**Envelope** — same as Order (`pack_id`, `type`, `language`, `revision`, `data`).

**`data[]` (litanies)**

| Field | Required | Notes |
| :--- | :---: | :--- |
| `order` | yes | 1-based sort key among litanies |
| `id` | no | Stable id; client falls back to a slug of `title` |
| `title` | yes | List and detail heading |
| `summary` | no | Subtitle under the title |
| `category` | no | Grouping label (e.g. Traditional) |
| `tags` | no | String array for detail chrome |
| `lines` | yes | Call/response rows (may be empty) |

**`data[].lines[]`**

| Field | Required | Notes |
| :--- | :---: | :--- |
| `order` | yes | 1-based sort key within the litany |
| `call` | yes | Left / invocation text |
| `response` | no | Right / people’s reply. Omit for call-only rows |

### Special Prayers download body

`GET /v1/packs/prayers-{lang}/download`

Language belongs on the **envelope** only. `data` is the list of prayers. Sort by `order` ascending.

```json
{
  "pack_id": "prayers-es",
  "type": "prayers",
  "language": "es",
  "revision": "2026-10-01T12:00:00.000Z",
  "data": [
    {
      "order": 1,
      "id": "memorare",
      "title": "Memorare",
      "summary": "Daily life · Traditional Marian prayer",
      "category": "Daily life",
      "tags": ["marian", "traditional"],
      "text": "Remember, O most gracious Virgin Mary…"
    }
  ]
}
```

**`data[]` (prayers)**

| Field | Required | Notes |
| :--- | :---: | :--- |
| `order` | yes | 1-based sort key among prayers |
| `id` | no | Stable id; client falls back to a slug of `title` |
| `title` | yes | List and detail heading |
| `summary` | no | Subtitle under the title in the list |
| `category` | no | Filter / detail label (e.g. Before meals) |
| `tags` | no | String array for detail chrome |
| `text` | yes | Full prayer body. Newlines are significant |

### Stations of the Cross download body

`GET /v1/packs/stations-{lang}/download`

Language belongs on the **envelope** only (`language: "es"`). The catalog row carries the label.

`data` is the list of stations, traditionally fourteen. Sort by `order` ascending. The client shows a bundled illustration for orders 1–14; do not send image URLs.

```json
{
  "pack_id": "stations-es",
  "type": "stations",
  "language": "es",
  "revision": "2026-10-01T12:00:00.000Z",
  "data": [
    {
      "order": 1,
      "id": "condemned",
      "title": "Jesús es condenado a muerte",
      "reference": "Lucas 23:24–25",
      "meditation": "Jesús permanece ante un juicio marcado por el miedo.",
      "prayer": "Señor Jesús, camina con nosotros en el amor. Amén."
    }
  ]
}
```

**Envelope** — same as Order (`pack_id`, `type`, `language`, `revision`, `data`).

**`data[]` (stations)**

| Field | Required | Notes |
| :--- | :---: | :--- |
| `order` | yes | 1-based sort key. Orders 1–14 match the bundled illustrations |
| `id` | no | Stable id; client falls back to a slug of `title` |
| `title` | yes | List and detail heading |
| `reference` | no | Scripture citation shown under the title. A reference, not verse text |
| `meditation` | yes | Original reflection. The client labels it as not a scripture quotation |
| `prayer` | yes | Closing prayer for that station. Newlines are significant |

Litanies, prayers, and stations packs use `mode: "download"` only — never the Sync route.


| Status | Meaning |
| :---: | :--- |
| 200 | Body installed on device; store `revision` |
| 401 / 403 | Client prompts sign-in |
| 404 | Pack unknown or body not shipped yet |

Sync does **not** replace this route for first install. A failed download is fixed by tapping Download again.

Payload is JSON. Prefer transparent HTTP gzip (`Content-Encoding: gzip`); OkHttp and URLSession decompress automatically — no zip library required.

---

## 3. Sync (updates only — hymns + daily readings)

### `GET /v1/packs/{pack_id}/sync`

Auth: **required** (signed-in Account).

Used by the Sync button and Wi‑Fi background job for **already installed** hymn and readings packs when the catalog `revision` is newer than the stored one.

**Do not call `/download` for updates.** Sync must not reload the whole pack.

**Path**

| Param | Example |
| :--- | :--- |
| `pack_id` | `hymns-en` |

**Query**

| Param | Required | Example | Meaning |
| :--- | :---: | :--- | :--- |
| `since` | **yes** | prior catalog `revision` (UTC ISO-8601) | Client’s last stored revision for this pack |

Omitting `since` returns `400` with `since_required` — use `/download` for a full install.

### How hymn sync chooses rows

1. Resolve the pack to one language collection (for example every hymn with `language = en` for `hymns-en`).
2. If `since` **equals** the catalog `revision`, return empty `data` (already up to date; no hymn rows loaded).
3. Otherwise parse `since` as a UTC ISO-8601 time and return only rows in that collection with **`updated_at` greater than `since`** — newly added, edited, soft-deleted, or licence tombstones. Unchanged hymns are omitted so the client does not re-download them.
4. Store the response `revision` as the next `since`.

### Hymns response

Same envelope as download (`pack_id`, `type`, `language`, `revision`, `data`), but `data` is **only** those `updated_at` deltas (tombstones use `deleted_at`).

Empty `data` when `since` already matches the catalog `revision` means “still current.”

### Readings response

```json
{
  "pack_id": "readings-rsvce",
  "type": "readings",
  "language": "en",
  "revision": "2026-10-18T14:02:11.000Z",
  "metadata": {
    "display_window": "week"
  },
  "data": [
    {
      "book": "Isa",
      "chapter": 7,
      "verse": 14,
      "part": null,
      "text": "…",
      "date": "2026-12-20",
      "updated_at": "2026-10-19T12:00:00Z",
      "deleted_at": null
    }
  ]
}
```

Translation key for local verse storage = `pack_id` without the `readings-` prefix (`rsvce`). Verse text only for dates inside `metadata.display_window` (fallback: catalog `metadata` for that pack).


| Status | Meaning |
| :---: | :--- |
| 200 | Apply delta; store `revision` |
| 400 | `since_required` / `invalid_since` / `use_download` |
| 401 / 403 | Show “Sign in to update hymns” (or readings) |
| 404 | Pack unknown |

---

## 4. Bookmarks

### `PUT /v1/bookmarks`

Auth: **required**. Merge local saved hymns, prayers, and litanies after sign-in, including removals. The device keeps the 50 newest saved items and drops the oldest. A dropped or removed item is sent with `deletedAt`, so the account does not hand it back as saved.

**Body**

`type` is a slug: `hymns`, `prayers` (special prayers), or `litanies`. `id` is that item's id. `createdAt` and `deletedAt` are milliseconds since epoch. `deletedAt` is `null` while the item is saved, or the client time when it was removed. The account keeps the row either way, so another device can drop it.

```json
[
  {
    "type": "hymns",
    "id": "uuid",
    "titleSnapshot": "Test hymn one",
    "createdAt": 1729000000000,
    "deletedAt": null
  },
  {
    "type": "prayers",
    "id": "uuid",
    "titleSnapshot": "Test prayer one",
    "createdAt": 1729000000000,
    "deletedAt": 1729000005000
  },
  {
    "type": "litanies",
    "id": "uuid",
    "titleSnapshot": "Test litany one",
    "createdAt": 1729000000000,
    "deletedAt": null
  }
]
```

### `GET /v1/bookmarks`

Auth: **required**. List envelope: `{ "data": [ …same bookmark rows… ], "page", "pageSize", "total" }`. Client merges by `type` and `id`. A row with `deletedAt` set is removed on the device when that time is not older than the local save. A saved row the device does not have is inserted. Other local saves stay.

`PUT` returns the same list envelope after merge.

---

## 5. Auth (Better Auth)

See **[`api-mobile-auth.md`](./api-mobile-auth.md)** for full routes, the https → `perfectliturgy://auth` bridge, Neon trusted domains, OAuth, magic link, and Apple (self-hosted) requirements.

Summary: `AUTH_BASE_URL` defaults to production (`https://api.perfectliturgy.com`); override with ngrok for dev. Paths are `/api/auth/...`. Neon Auth URL stays server-side. Mobile deep link is `perfectliturgy://auth`.

---

## Client call map

| User action | Request |
| :--- | :--- |
| Open Downloads / refresh list | `GET /v1/packs` (no auth) |
| First get English / Efik Hymns | `GET /v1/packs/hymns-en/download` (auth) |
| Download Order of Mass Spanish | `GET /v1/packs/order-es/download` |
| First get readings / Rosary / Order | `GET /v1/packs/{id}/download` (auth) |
| Sync button / Wi‑Fi | When online: for each installed hymn + readings pack — full `GET …/download` if this device has no stored revision, else `GET …/sync?since={storedRevision}`; when signed in also `PUT` then `GET /v1/bookmarks`. When offline: queue and run later |
| Remove any pack | Local only; next Sync skips it; user may Download again later |
| Sign in → merge bookmarks | `PUT` then `GET /v1/bookmarks` (auth) |

---

## Modes summary

| `mode` | Types | Install from Downloads | Sync button / background |
| :--- | :--- | :--- | :--- |
| `live` | `hymns`, `readings` | `GET …/download` (full pull; client stores `revision`) | Device has stored revision → `GET …/sync?since=`; else full `/download` again |
| `download` | `order`, `rosary`, `litanies`, `stations`, `prayers`, `calendar` | `GET …/download` | Never |
