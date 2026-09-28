# Paradise Panel Lifecycle Design

## Goal

Give every user-facing panel under `42.20/media/lua/client/Panels` one consistent, externally callable lifecycle API while preserving the panel-specific parameters and side effects that make each UI work.

Every registered module exposes:

```lua
Module.OpenPanel(...)
Module.ClosePanel()
Module.TogglePanel(...)
```

The panel's own close control must call the same `ClosePanel()` function. Existing panel-specific lifecycle names are removed, and all in-repository callers are migrated to the standardized names.

## Scope

The registry covers the top-level and independently managed child UIs implemented in the `Panels` tree, regardless of whether they derive from `ISCollapsableWindow`, `ISPanel`, or `ISPanelJoypad`.

Initial inventory:

- `ParadiseDev.DataCheck`
- `ParadiseDev.Panels.GlobalModData`
- `ParadiseDev.Panels.MediaSpawner`
- `ParadiseDev.Panels.ModActiveCheck`
- `ParadiseDev.Panels.PlaytimeCheck`
- `ParadiseDev.TraitSyncer`
- `ParadiseDev.ZedController`
- `ParadiseDev.Zones` (main panel)
- `ParadiseDev.Zones.Editor`
- `ParadiseDev.Zones.TestRemote`
- `ParadisePOI`
- `LuaResetTool`
- `WaveCasterPanel`
- `JimsRulesUI`
- separate ParadisePromo admin and player lifecycle modules, because the two panels cannot both use the same three names on the `ParadisePromo` table

Files in the directory that only patch a vanilla UI or contain no live panel, such as `ParadiseDev_AnimMonitor.lua` and the currently inactive Cage panel code, are not registry entries until they own an independently openable instance.

## Registry Contract

`ParadisePanels_table.lua` is the authoritative panel inventory. `ParadisePanels.table` is an ordered array so iteration is deterministic and duplicate keys can be detected.

Each entry uses this contract:

```lua
{
    key = "stableUniqueName",
    isAdmOnly = true,
    getModule = function()
        return SomeModule
    end,
    getInstance = function()
        return SomeOwner.instance
    end,
    setInstance = function(instance)
        SomeOwner.instance = instance
    end,
    create = function(...)
        -- Resolve default position and dimensions at open time.
        -- Construct and initialise the panel, preserving all arguments.
        return panel
    end,
    onOpen = function(panel, ...)
        -- Optional refresh, sync, focus, resize, or bring-to-top behavior.
    end,
    onClose = function(panel)
        -- Optional cleanup that must occur before removal.
    end,
}
```

`x`, `y`, `width`, and `height` live in the descriptor through `create` or geometry callbacks, not as values evaluated when the Lua file loads. This ensures current screen dimensions are used whenever a panel is opened. Simple panels can use a shared default creator; specialized panels retain a short custom creator or hook.

The registry stores functions and actual table references returned by `getModule`; it never evaluates a Lua module name from a string.

## Generated Lifecycle Behavior

`ParadisePanels_Main.lua` owns the reusable lifecycle implementation and installer.

### OpenPanel

`Module.OpenPanel(...)`:

1. Rejects the open when `isAdmOnly` is true and `ParadiseRestore.isAdm()` is false.
2. Reads the current instance through `getInstance()`.
3. If no instance exists, calls `create(...)`, stores its result, and adds it to the UI manager if the custom creator has not already done so.
4. Makes the instance visible, ensures it is in the UI manager, and brings it to the top when supported.
5. Runs `onOpen(instance, ...)` so existing refresh, request-sync, joypad focus, marker, always-on-top, and resizing behavior is retained.
6. Returns the instance, or `nil` when access or required parameters prevent creation.

All arguments are forwarded unchanged. Descriptor-specific creators decide which arguments are required and may supply the same defaults as the current implementation.

### ClosePanel

`Module.ClosePanel()`:

1. Returns safely when no instance exists.
2. Runs `onClose(instance)` for specialized cleanup.
3. Hides and removes the instance from the UI manager when those operations are available.
4. Clears the instance using `setInstance(nil)`.

Cleanup must preserve current behavior, including WaveCaster child-editor and marker cleanup, ZedController cursor/selection cleanup, Zone editor ownership cleanup, and JimsServerRules joypad-focus restoration.

`ClosePanel()` must be idempotent. Panel class `close`, `destroy`, close-button, and equivalent handlers delegate to `Module.ClosePanel()` rather than duplicating removal logic. The generated close path must not call the delegating instance method and recurse.

### TogglePanel

`Module.TogglePanel(...)` closes when an instance exists. Otherwise it forwards every argument to `Module.OpenPanel(...)` and returns that result.

## Module Naming and Migration

Lifecycle functions live on the most specific stable module or class table so names never collide. Examples:

```lua
ParadiseDev.Panels.MediaSpawner.OpenPanel()
ParadiseDev.Panels.MediaSpawner.ClosePanel()
ParadiseDev.Panels.MediaSpawner.TogglePanel()

ParadiseDev.Zones.Editor.OpenPanel(zoneId, parentWindow)
JimsRulesUI.OpenPanel(playerNumber, player, title, subtitle, rawRules, reviewOnly)
```

ParadisePromo receives distinct module tables, for example `ParadisePromo.AdminPanel` and `ParadisePromo.PlayerPanel`, each with the standard three functions.

All calls under `42.20/media/lua` are searched and migrated. Old lifecycle entry points such as `openPanel`, `openUI`, `openTestRemote`, `openMediaSpawner`, `openPlaytimeCheck`, `openAdminPanel`, `openPlayerPanel`, `show`, `panel`, `open`, and `close` are removed when they represent panel lifecycle. Unrelated domain functions with similar verbs are not changed.

Callback sites must preserve their existing argument order. Context-menu functions may pass the standardized function directly when the callback convention matches, or use a small closure when it does not.

## Load Order

`ParadisePanels_Main.lua` explicitly loads the registry definition. Because many panel modules are assigned later during client Lua loading, installation is deferred until the panel globals exist. The installer is safe to call repeatedly and marks installed entries, allowing a late-loaded or reloaded module to be attached without duplicating event callbacks.

The implementation will use an appropriate post-load/game event already available in Project Zomboid and expose `ParadisePanels.Install()` for Lua reload and console use. Missing modules produce a diagnostic and remain eligible for a later install attempt instead of crashing client startup.

## Admin Demotion

`ParadisePanels.CloseAdminPanels()` iterates `ParadisePanels.table`. For every entry where `isAdmOnly == true`, it resolves the module and calls its generated `ClosePanel()`.

`ParadisePanels.Demote.doDemote(pl)` sets the cached admin state to false and calls `ParadisePanels.CloseAdminPanels()`. Player-facing entries remain open.

The administrator check remains enforced in each admin entry's `OpenPanel(...)`, so console calls cannot reopen an admin UI after demotion.

## Error Handling

- A duplicate or missing registry key is reported during installation.
- A missing module is skipped without preventing other entries from installing.
- A creator that returns `nil` leaves the instance unset.
- Open, close, and toggle are safe when called repeatedly.
- Missing optional UI methods such as `bringToTop` do not cause errors.
- Required panel parameters retain their existing validation/default behavior inside the descriptor adapter.

## Verification

Automated Lua tests or a lightweight stub harness will cover the registry engine independently of the game runtime:

- generated functions attach to every resolvable module;
- open creates once and reuses the instance;
- parameters reach the creator and `onOpen` unchanged;
- close performs cleanup and clears the instance;
- toggle selects the correct path;
- admin-only open is denied for a non-admin;
- demotion closes only admin entries;
- repeated close and repeated installation are safe;
- missing modules do not block other registrations.

Static migration checks will confirm that removed lifecycle names have no remaining callers in `42.20/media/lua` and that every live panel close handler delegates to its standardized module function.

Runtime smoke testing in Project Zomboid should open, refocus, toggle, and close each panel; exercise parameterized panels; demote an admin with both admin and player panels open; and confirm specialized cleanup for WaveCaster, Zones, ZedController, and JimsServerRules.

## Non-Goals

- Redesigning panel visuals or domain behavior.
- Registering vanilla windows merely patched by this mod.
- Changing server commands or their payloads.
- Changing whether an existing panel is intended for administrators or players, except to record that existing policy explicitly in the registry.
