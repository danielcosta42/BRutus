# BRutus — CurseForge Listing

---

## Title
BRutus Guild Manager

## Short Description (for search/cards)
Premium guild management addon for TBC Anniversary. Auto-syncs gear, professions, attunements, TMB wishlists, raid attendance, loot history and more across your guild.

---

## CurseForge Project Description (copy/paste below)

---

# BRutus Guild Manager

**A premium guild management addon for WoW TBC Anniversary that automatically collects and shares gear, professions, raid attunements, TMB wishlists, loot history, and attendance data across your entire guild — no manual inspection required.**

![Interface: 20505](https://img.shields.io/badge/Interface-20505-blue)

---

## Why BRutus?

The default guild frame is barebones. BRutus replaces it with a full-featured management hub that gives officers and guild leaders instant visibility into what their members are wearing, what raids they're attuned to, who showed up on time with consumables, and who got what loot — all without spreadsheets or external tools.

Just install it, press **J**, and you're done.

---

## Features

### 📋 Guild Roster
- Modern dark-themed roster with **sortable columns**: Name, Level, Class, Race, Item Level, Professions, Attunements, Attendance%, Last Seen
- **Search** by name, class, zone or rank
- **Online/Offline filter** — offline members shown in grayscale
- **Hover tooltips** with full character details
- Stats bar showing total members, online count, and BRutus users

### 🔍 Member Inspection
Click any member to open their full detail panel:
- **Equipment** — all 17 gear slots with quality-colored names and item levels
- **Professions** — with rank progress bars
- **Character Stats** — HP, Mana, STR, AGI, STA, INT, SPI
- **Raid Attunements** — per-quest progress tracking with visual bars

### ⚔️ TBC Attunement Tracker
Automatically tracks quest-based attunement progress for:
- **T4:** Karazhan, Gruul's Lair, Magtheridon's Lair
- **T5:** Serpentshrine Cavern, Tempest Keep
- **T6:** Hyjal Summit, Black Temple, Sunwell Plateau
- **Heroic Keys:** HFC, Coilfang, Auchindoun, TK, Caverns of Time

### 🎯 TMB Integration (That's My BiS)
- Import TMB CSV exports with **wishlist**, **prio**, and **received loot** data
- **Tooltip integration** — hover any item to see who has it on their wishlist
- Syncs imported TMB data between officers via addon comms
- Dedicated **TMB Loot** tab for browsing all imported data

### ⚔️ Raid Tracker
- Automatically detects when you enter a raid and **tracks full sessions** (start/end, boss encounters, player snapshots)
- **Attendance scoring** with penalty system:
  - 100% base per session
  - −10% arrived late
  - −10% left early
  - −10% missing consumables
- View recent sessions and per-member attendance in the **Raids** tab

### 🍖 Consumable Checker
- Scans all raid members for expected TBC consumable buffs
- Checks **5 categories**: Flask, Food, Weapon Buff, Battle Elixir, Guardian Elixir
- Reports which categories each player is missing
- Integrates with attendance scoring — missing consumables reduce attendance %

### 📦 Loot Tracker
- Automatically records every **Rare+ item** looted in raids and dungeons
- Stores item link, recipient, timestamp, raid name, and quantity
- Browse full loot history in the **Loot** tab with sortable columns
- Keeps up to 500 entries

### 📝 Officer Notes
- Write **private notes** and apply quick-tags (Role, Priority, Status) per guild member
- Notes are **synced between officers** in real time via addon comms
- Duplicate detection prevents conflicts

### 👤 Trial Tracker (Officer Only)
- Track **trial/recruit members** with configurable trial periods (default 30 days)
- Records start date, sponsor, status (trial/approved/denied/expired), and evaluation notes
- **Auto-expires** overdue trials and alerts officers
- Manage trials in the dedicated **Trials** tab

### 📡 Automatic Data Sync
- Guild members with BRutus **automatically share** their gear, professions, attunements and stats
- Compressed protocol using LibSerialize + LibDeflate
- Periodic background sync every 5 minutes + manual sync button
- Zero configuration — just install and data flows

### Recruitment System (Officer Only)
- **Auto-recruit popups** — a notification appears at configurable intervals; click to post your recruitment message
- **Send Now** button for instant posting
- **Welcome whisper** — automatically greets new guild members with a custom message and Discord link
- **Channel management** — post to LookingForGroup, Trade, or any custom channel
- Full configuration UI in the dedicated Recruitment tab

### 🔒 Tab System
| Tab | Access |
|---|---|
| Roster | All members |
| TMB Loot | All members |
| Raids | All members |
| Loot | All members |
| Trials | Officers only |
| Recruitment | Officers only |

---

## Slash Commands

- `/brutus` or `/br` — Toggle roster window
- `/brutus scan` — Re-collect your character data
- `/brutus sync` — Broadcast your data to guild
- `/brutus reset` — Wipe data and reload
- `/brutus recruit ...` — Recruitment sub-commands (on/off, status, msg, interval, channel, welcome, discord, invite)

---

## How It Works

1. Install BRutus on any guild member's client
2. Press **J** to open the roster (replaces default guild frame)
3. Your gear, professions, attunements and stats are automatically collected
4. Data is compressed and shared with other BRutus users in your guild
5. View any guild member's full character details with a single click
6. Officers get extra tools: TMB imports, attendance tracking, loot history, trial management, and recruitment

The more guild members who install it, the more data you'll see!

---

## Libraries Included

- LibStub
- CallbackHandler-1.0
- LibSerialize
- LibDeflate
- ChatThrottleLib

---

## Notes

- Designed specifically for **TBC Anniversary** (Interface 20505)
- Channel messages (LookingForGroup, Trade) require a player click due to Blizzard restrictions — BRutus handles this with a clickable popup
- Data is stored per-character in SavedVariables

---

## Feedback & Bugs

Found a bug or have a suggestion? Open an issue on the project page!

---

[![GitHub](https://img.shields.io/badge/GitHub-BRutus-181717?logo=github)](https://github.com/danielcosta42/BRutus)
