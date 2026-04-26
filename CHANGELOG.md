# BRutus Changelog

All notable changes to this project will be documented in this file.

## [1.22.0] - 2026-04-26

### Added
- add zone column to roster UI and update frame width

### Fixed
- correct registration of Mining profession to include the correct parameters

### Other
- Refactor attendance tracking and loot distribution features


## [1.21.0] - 2026-04-25

### Added
- add additional WoW API read globals for talent inspection functionality
- implement talent data collection and viewer for player specs
- add SpecChecker module to collect and display talent spec data

### Changed
- remove unused variables in PopulateDetail function for improved clarity


## [1.20.0] - 2026-04-24

### Added
- Add functionality to record received loot, remove entries, and export as CSV

### Changed
- remove unused variables and improve code clarity in LootMaster and FeaturePanels


## [1.19.0] - 2026-04-23

### Added
- update settings panel to mark certain features as officer-only


## [1.18.0] - 2026-04-23

### Added
- add new WoW API globals for spell texture and invite functions
- add RaidHUD for tracking raid cooldowns and consumable checks
- enhance raid attendance tracking for 25-man raids and update UI components


## [1.17.0] - 2026-04-21

### Added
- add welcome message claim functionality for officers


## [1.16.0] - 2026-04-21

### Added
- implement full sync for officer data including raid attendance and officer notes

### Fixed
- remove redundant LibSerialize initialization in BroadcastAllNotes and HandleAllIncoming functions


## [1.15.0] - 2026-04-21

### Added
- enhance account-wide attunement support and improve UI for linked characters in README and CURSEFORGE
- implement alt/main linking for account-wide attunement propagation and enhance member detail UI
- add officer rank configuration panel and integrate WoW guild control API for rank management
- add support for new profession 'Poisons' and enhance profession checks in RecipeTracker
- enhance welcome message handling for new guild members with roster tracking
- enhance item and spell crafter indexing for improved tooltip information
- migrate data storage from BRutusDB to BRutus.db for improved modularity

### Fixed
- correct reference to guildKey in reset command for proper database reset functionality
- correct formatting in login message and streamline playerKey assignments in member detail population


## [1.14.0] - 2026-04-20

### Added
- exclude gathering professions from stale profession checks and recipe listings


## [1.13.0] - 2026-04-19

### Added
- improve recipe deduplication by skipping name-only entries without ID matches
- enhance tooltip display for recipe items and spells in the Recipes panel
- enrich recipe data by merging spellIds and enhance gem tooltips in member detail
- enhance recipe scanning to extract enchant IDs from item links and merge duplicate entries


## [1.12.0] - 2026-04-19

### Added
- add item crafter index and tooltip enhancements for recipe visibility
- enhance whisper functionality to include item link in messages
- restrict officer-only module initialization and settings visibility


## [1.11.0] - 2026-04-19

### Added
- enhance guild invitation tracking and welcome messaging


## [1.10.0] - 2026-04-19

### Added
- enhance trial data broadcasting and handling for officers


## [1.9.0] - 2026-04-19

### Added
- enhance profession handling and item display across various modules


## [1.8.0] - 2026-04-19

### Added
- group crafters in recipe index and update online status display


## [1.7.0] - 2026-04-19

### Added
- Implement profession freshness check and reminder system

### Changed
- remove unused ENCHANTABLE_SLOTS definition from MemberDetail.lua


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
