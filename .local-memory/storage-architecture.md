# BRutus — Storage Architecture

_Last updated: 2026-04-26_

---

## Situação Atual

`BRutus.db` é acessado diretamente por praticamente todos os módulos.
Não existe uma camada de proteção, schema enforcement ou migration system.

### Acessos Diretos Mapeados

| Módulo/Arquivo | Campos acessados diretamente |
|---|---|
| `Core.lua` | BRutusDB, BRutus.db (todos os campos — define defaults) |
| `CommSystem.lua` | BRutus.db.altLinks, BRutus.db.members |
| `DataCollector.lua` | BRutus.db.members, BRutus.db.myData |
| `AttunementTracker.lua` | BRutus.db.members (via DataCollector normalmente) |
| `RaidTracker.lua` | BRutus.db.raidTracker.sessions, .attendance, .currentGroupTag, .deletedSessions |
| `LootTracker.lua` | BRutus.db.lootHistory |
| `LootMaster.lua` | BRutus.db.lootMaster, BRutus.db.lootPrios, BRutus.db.guildWishlists |
| `WishlistSystem.lua` | BRutus.db.guildWishlists, BRutus.db.lootPrios, BRutus.db.wishlists |
| `RecipeTracker.lua` | BRutus.db.recipes, BRutus.db.recipeScanTimes |
| `OfficerNotes.lua` | BRutus.db.officerNotes |
| `TrialTracker.lua` | BRutus.db.trials |
| `RecruitmentSystem.lua` | BRutus.db.recruitment |
| `ConsumableChecker.lua` | BRutus.db.consumableChecks |
| `SpecChecker.lua` | BRutus.db.members (spec field) |
| `UI/FeaturePanels.lua` | BRutus.db.raidTracker, BRutus.db.lootHistory, BRutus.db.trials, BRutus.db.recruitment, BRutus.db.settings |
| `UI/MemberDetail.lua` | BRutus.db.members, BRutus.db.altLinks, BRutus.db.officerNotes |
| `UI/RaidHUD.lua` | Migrado para BRutus.State ✅ |
| `UI/RosterFrame.lua` | Usa GetSetting/SetSetting ✅ |

---

## Schema Atual (BRutusDB)

```lua
BRutusDB = {
    -- (flat, sem nested por guild — exceto guildKey como key)
    ["GuildName-Realm"] = {
        version  = 1,
        settings = {
            sortBy         = "level",
            sortAsc        = false,
            showOffline    = true,
            minimap        = { hide = false },
            officerMaxRank = 2,
            modules        = { raidTracker=true, lootTracker=true, ... },
        },
        members  = {
            ["Name-Realm"] = {
                name, realm, class, level, race,
                avgIlvl, gear, professions, attunements,
                stats, spec, addonVersion, lastUpdate, lastSync,
            }
        },
        myData          = {},          -- snapshot do player local
        altLinks        = {},          -- [altKey] = mainKey
        guildWishlists  = {},          -- [lowerName] = { name, class, wishlist=[] }
        lootPrios       = {},          -- [itemId(num)] = [{ name, class, order }]
        wishlists       = {},          -- [charKey] = [{ itemId, itemLink, order, isOffspec }]
        raidTracker     = {
            sessions        = {},
            attendance      = {},
            currentGroupTag = "",
            deletedSessions = {},      -- tombstones permanentes
        },
        lootHistory     = {},          -- [{ itemId, itemLink, playerName, raidName, timestamp }]
        lootMaster      = {
            rollDuration     = 30,
            autoAnnounce     = true,
            wishlistOnlyMode = false,
            awardHistory     = {},
        },
        officerNotes    = {},          -- [key] = { notes=[], tags={} }
        trials          = {},          -- [key] = { status, startDate, endDate, notes, snapshots }
        recruitment     = {},          -- { enabled, interval, message, channels, ... }
        consumableChecks = { lastResults = {} },
        recipes         = {},          -- [charKey] = { [canonProfName] = [{ name, spellId, itemId }] }
        recipeScanTimes = {},          -- [profName] = timestamp
        lastSync        = 0,
    }
}
```

---

## Arquitetura Alvo: Storage Layer

```lua
-- Storage.lua — único ponto de acesso a BRutusDB
BRutus.Storage = {}

-- Internamente: BRutus.Storage._db = BRutusDB[guildKey]

function BRutus.Storage:Get(domain, key)
    return self._db[domain] and self._db[domain][key]
end

function BRutus.Storage:Set(domain, key, value)
    if not self._db[domain] then self._db[domain] = {} end
    self._db[domain][key] = value
end

function BRutus.Storage:GetAll(domain)
    return self._db[domain] or {}
end

function BRutus.Storage:Delete(domain, key)
    if self._db[domain] then
        self._db[domain][key] = nil
    end
end

function BRutus.Storage:GetSetting(key)
    return self._db.settings and self._db.settings[key]
end

function BRutus.Storage:SetSetting(key, value)
    if not self._db.settings then self._db.settings = {} end
    self._db.settings[key] = value
end
```

---

## Repository Pattern Alvo

```lua
-- Repository/MemberRepository.lua
local MemberRepository = {}
BRutus.MemberRepository = MemberRepository

function MemberRepository:Get(playerKey)
    return BRutus.Storage:Get("members", playerKey)
end

function MemberRepository:Save(playerKey, data)
    data.updatedAt = GetTime()
    BRutus.Storage:Set("members", playerKey, data)
end

function MemberRepository:GetAll()
    return BRutus.Storage:GetAll("members")
end
```

---

## Distinção de Tipos de Dado

### Persisted (SavedVariables — sobrevive ao reload)
- `members` — dados de gear/profs/etc dos guildmates
- `raidTracker.sessions` — histórico de raids
- `raidTracker.attendance` — presença calculada
- `lootHistory` — histórico de loot
- `lootMaster.awardHistory` — histórico de awards
- `guildWishlists` / `wishlists` / `lootPrios`
- `officerNotes`
- `trials`
- `altLinks`
- `recruitment`
- `recipes` / `recipeScanTimes`
- `settings`
- `myData`

### Runtime (BRutus.State — reseta no reload)
- `State.comm` — lastBroadcast, pendingMessages
- `State.lootMaster` — activeLoot, rolls, rollTimer, ...
- `State.recruitment` — ticker, knownMembers, welcomedRecently
- `State.raid` — currentRaid, snapshotTimer, endTimer
- `State.consumables` — lastCheck
- `State.raidCD` — CD state + raid members

### Cache (computed, pode ser regenerado)
- Lista de membros filtrada/ordenada (RosterFrame)
- Index de receitas (RecipeTracker)
- Resumos de atunamento
- Percentuais de presença

### Computed (calculado, não deve ser salvo)
- Attendance percent
- Score de consumíveis
- Wishlist ranking
- Resumo de atunamentos por player

---

## Limites de Crescimento

| Campo | Limite atual | Limite recomendado |
|---|---|---|
| `lootHistory` | 500 entries (LootTracker) | 500 ✅ |
| `lootMaster.awardHistory` | sem limite | 500 |
| `officerNotes[key].notes` | 50 por player (OfficerNotes) | 50 ✅ |
| `members` | sem limite (todos os guildmates) | OK |
| `raidTracker.sessions` | sem limite | 200 sessions |
| `raidTracker.deletedSessions` | tombstones permanentes | 500 ids |
| `recipes` | sem limite | OK (pequeno) |
| Dedup de messageIds (futuro) | sem limite | 500 ids em memória |
| `consumableChecks.lastResults` | sem limite | 1 resultado por member |

---

## Schema Migration

```lua
-- Em Core.lua (por enquanto) ou Storage.lua (alvo)
function BRutus:MigrateDB(db)
    db.version = db.version or 1

    if db.version < 2 then
        -- Migração v1 → v2: mover lootMaster para sub-tabela
        -- ...
        db.version = 2
    end

    if db.version < 3 then
        -- Migração v2 → v3: adicionar campo X
        -- ...
        db.version = 3
    end
end
```

**Regra**: nunca apagar campos sem migrar os dados existentes.
**Regra**: sempre inicializar com `or default` para compatibilidade retroativa.

---

## Convenções de Chaves

| Conceito | Formato | Exemplo |
|---|---|---|
| Player key | `"Name-Realm"` | `"Arthax-Firetree"` |
| Guild key | `"GuildName-Realm"` | `"Insanity-Firetree"` |
| Session ID | `"instanceID-weekNum"` | `"532-2650"` |
| Message ID | 4+ hex chars | `"A1B2"` |

**Normalização**: nomes de player sempre com realm completo; nunca usar só o nome curto como chave.
