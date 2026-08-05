# Dev Zone Modules Design

## Goal

Port only the ParadiseZ zone API and selected zone handlers into a Dev-owned
folder without rewriting or duplicating Jim's B42 zone editor.

## Boundaries

- All newly ported ParadiseZ zone code lives under
  `42.20/media/lua/client/Dev/Zones/`.
- `client/Jim/PZZoneEngine/` and `client/Jim/PZZoneHarness/` remain unchanged.
  They are the B42 authority/cache and the existing editor UI.
- `ParadiseDev_ZonePanel.lua` is a Dev entry point that opens Jim's panel; it
  does not copy the panel, attach duplicate event listeners, or own a second
  copy of zone state.
- One feature handler file is created only when that feature is intentionally
  restored. Unused B41 features are not transferred merely because files exist
  in ParadiseZ.

## Module Layout

`ParadiseDev_ZoneQueries.lua` resolves a player object or username and reads
the server-published `PZZoneEngineClientBorder` cache. It provides the old
ParadiseZ queries (`isKosZone`, `isPveZone`, `isBlockedZone`, and each
feature-specific predicate) while applying B42's highest-priority zone rule.

`ParadiseDev_ZonePanel.lua` exposes a Dev-owned `openPanel()` entry point that
delegates to `PZZoneHarness.openUI()`. Jim's panel remains the only editor.

Each later restored gameplay rule has one file named for its zone type, for
example `ParadiseDev_Zone_NoFire.lua` or `ParadiseDev_Zone_PvP.lua`. Every
handler consumes the shared query API rather than duplicating rectangle,
priority, vehicle, or floor checks.

## Compatibility and Safety

The query API adds compatibility names to `ParadiseZ` while keeping its own
implementation under `ParadiseDev.Zones`. Unknown users, unavailable client
cache, and locations outside a zone return `false` from predicates. The client
cache is used only for UI/query compatibility; any future rule that changes
world state must be validated on the server.

## Initial Scope

The initial transfer creates the folder, shared query API, and panel facade.
It does not activate unused B41 effects such as radiation, minefields,
temperature, PvP damage overrides, or zone destruction restrictions.
