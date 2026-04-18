# BRutus — CurseForge Listing

---

## Title
BRutus Guild Manager

## Short Description (for search/cards)
Premium guild roster & member inspector for TBC Anniversary. Auto-syncs gear, professions, attunements and stats across your guild.

---

## CurseForge Project Description (copy/paste below)

---

# BRutus Guild Manager

**A premium guild roster replacement for WoW TBC Anniversary that automatically collects and shares gear, professions, raid attunements, and stats across your entire guild — no manual inspection required.**

![Interface: 20504](https://img.shields.io/badge/Interface-20504-blue)

---

## Why BRutus?

The default guild frame is barebones. BRutus replaces it with a full-featured roster that gives officers and guild leaders instant visibility into what their members are wearing, what professions they have, and which raids they're attuned to — all without asking anyone to open a trade window or link their gear.

Just install it, press **J**, and you're done.

---

## Features

### 📋 Guild Roster
- Modern dark-themed roster with **sortable columns**: Name, Level, Class, Race, Item Level, Professions, Attunements, Last Seen
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

### 📡 Automatic Data Sync
- Guild members with BRutus **automatically share** their gear, professions, attunements and stats
- Compressed protocol using LibSerialize + LibDeflate
- Periodic background sync every 5 minutes + manual sync button
- Zero configuration — just install and data flows

### 📢 Recruitment System (Officer Only)
- **Auto-recruit popups** — a notification appears at configurable intervals; click to post your recruitment message
- **Send Now** button for instant posting
- **Welcome whisper** — automatically greets new guild members with a custom message and Discord link
- **Channel management** — post to LookingForGroup, Trade, or any custom channel
- Full configuration UI in the dedicated Recruitment tab

### 🔒 Permission System
- **Roster tab** — available to all guild members
- **Recruitment tab** — restricted to Officers and GM only

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

- Designed specifically for **TBC Anniversary** (Interface 20504)
- Channel messages (LookingForGroup, Trade) require a player click due to Blizzard restrictions — BRutus handles this with a clickable popup
- Data is stored per-character in SavedVariables

---

## Feedback & Bugs

Found a bug or have a suggestion? Open an issue on the project page!
