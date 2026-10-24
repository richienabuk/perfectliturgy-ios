# PerfectLiturgy

A Catholic platform for Africa that helps people find Mass, take part in Mass, and serve at Mass.

## Places

**Parish**:
The administrative Catholic community under a parish priest; it groups one or more Churches.
_Avoid_: Church (when meaning the community)

**Church**:
A physical place of worship with its own address and Services; either a parish's main church or an Outstation.
_Avoid_: Parish (when meaning the building), location, venue

**Outstation**:
A Church belonging to a Parish other than its main church, usually in a nearby village.
_Avoid_: Chapel, mission station, sub-parish

## Schedules

**Service**:
A recurring scheduled liturgical celebration at a Church: a Mass, Confession, Adoration or Devotion.
_Avoid_: Mass (as the umbrella term), event, programme

**Mass times**:
The public-facing name for a Church's weekly Services schedule.
_Avoid_: Mass schedule (in public copy)

**Special schedule**:
A dated set of Services for a season such as Christmas, Ash Wednesday or Holy Week/Easter, which replaces the normal weekly Mass times for those days.
_Avoid_: Holiday schedule, seasonal timetable

**Special day**:
A named liturgical day (Christmas, Ash Wednesday, Immaculate Conception, Corpus Christi) that an Admin has added and that Churches can attach a Special schedule to.
_Avoid_: Holiday, feast template

**Hub**:
A Mass Times site page for a place (country, state/region/county, or city/town) that lists its Churches.
_Avoid_: Category page, landing page (reserved for the Landing site)

## Surfaces

**Mass Times site**:
The public English-language web directory of Churches and their Services.
_Avoid_: Web app, portal

**Landing site**:
The single page at perfectliturgy.com that presents Mass Times and the PerfectLiturgy mobile app, each with its links, and nothing else.
_Avoid_: Homepage (ambiguous with the Mass Times site's home)

**Product**:
An independently deployed and independently growing part of PerfectLiturgy, each on its own subdomain (Landing site, Mass Times site, Choir site, and the mobile apps).
_Avoid_: Module, section, feature

**Choir site**:
The signed-in web Product at choir.perfectliturgy.com where choir directors manage libraries and Mass plans; not indexed by search engines.
_Avoid_: Choir dashboard, choir portal

## Liturgy content

**Hymn**:
A single song in exactly one language, with a number in that language's hymn catalogue (for example hymn 42 in Efik); never a translation or version of another Hymn. The same number can exist in different languages. Editors may merge hymns from more than one printed source into one language catalogue; the app shows one name per language (for example **English Hymns**, **Efik Hymns**), not separate denominational books. The first **English Hymns** import ships inside the mobile app binary and works without sign-in; **Latin** liturgy and prayer essentials also ship with the app; **API sync** for hymn updates to English Hymns requires a signed-in Account (or a newer store build with a refreshed bundle).
_Avoid_: Hymn version, song (when meaning a Hymn), translation

**Content pack**:
A downloadable unit of liturgy content in the mobile apps (hymns per language, readings per Bible translation, Order of Mass per language, Stations per language, or a country liturgical calendar). Each pack syncs on its own; the user installs only what they need.
_Avoid_: Language bundle, content module

**Order of Mass** (mobile apps):
The fixed texts of the Mass in one language, edited and uploaded by Content editors, delivered as its own content pack and read offline in the app. Not the same as the projection app's parish-editable templates (see PRD §7.5).
_Avoid_: Mass template (reserved for projection)

**Hymn relationship**:
A link between two Hymns that exist separately, such as one being a counterpart in another language, or sharing a composer.
_Avoid_: Translation link, variant

**Content editor**:
An Account assigned by an Admin to enter and check readings and hymns for specific languages.
_Avoid_: Moderator (reserved for Parish changes)

**Licence status**:
The recorded rights position of a Hymn or Bible translation, with follow-up details the Admin tracks until permission is settled.
_Avoid_: Copyright flag

## Choirs

**Choir**:
A group of singers that belongs to exactly one Church and is managed on the Choir site.
_Avoid_: Group, team

**Choir library**:
A Choir's private catalogue of songs, each recording where the song is kept; scans and audio are optional.
_Avoid_: Songbook, folder

## Accounts

**Account**:
A person's single PerfectLiturgy identity, created once and usable across every Product.
_Avoid_: User record, profile, login

**Admin**:
The Account role that appoints and removes Moderators and can do everything on the Mass Times site.
_Avoid_: Super admin, owner

**Moderator**:
An Account that an Admin has assigned to specific Parishes, to review and publish Mass Times site changes for those Parishes only; may be a priest, catechist, church officer or volunteer. Losing every Parish assignment leaves a plain Contributor.
_Avoid_: Parish admin, editor, secretary, area moderator

**Visitor**:
A person using the Mass Times site without signing in.
_Avoid_: Anonymous user, guest

**Contributor**:
Any signed-in Account that submits information about a Church or Parish for review.
_Avoid_: Visitor (when signed in), user

**Session**:
One signed-in device or browser of an Account, which the owner can list and revoke.
_Avoid_: Login, token
