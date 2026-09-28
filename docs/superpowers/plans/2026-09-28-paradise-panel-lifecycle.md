# Paradise Panel Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every live panel-specific open/close entry point in the ParadiseRestore `Panels` tree with registry-generated `OpenPanel(...)`, `ClosePanel()`, and `TogglePanel(...)` functions, including automatic closure of admin-only panels on demotion.

**Architecture:** `ParadisePanels_table.lua` supplies ordered descriptors with lazy module resolution, instance accessors, creators, and lifecycle hooks. `ParadisePanels_Main.lua` validates descriptors and installs the common API after modules load; panel files retain only their construction and specialized hook logic, while their close controls delegate to the generated API.

**Tech Stack:** Project Zomboid Build 42 client Lua, Lua 5.4-compatible test runner, stubbed PZ UI globals, PowerShell/`rg` static migration checks.

**Spec:** `docs/superpowers/specs/2026-09-28-paradise-panel-lifecycle-design.md`

## Global Constraints

- Public lifecycle names are exactly `OpenPanel(...)`, `ClosePanel()`, and `TogglePanel(...)`.
- Preserve every existing panel parameter, default, refresh/sync call, focus behavior, and cleanup side effect.
- All lifecycle callers under `42.20/media/lua` must use the new API; remove old lifecycle entry points rather than keep compatibility aliases.
- Include independently managed `ISCollapsableWindow`, `ISPanel`, and `ISPanelJoypad` panels; exclude vanilla UI patches and code with no live openable instance.
- Store `isAdmOnly` explicitly for every registry entry and deny admin-only opens when `ParadiseRestore.isAdm()` is false.
- Do not evaluate module names from strings; resolve actual Lua tables lazily.
- Preserve the user's unrelated dirty-worktree changes and stage only task-owned hunks/files.

## Review Focus

- Reopening an existing parameterized panel must not reconstruct it, but its `onOpen(instance, ...)` hook must still receive the new arguments when refresh behavior needs them; Task 1 tests this.
- A close hook that performs specialized cleanup must run once without recursively re-entering an instance `close`/`destroy` method; Task 1 tests this.
- Two ParadisePromo panels sharing one domain table must receive independent modules and instance fields; Task 2 tests both descriptors together.
- A descriptor whose module is unavailable during the first install must install successfully on a later retry; Task 1 tests late resolution.
- Demotion with a mixture of open admin and player panels must close only admin entries and tolerate missing modules/instances; Task 4 tests this.

---

### Task 1: Registry engine and lifecycle contract

**Files:**
- Modify: `42.20/media/lua/client/Panels/ParadisePanels_Main.lua`
- Create: `tests/client/Panels/test_ParadisePanels_Main.lua`

**Interfaces:**
- Consumes: `ParadisePanels.table`, with entries containing `key`, `isAdmOnly`, `getModule()`, `getInstance()`, `setInstance(instance)`, `create(...)`, optional `onOpen(instance, ...)`, and optional `onClose(instance)`.
- Produces: `ParadisePanels.Install() -> integer`, `ParadisePanels.InstallEntry(entry) -> boolean`, `ParadisePanels.Open(entry, ...) -> instance|nil`, `ParadisePanels.Close(entry)`, `ParadisePanels.Toggle(entry, ...) -> instance|nil`, and module methods `OpenPanel`, `ClosePanel`, `TogglePanel`.

- [ ] **Step 1: Write failing registry-engine tests**

Create a stub module, descriptor, UI instance, `ParadiseRestore.isAdm`, and `Events.OnGameStart`. Assert that installation attaches all three public methods; open forwards varargs, creates once, reuses the instance, and runs `onOpen` on both first and repeat open; close runs `onClose` once, hides/removes, and clears; toggle opens then closes; repeated close/install are safe; non-admin access is denied; duplicate/missing keys are rejected; and a missing module can resolve on a later `Install()` call.

- [ ] **Step 2: Run the test to verify RED**

Run: `lua tests/client/Panels/test_ParadisePanels_Main.lua`

Expected: FAIL because the installer and generated lifecycle methods do not exist.

- [ ] **Step 3: Implement the registry engine**

Implement the produced interfaces in `ParadisePanels_Main.lua`. Generated methods close over their descriptor, optional UI methods are guarded, creators returning `nil` do not set an instance, and installation is idempotent but retries unresolved modules. Register `ParadisePanels.Install` on `Events.OnGameStart` without duplicating the callback after Lua reload.

- [ ] **Step 4: Run the registry-engine test to verify GREEN**

Run: `lua tests/client/Panels/test_ParadisePanels_Main.lua`

Expected: PASS with all lifecycle assertions executed and exit code 0.

- [ ] **Step 5: Commit only the registry engine and its test**

```powershell
git add -- 42.20/media/lua/client/Panels/ParadisePanels_Main.lua tests/client/Panels/test_ParadisePanels_Main.lua
git commit -m "feat: add registry-driven panel lifecycle"
```

### Task 2: Author the complete panel descriptor table

**Files:**
- Modify: `42.20/media/lua/client/Panels/ParadisePanels_table.lua`
- Modify: `tests/client/Panels/test_ParadisePanels_Main.lua`

**Interfaces:**
- Consumes: Task 1 descriptor contract and lifecycle engine.
- Produces: one deterministic descriptor per scoped UI, including separate `ParadisePromo.AdminPanel` and `ParadisePromo.PlayerPanel` modules.

- [ ] **Step 1: Add failing descriptor-shape and inventory tests**

Assert unique keys and required fields for these entries: DataCheck, GlobalModData, MediaSpawner, ModActiveCheck, PlaytimeCheck, TraitSyncer, ZedController, Zones main, Zones Editor, Zones TestRemote, POI, LuaResetTool, WaveCaster, JimsRulesUI, ParadisePromo Admin, and ParadisePromo Player. Assert the two Promo entries resolve different modules and instance accessors. Assert expected player-facing entries have `isAdmOnly == false` and every remaining admin tool has `isAdmOnly == true`.

- [ ] **Step 2: Run the descriptor tests to verify RED**

Run: `lua tests/client/Panels/test_ParadisePanels_Main.lua`

Expected: FAIL because `ParadisePanels.table` is empty.

- [ ] **Step 3: Populate `ParadisePanels.table`**

Add the 16 descriptors with lazy `getModule` functions, correct existing instance fields, runtime geometry, creators that forward required parameters, and hooks matching current behavior. Create `ParadisePromo.AdminPanel` and `ParadisePromo.PlayerPanel` namespace tables in a location that cannot be overwritten by class definitions. Keep panel construction out of `ParadisePanels_Main.lua`.

- [ ] **Step 4: Run the descriptor and engine tests to verify GREEN**

Run: `lua tests/client/Panels/test_ParadisePanels_Main.lua`

Expected: PASS with 16 unique descriptors and both Promo lifecycles independent.

- [ ] **Step 5: Commit the descriptor table and expanded test**

```powershell
git add -- 42.20/media/lua/client/Panels/ParadisePanels_table.lua tests/client/Panels/test_ParadisePanels_Main.lua
git commit -m "feat: register Paradise panel descriptors"
```

### Task 3: Refactor panel implementations to delegate lifecycle

**Files:**
- Modify: `42.20/media/lua/client/Panels/ParadiseDev_DataCheck.lua`
- Modify: `42.20/media/lua/client/Panels/ParadiseDev_GlobalModData.lua`
- Modify: `42.20/media/lua/client/Panels/ParadiseDev_MediaSpawner.lua`
- Modify: `42.20/media/lua/client/Panels/ParadiseDev_ModActiveCheck.lua`
- Modify: `42.20/media/lua/client/Panels/ParadiseDev_PlaytimeCheck.lua`
- Modify: `42.20/media/lua/client/Panels/ParadiseDev_TraitSyncer.lua`
- Modify: `42.20/media/lua/client/Panels/ParadiseDev_ZedController.lua`
- Modify: `42.20/media/lua/client/Panels/ParadiseDev_ZonePanel.lua`
- Modify: `42.20/media/lua/client/Panels/ParadiseDev_POI.lua`
- Modify: `42.20/media/lua/client/Panels/ParadiseRestore_LuaResetTool.lua`
- Modify: `42.20/media/lua/client/Panels/WaveCaster/WaveCaster_Panel.lua`
- Modify: `42.20/media/lua/client/Panels/JimsServerRules/JimsRulesUI.lua`
- Modify: `42.20/media/lua/client/Panels/ParadisePromo/ParadisePromo_Admin.lua`
- Modify: `42.20/media/lua/client/Panels/ParadisePromo/ParadisePromo_Client.lua`
- Create: `tests/client/Panels/test_ParadisePanelDelegation.lua`

**Interfaces:**
- Consumes: Task 1 generated module methods and Task 2 descriptors/hooks.
- Produces: close-button/class handlers that call their owning `ClosePanel()`, with old lifecycle definitions removed and specialized non-lifecycle panel behavior unchanged.

- [ ] **Step 1: Write failing delegation/migration tests**

Load representative panel files against stub UI base classes and replace generated `ClosePanel` methods with counters. Assert their `close`, `destroy`, and explicit close-button handlers call the counter. Add source assertions that old lifecycle definitions are absent and that WaveCaster, ZedController, Zone Editor, and JimsRulesUI cleanup responsibilities are represented in descriptor hooks rather than lost.

- [ ] **Step 2: Run the delegation test to verify RED**

Run: `lua tests/client/Panels/test_ParadisePanelDelegation.lua`

Expected: FAIL because current handlers perform direct cleanup and old lifecycle functions remain.

- [ ] **Step 3: Refactor simple panel lifecycle code**

For DataCheck, GlobalModData, MediaSpawner, ModActiveCheck, PlaytimeCheck, TraitSyncer, POI, LuaResetTool, and both Promo panels, delete their old open/close functions and make UI close handlers call the exact owning module's `ClosePanel()`.

- [ ] **Step 4: Refactor specialized panel lifecycle code**

For ZedController, Zones main/editor/test, WaveCaster, and JimsRulesUI, move specialized construction/open/cleanup work into Task 2 descriptor callbacks and leave instance handlers as non-recursive delegates. Preserve all arguments and current side effects listed in the spec.

- [ ] **Step 5: Run both Lua tests to verify GREEN**

Run:

```powershell
lua tests/client/Panels/test_ParadisePanels_Main.lua
lua tests/client/Panels/test_ParadisePanelDelegation.lua
```

Expected: both commands PASS with exit code 0.

- [ ] **Step 6: Commit only panel lifecycle refactors and their test**

Stage the listed panel files and `test_ParadisePanelDelegation.lua`, review `git diff --cached`, then commit:

```powershell
git commit -m "refactor: unify Paradise panel lifecycle"
```

### Task 4: Migrate callers and close admin panels on demotion

**Files:**
- Modify: `42.20/media/lua/client/Panels/ParadisePanels_Main.lua`
- Modify: `42.20/media/lua/client/Panels/ParadisePanels_Demote.lua`
- Modify: `42.20/media/lua/client/Panels/ParadiseDev_AdminPanels.lua`
- Modify: `42.20/media/lua/client/Panels/JimsServerRules/JimsRulesClient.lua`
- Modify: `42.20/media/lua/client/ContextMenu/ParadiseDev_Context.lua`
- Modify: `42.20/media/lua/client/Dev/DBG/ParadiseDev_Tiles.lua`
- Modify: `42.20/media/lua/client/Dev/ParadiseDev_ZoneHUD.lua`
- Modify: `42.20/media/lua/client/Dev/patch/ParadiseDev_Chat.lua`
- Modify: any additional caller found by the required full-tree search
- Modify: `tests/client/Panels/test_ParadisePanels_Main.lua`
- Create: `tests/client/Panels/test_ParadisePanelCallers.lua`

**Interfaces:**
- Consumes: standardized module lifecycle methods and registry `isAdmOnly` metadata.
- Produces: `ParadisePanels.CloseAdminPanels()` and caller code containing no references to removed panel lifecycle functions.

- [ ] **Step 1: Write the failing admin-close test**

Construct a registry containing one admin entry, one player entry, one unresolved entry, and one admin entry with no instance. Assert `CloseAdminPanels()` invokes only the resolvable admin module's `ClosePanel()` and does not throw.

- [ ] **Step 2: Write the failing caller migration test**

Scan `42.20/media/lua` and assert there are no calls or definitions for the removed panel lifecycle names identified in the spec, while allowing unrelated domain functions. Assert the known context-menu, debug-tile, Zone HUD, chat, JimsServerRules client, and admin-panel call sites contain the appropriate new module method.

- [ ] **Step 3: Run both tests to verify RED**

Run:

```powershell
lua tests/client/Panels/test_ParadisePanels_Main.lua
lua tests/client/Panels/test_ParadisePanelCallers.lua
```

Expected: FAIL because `CloseAdminPanels` and new caller names are missing.

- [ ] **Step 4: Implement admin-only bulk close and demotion integration**

Add `ParadisePanels.CloseAdminPanels()` to `ParadisePanels_Main.lua`. Update `ParadisePanels.Demote.doDemote(pl)` to set `pl:getModData().isAdm = false` and invoke it. Do not close player-facing entries.

- [ ] **Step 5: Migrate every lifecycle caller**

Replace all old lifecycle calls with the exact standardized module function. Preserve callback argument order and use closures only where direct callback passing would change it. Repeat the full-tree search after edits to catch callers outside the initially known files.

- [ ] **Step 6: Run all Lua tests to verify GREEN**

Run:

```powershell
lua tests/client/Panels/test_ParadisePanels_Main.lua
lua tests/client/Panels/test_ParadisePanelDelegation.lua
lua tests/client/Panels/test_ParadisePanelCallers.lua
```

Expected: all commands PASS with exit code 0.

- [ ] **Step 7: Commit the demotion behavior and caller migration**

Stage only the task-owned files/hunks, inspect the staged diff, then commit:

```powershell
git commit -m "refactor: migrate panel lifecycle callers"
```

### Task 5: Full static and runtime-oriented verification

**Files:**
- Modify only files required to correct failures found by this task.

**Interfaces:**
- Consumes: Tasks 1-4 complete lifecycle implementation.
- Produces: verified registry coverage, clean static migration, and a concise manual Project Zomboid smoke-test checklist.

- [ ] **Step 1: Run the complete automated suite**

Run:

```powershell
Get-ChildItem tests/client/Panels/test_*.lua | ForEach-Object { lua $_.FullName; if ($LASTEXITCODE -ne 0) { throw "Lua test failed: $($_.FullName)" } }
```

Expected: every test reports PASS and the command exits 0.

- [ ] **Step 2: Run syntax checks on all changed Lua files**

Run `luac -p` for every changed `.lua` file when `luac` is installed; otherwise load non-PZ-dependent files through `lua` and report that full parsing is limited by unavailable game globals.

Expected: no Lua syntax errors.

- [ ] **Step 3: Run final lifecycle migration searches**

Use `rg` across `42.20/media/lua` to confirm no removed lifecycle definitions/calls remain, every registered UI has exactly the three generated entry points through its module, and every live close handler delegates to `ClosePanel()`.

Expected: only unrelated domain functions or explicitly documented exclusions match old generic verbs.

- [ ] **Step 4: Inspect the complete scoped diff**

Run `git diff --check`, inspect `git diff` and `git status --short`, and verify unrelated pre-existing edits were neither overwritten nor staged.

Expected: no whitespace errors and only intended lifecycle changes in the scoped diff.

- [ ] **Step 5: Record the in-game smoke checklist in the handoff**

List: open/reopen/toggle/close each registry entry; exercise DataCheck, Zone Editor, ZedController, WaveCaster, and JimsRulesUI parameters; verify Promo admin/player independence; demote with both admin and player panels open; verify WaveCaster marker/child cleanup, Zone child cleanup, ZedController cursor cleanup, and JimsRulesUI joypad focus restoration.

- [ ] **Step 6: Commit any verification fixes**

If verification required code changes, rerun Steps 1-4 and commit only those fixes with `fix: complete panel lifecycle migration`. If no changes were needed, do not create an empty commit.
