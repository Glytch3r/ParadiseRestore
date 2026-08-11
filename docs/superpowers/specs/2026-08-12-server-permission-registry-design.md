# Server Permission Registry Design

## Purpose

Add a server-owned, Steam-ID-keyed permission and moderation registry to
ParadiseRestore. It must preserve records through whitelist changes, bans,
world wipes, and server migrations; drive the existing Lua cage mechanism; and
give staff a roster that can be filtered by real server-observed play time.

The registry is not Project Zomboid's `accessLevel`. It is a mod-owned
permission tier and moderation state. Built-in access levels remain untouched.

## Scope and safety boundary

The system runs only under the server operator's control. The client is
untrusted: no client-reported play time, permissions, or detection result can
grant authority. The system evaluates only observations available to the
server, and enforcement is performed by server-side Lua or explicitly
allowlisted RCON commands.

The design does not claim to prevent arbitrary code injection into a player
client. It detects and responds to invalid or anomalous actions observable by
the server. Any Java in-process hook is experimental, server-only, and opt-in.

VIP entitlements are limited to non-gameplay benefits, such as cosmetics or
recognition, to avoid monetising gameplay advantages.

## Domain model

Each record is keyed by the canonical Steam ID string and contains:

- most recently observed username;
- permission tier: `Recruit`, `Regular`, or `VIP`;
- moderation state: `Normal`, `Flagged`, `Suspended`, or `Banned`;
- lifetime active seconds and rolling active seconds for 7- and 30-day
  windows;
- first seen, last seen, last active, and record-update timestamps;
- current flag/review reason when applicable; and
- append-only audit events with actor, source, old/new values, reason, and
  timestamp.

`Suspended` maps to the existing `ParadiseDev.Cage` status. `Banned` remains a
registry record after a native ban, whitelist removal, or world reset. Records
are never removed by an automatic process; staff can only mark them archived.

## Components

### Lua server bridge and staff UI

Lua remains the supported Project Zomboid mod integration layer. It exposes
server-authorized commands to list filtered records, request a manual change,
and synchronize the `Suspended` state with `ParadiseDev.Cage`. Client UI is
display-only for roster data and sends requests; the server independently
checks staff authority before applying a change.

The roster supports exact and range filters for Steam ID/name, tier,
moderation state, lifetime active hours, active hours in a selected 7- or
30-day window, last seen, first seen, flag reason, and review status. Results
are paginated and sorted server-side.

### Java companion service

A standalone Java service runs beside the dedicated server. It owns a local
SQLite database and exposes a loopback-only HTTP API with a generated bearer
token. It provides record queries and mutations to the Lua bridge, receives
server observation events, calculates active time, writes timestamped JSON and
CSV exports, and imports them idempotently during a migration.

The companion authenticates outbound RCON with configuration supplied at
deployment. RCON is off by default. If enabled, it accepts only a static
allowlist of approved native actions. Each attempted command, success, failure,
and correlation ID becomes an audit event. FTP is deployment transport only;
the service does not require FTP credentials or access.

### Experimental Java server hook

The optional Java agent attaches only to the dedicated server process at
startup. It emits version-tagged, minimal server observations such as connect,
disconnect, action rejection, and safe rate-limit counters to the companion.
It must fail open: an incompatible PZ build disables the hook and logs a clear
message, leaving Lua enforcement and the companion operating. It does not patch
or alter game decisions, scan clients, or accept commands from clients.

## Active-time and automation rules

The companion starts an activity session at a server-observed successful
connection. It adds time only while server observations show meaningful player
activity within a configurable recent-activity interval. Extended inactivity,
disconnects, or unavailable observations stop accumulation. The exact activity
signals and thresholds are configuration values and all calculated intervals
are audit events.

Automatic rules can perform only two actions:

- promote `Recruit` to `Regular` after configured active hours; and
- set `Flagged` after a configured, evidence-backed server anomaly threshold.

They never suspend, ban, demote, or grant VIP. Staff can override any tier or
state, but must supply a reason. A manual action always wins over a conflicting
automatic rule until staff clears the override.

## Data flow

1. The server observes a connection or activity event and sends it to the
   companion.
2. The companion upserts the Steam-ID record, computes active time, evaluates
   the limited automatic rules, and appends audit events.
3. The Lua bridge queries filtered roster data and renders it to authorized
   staff.
4. A staff change is server-authorized, persisted by the companion, recorded
   in audit history, and applied through Lua. A `Suspended` record is synced to
   `ParadiseDev.Cage`.
5. When an approved RCON action is configured, the companion executes it and
   records the result without deleting the registry record.

## Failure handling

- A companion outage does not remove an existing cage or native ban. Lua logs
  the outage and rejects new registry mutations rather than guessing.
- The companion queues export writes locally and resumes after a transient I/O
  failure; failed exports are visible in service health.
- Invalid, unauthenticated, or non-loopback API calls are rejected and logged
  without exposing player data.
- RCON timeouts or failures do not change registry state automatically; staff
  see the failed execution and can retry deliberately.
- The Java hook is disabled for an unsupported PZ build and cannot prevent the
  dedicated server from starting.

## Delivery phases

1. Establish the Java companion project, SQLite schema, loopback API,
   configuration validation, audit log, and export/import tooling.
2. Add Lua server bridge and staff roster, then replace/extend caging state
   synchronization using the registry.
3. Add activity collection, filters, Recruit-to-Regular automation, and
   evidence-backed Flagged automation.
4. Add opt-in RCON action adapter with command allowlist and deployment guide.
5. Prototype the optional in-process Java hook against one pinned B42 build,
   with compatibility checks and no enforcement authority.

## Verification

Automated tests cover migration idempotency, audit append-only behavior,
authorization, pagination/filter correctness, active-time accumulation and
AFK pauses, manual-over-automatic precedence, cage synchronization, RCON
allowlist rejection, and hook compatibility failure. An isolated test server
validates reconnects, wipe/migration import, suspension persistence, and staff
roster output before the production server is touched.
