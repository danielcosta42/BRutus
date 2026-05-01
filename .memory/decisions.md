# BRutus — Architectural Decision Records

_Last updated: 2026-04-26_

Architectural Decision Records (ADRs) for BRutus.
This is the canonical record of WHY the codebase is structured as it is.
Add a new ADR whenever you introduce a significant architectural pattern or change.

---

## ADR-0001 — Single `BRutus` global namespace

### Context
WoW addons share a global environment. Name collisions between addons are a real hazard.
Classic TBC clients do not support modern Lua module systems or table-passing via `...`.

### Decision
Create exactly one global: `BRutus`. All modules attach as sub-tables (`BRutus.CommSystem`, `BRutus.UI`, etc.).
`Core.lua` is the only file that creates the global; all other files assume it exists.

### Consequences
- (+) One global to audit; no accidental global leakage.
- (+) Compatible with all WoW Classic client versions.
- (+) Sub-modules can alias locally: `local RT = BRutus.RaidTracker`.
- (−) Modules must be loaded in the correct order. Enforced by `.toc`.

---

## ADR-0002 — Per-guild SavedVariables key

### Context
A single BRutus installation may be used on multiple guilds (server transfers, alts in different guilds).
Mixing guild data in a single flat DB would contaminate one guild's data with another's.

### Decision
`BRutusDB` uses a `"GuildName-Realm"` key as the top-level partition.
`BRutus:ResolveGuildDB()` creates or retrieves the guild-specific sub-table and stores it as `BRutus.db`.
All modules read/write `BRutus.db`, never `BRutusDB` directly.

### Consequences
- (+) Complete data isolation per guild per realm.
- (+) Migrations only need to handle one sub-table at a time.
- (−) If a player changes guilds, old guild data remains in `BRutusDB` until cleared manually.

---

## ADR-0003 — Cross-version compatibility layer (`BRutus.Compat`)

### Context
TBC Anniversary uses a different API surface than progressive Classic or Retail.
`C_ChatInfo`, `C_QuestLog`, `C_GuildInfo`, and `C_Timer` may or may not be present.
Inline version checks scattered across modules would become unmanageable.

### Decision
All version-sensitive API calls go through `BRutus.Compat` wrappers (defined in `Core.lua`).
No module other than `Core.lua` may check for `C_ChatInfo`, `C_QuestLog`, etc. directly.

### Consequences
- (+) Single place to update when APIs change across patches.
- (+) All feature modules are version-agnostic.
- (+) Wrappers return nil on unavailability; callers guard with `if result then`.
- (−) Slight indirection; performance overhead is negligible.

---

## ADR-0004 — CommSystem with LibSerialize + LibDeflate + ChatThrottleLib

### Context
WoW addon messages have a 255-byte channel limit. Guild roster data (gear, attunements, recipes)
far exceeds this. Sending raw Lua table representations would produce large strings.

### Decision
All outgoing messages are:
1. Serialized with LibSerialize (compact binary format)
2. Compressed with LibDeflate (further reduces size)
3. Encoded for addon channel (safe ASCII)
4. Chunked into ≤230-byte pieces (leaving room for `M:<msgId>:<idx>:<total>:` prefix)
5. Throttled via ChatThrottleLib to avoid disconnects

Receiving end reassembles chunks (keyed by msgId), then reverses the pipeline.
`BRutus.State.comm.pendingMessages` holds in-flight chunk sets.

### Consequences
- (+) Can send any size payload safely.
- (+) ChatThrottleLib prevents server-side throttle kicks.
- (−) Adds 3 library dependencies (LibSerialize, LibDeflate, ChatThrottleLib).
- (−) Small messages still go through the full pipeline (acceptable overhead).

---

## ADR-0005 — Session state in `BRutus.State` (not as module member vars)

### Context
Early versions stored session state as module-level member vars (e.g. `LootMaster.activeLoot`,
`CommSystem.lastBroadcast`). These are reset on `/reload` anyway but pollute the module table
with non-persistent data, making it unclear what is saved and what is runtime-only.

### Decision
All runtime-only, non-persistent data lives in `BRutus.State` (a table created in `Core.lua`).
Sub-tables mirror module ownership: `BRutus.State.comm`, `BRutus.State.lootMaster`, etc.
Module tables only contain methods and constants.

### Consequences
- (+) Clear boundary: `BRutus.db.*` = persisted, `BRutus.State.*` = runtime-only.
- (+) Easier to inspect/reset session state in one place.
- (+) Module tables are cleaner (methods only).
- (−) Slightly more verbose access path: `BRutus.State.lootMaster.activeLoot`.

---

## ADR-0006 — No centralized event pub/sub (yet)

### Context
AutoRaidCoach uses a centralized `Events.lua` pub/sub system where all game events route
through a single frame and modules subscribe with `On(eventName, fn)`.
BRutus predates this pattern and has event frames scattered across modules.

### Decision
BRutus does NOT yet have a centralized event system.
Each module creates its own event frame inside `Initialize()` for the events it needs.
The `BRutus` frame in `Core.lua` handles core events (PLAYER_LOGIN, GUILD_ROSTER_UPDATE, etc.).

**Future direction**: Extract to a centralized `Events.lua` when the module count grows enough
to justify the refactor. An ADR will be added at that point.

### Consequences
- (+) Simpler to reason about per-module event scope.
- (+) No risk of one module's handler affecting another.
- (−) Multiple frames registered for the same event (minor overhead).
- (−) No built-in decoupling between event source and handlers.

---

## ADR-0007 — Config accessors (`BRutus:GetSetting` / `BRutus:SetSetting`)

### Context
UI callbacks were directly reading/writing `BRutus.db.settings.*`. This tightly couples UI files
to the internal SavedVariables structure and makes future schema migrations harder.

### Decision
All reads and writes of `BRutus.db.settings.*` go through:
```lua
BRutus:GetSetting(key)        -- reads BRutus.db.settings[key]
BRutus:SetSetting(key, value) -- writes BRutus.db.settings[key]
```
UI files must use these accessors. Only `Core.lua` accesses `BRutus.db.settings` directly
(to define defaults and implement the accessors).

### Consequences
- (+) Schema migrations only require updating `GetSetting`/`SetSetting`.
- (+) UI files have no direct dependency on SavedVariables key names.
- (−) Marginal overhead (function call vs direct table access).

---

## ADR-0008 — UI component factory in `UI/Helpers.lua`

### Context
Each panel file was independently creating frames, applying backdrops, and styling text.
This produced duplicated code and inconsistent visual results.

### Decision
`UI/Helpers.lua` is the single source of truth for UI component creation:
`UI:CreateButton()`, `UI:CreateText()`, `UI:CreateHeaderText()`, `UI:CreateCloseButton()`,
`UI:SkinScrollBar()`, and the `C` color table.
Panel files must use these factory functions and never inline backdrop or font logic.

**Future direction** (see `architecture.md` — Target UI split):
Split `UI/Helpers.lua` into `UI/Theme.lua` (colors, no frames) and `UI/Core.lua` (factory functions),
keeping `UI/Helpers.lua` as a thin backward-compat shim.

### Consequences
- (+) Visual consistency enforced at the factory level.
- (+) Color theme changes require updating only one file.
- (+) Panel files are simpler and more readable.
- (−) `UI/Helpers.lua` currently mixes theme and factory responsibilities (known tech debt).

---

## ADR-0009 — Business logic in data modules, not UI callbacks (Rule 10)

### Context
`UI/RaidHUD.lua` had combat log parsing inline in `SetScript("OnEvent")`.
`UI/FeaturePanels.lua` had the full attendance score calculation inline.
This duplicated logic from `RaidTracker.lua` and made the code hard to test or reuse.

### Decision
All business logic lives in the data module that owns the domain:
- Score calculation → `RaidTracker:GetSnapshotScore()`
- Combat CD tracking → `HandleCombatLogCD()` (named function, called from SetScript)
- Welcome dedup logic → `Recruitment:HandleGuildJoin()`

UI callbacks are one-liner delegations or at most simple display logic (color selection, text formatting).

### Consequences
- (+) Logic is reusable from multiple UI panels.
- (+) Data module unit-testable in isolation.
- (+) UI callbacks are readable and predictable.
- (−) Requires discipline to resist the temptation of "just putting it here for now".
