# Permission Registry Companion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a Steam-ID permission registry, active-time service, staff roster, cage synchronization, export/import, and opt-in RCON adapter.

**Architecture:** A standalone Java 25 companion owns SQLite state and a loopback bearer-token API. Existing Lua performs server authorization and cage enforcement, querying the companion over localhost. Every mutation appends an audit event; automatic rules may only promote Recruit to Regular or flag a record.

**Tech Stack:** Java 25, Gradle, sqlite-jdbc, Javalin, JUnit 5, Project Zomboid B42 Lua APIs, SQLite.

## Global Constraints

- Key records by canonical Steam ID; never use PZ `accessLevel`.
- Do not trust client-reported time, permissions, or detections.
- `Suspended` synchronizes to `ParadiseDev.Cage`; Banned records are never deleted automatically.
- Bind to loopback and require a generated bearer token.
- RCON defaults off and accepts only enum-defined commands.
- Do not stage or edit the unrelated dirty console file.

---

## File structure

- `security-companion/build.gradle.kts` — Java dependencies and application entrypoint.
- `security-companion/src/main/java/com/jimsparadise/security/domain/*` — enums and immutable records.
- `security-companion/src/main/java/com/jimsparadise/security/persistence/*` — SQLite schema and repository.
- `security-companion/src/main/java/com/jimsparadise/security/activity/*` — server-observed active-time tracker.
- `security-companion/src/main/java/com/jimsparadise/security/api/*` — loopback HTTP API and auth filter.
- `security-companion/src/main/java/com/jimsparadise/security/export/*` — JSON/CSV migration I/O.
- `security-companion/src/main/java/com/jimsparadise/security/rcon/*` — opt-in allowlisted RCON adapter.
- `42.20/media/lua/server/Dev/ParadiseDev_Permissions.lua` — server authority/companion bridge.
- `42.20/media/lua/client/Dev/ParadiseDev_Permissions.lua` — staff-only paginated roster.
- `42.20/media/lua/server/Dev/ParadiseDev_Cage.lua` — corrected Steam-ID keying.
- `tests/lua/permissions_spec.lua` — Lua bridge behavior tests.

### Task 1: SQLite registry and audit history

**Files:**
- Create: `security-companion/settings.gradle.kts`
- Create: `security-companion/build.gradle.kts`
- Create: `security-companion/src/main/java/com/jimsparadise/security/domain/PermissionTier.java`
- Create: `security-companion/src/main/java/com/jimsparadise/security/domain/ModerationState.java`
- Create: `security-companion/src/main/java/com/jimsparadise/security/persistence/RegistryRepository.java`
- Create: `security-companion/src/main/java/com/jimsparadise/security/persistence/SqliteRegistryRepository.java`
- Test: `security-companion/src/test/java/com/jimsparadise/security/persistence/SqliteRegistryRepositoryTest.java`

**Interfaces:**
- Produces `upsertSeen(String steamId, String username, Instant seenAt)`, `setTier(...)`, `setState(...)`, `query(PlayerFilter, Page)`, and `appendAudit(AuditEvent)`.

- [ ] **Step 1: Write the failing tests**

```java
@Test void upsertDefaultsToRecruitAndAudits() {
  var r = repo.upsertSeen("76561198000000000", "Jim", now);
  assertEquals(PermissionTier.RECRUIT, r.tier());
  assertEquals(ModerationState.NORMAL, r.state());
  assertEquals(1, repo.auditFor(r.steamId()).size());
}
@Test void banSurvivesLaterUpsert() {
  repo.setState(id, ModerationState.BANNED, "staff", "test", now);
  assertEquals(ModerationState.BANNED, repo.upsertSeen(id, "newName", later).state());
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `./gradlew test --tests '*SqliteRegistryRepositoryTest'`

Expected: FAIL because the project and repository do not exist.

- [ ] **Step 3: Write the minimal implementation**

Create `player_record` with Steam ID primary key, latest username, tier, state, active seconds, first/last seen, and manual override; create append-only `audit_event` with a stable UUID. Validate Steam IDs using `^[0-9]{17}$`; make every mutation and its audit insert one transaction.

- [ ] **Step 4: Run tests to verify they pass**

Run: `./gradlew test --tests '*SqliteRegistryRepositoryTest'`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add security-companion
git commit -m "feat: add permission registry persistence"
```

### Task 2: Active time and automatic rules

**Files:**
- Create: `security-companion/src/main/java/com/jimsparadise/security/activity/ActivityTracker.java`
- Create: `security-companion/src/main/java/com/jimsparadise/security/rules/AutomaticRuleEngine.java`
- Test: `security-companion/src/test/java/com/jimsparadise/security/activity/ActivityTrackerTest.java`
- Test: `security-companion/src/test/java/com/jimsparadise/security/rules/AutomaticRuleEngineTest.java`

**Interfaces:**
- Produces `observe(String steamId, Instant at, boolean meaningful)` and `evaluate(String steamId, Instant at)`.

- [ ] **Step 1: Write failing tests**

```java
@Test void inactiveGapDoesNotAccumulateHours() {
  tracker.observe(id, start, true);
  tracker.observe(id, start.plusSeconds(120), true);
  tracker.observe(id, start.plusHours(2), false);
  assertEquals(120, repo.find(id).orElseThrow().lifetimeActiveSeconds());
}
@Test void promotionDoesNotOverrideManualChoice() {
  repo.setTier(id, PermissionTier.RECRUIT, "staff", "hold", true, now);
  tracker.credit(id, Duration.ofHours(50), now);
  rules.evaluate(id, now);
  assertEquals(PermissionTier.RECRUIT, repo.find(id).orElseThrow().tier());
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./gradlew test --tests '*ActivityTrackerTest' --tests '*AutomaticRuleEngineTest'`

Expected: FAIL because the classes do not exist.

- [ ] **Step 3: Write minimal implementation**

Credit only a configurable bounded delta between meaningful server observations. Store rolling activity intervals for 7/30-day filters. Implement only Recruit-to-Regular and Normal-to-Flagged; both audit, both skip manual override, and neither can suspend, ban, demote, or grant VIP.

- [ ] **Step 4: Run tests to verify they pass**

Run: `./gradlew test --tests '*ActivityTrackerTest' --tests '*AutomaticRuleEngineTest'`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add security-companion
git commit -m "feat: add active-time permission rules"
```

### Task 3: Authenticated API, exports, and RCON

**Files:**
- Create: `security-companion/src/main/java/com/jimsparadise/security/api/CompanionServer.java`
- Create: `security-companion/src/main/java/com/jimsparadise/security/export/RegistryExporter.java`
- Create: `security-companion/src/main/java/com/jimsparadise/security/rcon/RconAdapter.java`
- Create: `security-companion/config.example.json`
- Test: `security-companion/src/test/java/com/jimsparadise/security/api/CompanionServerTest.java`
- Test: `security-companion/src/test/java/com/jimsparadise/security/export/RegistryExporterTest.java`
- Test: `security-companion/src/test/java/com/jimsparadise/security/rcon/RconAdapterTest.java`

**Interfaces:**
- Produces `GET /v1/players`, tier/state mutation endpoints, `POST /v1/observations`, and timestamped JSON/CSV export/import.

- [ ] **Step 1: Write failing tests**

```java
@Test void rejectsUnauthenticatedRequests() {
  assertEquals(401, request("GET", "/v1/players", null).status());
}
@Test void rejectsNonLoopbackRequests() {
  assertEquals(403, server.handle(remote("10.0.0.2"), validRequest()).status());
}
@Test void rejectsRawRconCommand() {
  assertThrows(IllegalArgumentException.class, () -> rcon.executeRaw("save"));
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./gradlew test --tests '*CompanionServerTest' --tests '*RegistryExporterTest' --tests '*RconAdapterTest'`

Expected: FAIL because these classes do not exist.

- [ ] **Step 3: Write minimal implementation**

Bind Javalin only to `127.0.0.1`, authenticate with a constant-time bearer comparison, cap pages at 100, and return no stack traces. Export records and audit UUIDs to JSON/CSV; import idempotently by Steam ID and event UUID. Default RCON disabled; accept only `KICK_USER`, `BAN_STEAM_ID`, and `UNBAN_STEAM_ID` enum actions, generate command text from validated IDs, and audit every attempt/result.

- [ ] **Step 4: Run tests to verify they pass**

Run: `./gradlew test --tests '*CompanionServerTest' --tests '*RegistryExporterTest' --tests '*RconAdapterTest'`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add security-companion
git commit -m "feat: add secure registry API and rcon adapter"
```

### Task 4: Lua authority bridge, roster, and cage synchronization

**Files:**
- Modify: `42.20/media/lua/server/Dev/ParadiseDev_Cage.lua`
- Create: `42.20/media/lua/server/Dev/ParadiseDev_Permissions.lua`
- Create: `42.20/media/lua/client/Dev/ParadiseDev_Permissions.lua`
- Test: `tests/lua/permissions_spec.lua`

**Interfaces:**
- Produces `ParadiseDev.Permissions.onClientCommand(module, command, pl, args)` and `syncSuspension(steamId, state)`.

- [ ] **Step 1: Write failing Lua tests**

```lua
it("uses Steam ID as the cage key in Steam mode", function()
  stub(getSteamModeActive).returns(true)
  assert.equals("76561198000000000", ParadiseDev.Cage.getKey(player))
end)
it("rejects a non-admin tier mutation", function()
  ParadiseDev.Permissions.onClientCommand("ParadiseDevPermissions", "setTier", player, args)
  assert.is_nil(fakeBridge.lastMutation)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua tests/lua/permissions_spec.lua`

Expected: FAIL because the permission module is absent and Steam mode currently keys caging by username.

- [ ] **Step 3: Write minimal implementation**

Make `Cage.getKey` return Steam ID when Steam mode is active, with username fallback only when no Steam ID exists. Server-check `ParadiseDev.isAdm(pl)` for every roster and mutation command, resolve online identities server-side, and require a nonempty manual-change reason. Send server-filtered, paginated rows to the client. Map Suspended to `Cage.set(..., true)`; release only when state changes away from Suspended.

- [ ] **Step 4: Run tests to verify they pass**

Run: `lua tests/lua/permissions_spec.lua`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add 42.20/media/lua/server/Dev/ParadiseDev_Cage.lua 42.20/media/lua/server/Dev/ParadiseDev_Permissions.lua 42.20/media/lua/client/Dev/ParadiseDev_Permissions.lua tests/lua/permissions_spec.lua
git commit -m "feat: add permission roster and cage bridge"
```

### Task 5: Document operations

**Files:**
- Modify: `42.20/README.md`

- [ ] **Step 1: Write a deployment checklist**

Document Java companion startup, local token generation, loopback-only binding, SQLite backup/export/import, configuration of automatic thresholds, dry-run RCON test, and rollback. Exclude production server addresses and all credentials.

- [ ] **Step 2: Verify commands**

Run: `./gradlew test`

Expected: PASS.

- [ ] **Step 3: Commit**

```powershell
git add 42.20/README.md
git commit -m "docs: add permission registry operations guide"
```

