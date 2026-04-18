# ![BRutus](https://img.shields.io/badge/BRutus-Guild%20Manager-blueviolet?style=for-the-badge) 

### Premium Guild Roster & Member Inspector for WoW TBC Anniversary

BRutus replaces the default guild frame with a modern, feature-rich roster that automatically collects and shares gear, professions, attunements, and stats across your guild — no inspection required.

> **Client:** WoW TBC Anniversary (Interface 20504)

---

## Features

### Guild Roster
- **Full guild roster** with sortable columns: Name, Level, Class, Race, Item Level, Professions, Attunements, Last Seen
- **Search** by name, class, zone or rank
- **Online/Offline toggle** with offline members shown in grayscale
- **Hover tooltips** with detailed character info
- **Click any member** to open their full inspection panel
- **Stats bar** showing total members, online count, and how many have BRutus installed

### Member Detail Panel
- Full equipment inspection (17 gear slots) with quality-colored item names and tier-colored item levels
- Profession list with progress bars and rank display
- Character stats: HP, Mana, STR, AGI, STA, INT, SPI
- Raid attunement progress with per-quest tracking and visual progress bars

### Attunement Tracker
Tracks quest-based attunement progress for all TBC raids:

| Raid | Tier |
|---|---|
| Karazhan | T4 |
| Gruul's Lair | T4 |
| Magtheridon's Lair | T4 |
| Serpentshrine Cavern | T5 |
| Tempest Keep: The Eye | T5 |
| Hyjal Summit | T6 |
| Black Temple | T6 |
| Sunwell Plateau | T6.5 |

Also tracks Heroic dungeon key reputation requirements (Honor Hold/Thrallmar, Cenarion Expedition, Lower City, Sha'tar, Keepers of Time).

### Guild-Wide Data Sync
- Automatically shares your gear, professions, attunements and stats with guildmates who have BRutus
- Compressed and chunked communication protocol (LibSerialize + LibDeflate)
- Periodic sync every 5 minutes + manual sync button
- No manual inspection needed — data flows automatically

### Recruitment System (Officer Only)
- **Auto-recruit popup** — a notification appears on a configurable interval; click it to send your recruitment message to chat channels (LookingForGroup, Trade, etc.)
- **Send Now button** in the Recruitment tab for instant posting
- **Welcome message** — automatically whispers new guild members with a customizable greeting and Discord link
- **Guild invite** via `/brutus recruit invite <Player>`
- Full configuration UI in the Recruitment tab: message, interval, channels, welcome text, Discord link

### Tab System
- **Roster tab** — visible to all guild members
- **Recruitment tab** — visible to officers and GM only

### Guild Frame Hook
Pressing **J** (or however you open the guild frame) opens BRutus instead of the default Blizzard guild panel.

---

## Slash Commands

| Command | Description |
|---|---|
| `/brutus` or `/br` | Toggle the roster window |
| `/brutus scan` | Re-collect your local character data |
| `/brutus sync` | Broadcast your data to the guild |
| `/brutus reset` | Wipe saved data and reload |

### Recruitment Commands (Officer+)

| Command | Description |
|---|---|
| `/brutus recruit on/off` | Start/stop auto-recruit popup |
| `/brutus recruit status` | Show recruitment status |
| `/brutus recruit msg <text>` | Set recruitment message |
| `/brutus recruit interval <sec>` | Set popup interval (min 60s) |
| `/brutus recruit channel add/remove/list <name>` | Manage channels |
| `/brutus recruit welcome on/off` | Toggle welcome whisper |
| `/brutus recruit welcome msg <text>` | Set welcome message |
| `/brutus recruit discord <link>` | Set Discord link |
| `/brutus recruit invite <Player>` | Send guild invite |

---

## Installation

1. Download and extract into your `Interface/AddOns/` folder
2. The folder should be named `BRutus`
3. Restart WoW or type `/reload`
4. Press **J** to open BRutus or type `/brutus`

---

## Libraries

- [LibStub](https://www.wowace.com/projects/libstub)
- [CallbackHandler-1.0](https://www.wowace.com/projects/callbackhandler)
- [LibSerialize](https://github.com/rossnichols/LibSerialize)
- [LibDeflate](https://github.com/SafeteeWoW/LibDeflate)
- [ChatThrottleLib](https://www.wowace.com/projects/chatthrottlelib)

---

## Notes

- **SendChatMessage to channels** (LookingForGroup, Trade, etc.) requires a hardware click due to Blizzard restrictions. BRutus handles this by showing a clickable popup notification instead of sending automatically.
- Officer permission is determined by guild rank index ≤ 2 or having guild invite permission.
- Data is stored per-character in `BRutusDB` SavedVariables.

---

## License

All rights reserved. This addon is provided as-is for personal use.
