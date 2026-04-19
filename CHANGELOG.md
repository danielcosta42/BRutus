# BRutus Changelog

All notable changes to this project will be documented in this file.

## [1.6.0] - 2026-04-19

### Added
- enhance WoW API integration and improve function parameters in LootMaster and UI panels

### Other
- Add Recipe Tracker and Recipes Panel for guild tradeskill management


## [1.0.0] - 2026-04-18

### Added
- Full guild roster with sortable columns (name, level, class, race, item level, professions, attunements, last seen)
- Member detail panel with equipment inspection, profession progress bars, and raid attunement tracking
- Attunement tracking for all TBC raids (Karazhan, Gruul, Magtheridon, SSC, TK, Hyjal, BT, Sunwell) and heroic dungeon keys
- Compact attunement summary with color-coded progress and tooltip details
- Guild-wide data synchronization via addon messaging with compression (LibDeflate + LibSerialize)
- Chunked message protocol for large data transfers (230-byte chunks)
- Recruitment system with popup-based channel messaging (compliant with Blizzard hardware event requirements)
- Automatic welcome whisper for new guild members with customizable message and Discord link
- Tab-based UI: Roster tab (all members) and Recruitment tab (officers only)
- Officer permission system (rank-based + CanGuildInvite fallback)
- Search and filter functionality for the guild roster
- Offline member display with grayscale styling
- Integration with default guild frame (J key hook)
- Slash commands: `/brutus` with subcommands for roster, sync, recruitment management
