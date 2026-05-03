----------------------------------------------------------------------
-- BRutus Guild Manager - Data/RaidAssignmentTemplates
-- Static assignment templates for Phase 2 raids: SSC and TK.
--
-- Each slot supports:
--   id           (string)  — unique identifier within the boss
--   label        (string)  — human-readable name
--   role         (string)  — "tank"|"healer"|"dps"|"ranged"|"melee"|"any"
--   count        (number)  — players needed (default 1)
--   priority     (string)  — "HIGH"|"MEDIUM"|"LOW"
--   critical     (bool)    — missing this slot → confidence LOW
--   requirements (table)   — optional special flags (warlockTank, frostResist, …)
--   phase        (string)  — optional phase grouping key (used by Kael'thas)
--   notes        (string)  — optional hint shown in preview
----------------------------------------------------------------------

BRutus.RaidAssignmentTemplates = {

    --------------------------------------------------------------------
    -- SERPENTSHRINE CAVERN
    --------------------------------------------------------------------
    SSC = {
        name            = "Serpentshrine Cavern",
        short           = "SSC",
        attunementShort = "SSC",
        bossOrder       = { "hydross", "lurker", "leotheras", "karathress", "morogrim", "vashj" },
        bosses = {

            ---- Hydross the Unstable ----
            hydross = {
                name  = "Hydross the Unstable",
                slots = {
                    { id = "frost_resist_tank",  label = "Frost Resistance Tank",    role = "tank",   count = 1, priority = "HIGH",   critical = true,  requirements = { tank = true, frostResist = true },  notes = "Full Frost Resist kit required" },
                    { id = "nature_resist_tank", label = "Nature Resistance Tank",   role = "tank",   count = 1, priority = "HIGH",   critical = true,  requirements = { tank = true, natureResist = true }, notes = "Full Nature Resist kit required" },
                    { id = "add_tanks",          label = "Add Tanks",                role = "tank",   count = 2, priority = "HIGH",   critical = true,  requirements = {} },
                    { id = "frost_healers",      label = "Frost Phase Healers",      role = "healer", count = 3, priority = "MEDIUM", critical = false, requirements = {} },
                    { id = "nature_healers",     label = "Nature Phase Healers",     role = "healer", count = 3, priority = "MEDIUM", critical = false, requirements = {} },
                    { id = "add_dps",            label = "Add DPS Focus",            role = "dps",    count = 4, priority = "MEDIUM", critical = false, requirements = {} },
                    { id = "decurse_support",    label = "Decurse / Cleanse",        role = "any",    count = 2, priority = "MEDIUM", critical = false, requirements = {} },
                    { id = "raid_notes",         label = "Raid Lead Notes",          role = "any",    count = 1, priority = "LOW",    critical = false, notes = "Call phase transitions at 25%/75% HP" },
                },
            },

            ---- The Lurker Below ----
            lurker = {
                name  = "The Lurker Below",
                slots = {
                    { id = "main_tank",          label = "Main Tank",                role = "tank",   count = 1, priority = "HIGH",   critical = true  },
                    { id = "add_tanks",          label = "Platform Add Tanks",       role = "tank",   count = 2, priority = "HIGH",   critical = true  },
                    { id = "spout_call",         label = "Spout Call",               role = "any",    count = 1, priority = "HIGH",   critical = false, notes = "Call on voice when Lurker turns to spout — everyone jump" },
                    { id = "platform_groups",    label = "Platform Groups (3x)",     role = "any",    count = 3, priority = "MEDIUM", critical = false, notes = "Assign 3 balanced groups to platforms" },
                    { id = "interrupt_team",     label = "Interrupt Team",           role = "melee",  count = 3, priority = "MEDIUM", critical = false },
                    { id = "ranged_spread",      label = "Ranged Spread Groups",     role = "ranged", count = 4, priority = "MEDIUM", critical = false },
                    { id = "healer_assignments", label = "Healer Assignments",       role = "healer", count = 5, priority = "MEDIUM", critical = false },
                },
            },

            ---- Leotheras the Blind ----
            leotheras = {
                name  = "Leotheras the Blind",
                slots = {
                    { id = "human_tank",         label = "Human Phase Tank",         role = "tank",   count = 1, priority = "HIGH",   critical = true,  requirements = { tank = true } },
                    { id = "demon_tank",         label = "Demon Phase Warlock Tank", role = "dps",    count = 1, priority = "HIGH",   critical = true,  requirements = { warlockTank = true }, notes = "Must be Warlock — Demon phase tank with shadow resist" },
                    { id = "warlock_healer",     label = "Warlock Tank Healer",      role = "healer", count = 1, priority = "HIGH",   critical = true  },
                    { id = "mt_healers",         label = "Main Tank Healers",        role = "healer", count = 2, priority = "HIGH",   critical = true  },
                    { id = "whirlwind_call",     label = "Whirlwind Call",           role = "any",    count = 1, priority = "MEDIUM", critical = false, notes = "Call whirlwind direction — melee move immediately" },
                    { id = "inner_demon",        label = "Inner Demon Awareness",    role = "dps",    count = 5, priority = "MEDIUM", critical = false, notes = "Assigned players kill their own inner demon" },
                    { id = "melee_safe_call",    label = "Melee Safe Call",          role = "any",    count = 1, priority = "LOW",    critical = false },
                },
            },

            ---- Fathom-Lord Karathress ----
            karathress = {
                name  = "Fathom-Lord Karathress",
                slots = {
                    { id = "karathress_tank",    label = "Karathress Tank",          role = "tank",   count = 1, priority = "HIGH",   critical = true  },
                    { id = "sharkkis_tank",      label = "Sharkkis Tank",            role = "tank",   count = 1, priority = "HIGH",   critical = true  },
                    { id = "tidalvess_tank",     label = "Tidalvess Tank",           role = "tank",   count = 1, priority = "HIGH",   critical = true  },
                    { id = "caribdis_tank",      label = "Caribdis Tank",            role = "tank",   count = 1, priority = "MEDIUM", critical = false, notes = "Usually off-tank or add-capable" },
                    { id = "interrupt_team",     label = "Interrupt Team",           role = "melee",  count = 3, priority = "HIGH",   critical = true,  notes = "Interrupt Cataclysmic Bolt and Lightning Bolt" },
                    { id = "healer_assignments", label = "Healers Per Tank",         role = "healer", count = 4, priority = "MEDIUM", critical = false },
                    { id = "kill_order",         label = "Kill Order",               role = "any",    count = 1, priority = "MEDIUM", critical = false, notes = "Sharkkis > Tidalvess > Caribdis > Karathress" },
                    { id = "totem_control",      label = "Totem / Spitfire Control", role = "dps",    count = 2, priority = "MEDIUM", critical = false, notes = "Kill Water Totems and Spitfire Totem" },
                },
            },

            ---- Morogrim Tidewalker ----
            morogrim = {
                name  = "Morogrim Tidewalker",
                slots = {
                    { id = "main_tank",           label = "Main Tank",                        role = "tank",   count = 1, priority = "HIGH",   critical = true  },
                    { id = "murloc_tank_1",       label = "Murloc Tank 1",                    role = "tank",   count = 1, priority = "HIGH",   critical = true  },
                    { id = "murloc_tank_2",       label = "Murloc Tank 2 (Paladin preferred)", role = "tank",  count = 1, priority = "HIGH",   critical = true,  requirements = { preferPaladin = true } },
                    { id = "murloc_aoe_team",     label = "Murloc AoE Team",                  role = "dps",    count = 4, priority = "MEDIUM", critical = false, notes = "AoE when murlocs stack" },
                    { id = "watery_grave_healers", label = "Watery Grave Healers",            role = "healer", count = 2, priority = "HIGH",   critical = true,  notes = "Instant heal Watery Grave targets" },
                    { id = "earthquake_call",     label = "Earthquake Call",                  role = "any",    count = 1, priority = "MEDIUM", critical = false, notes = "Call earthquake — everyone spread" },
                    { id = "paladin_priority",    label = "Paladin Consecration Tank",        role = "any",    count = 1, priority = "LOW",    critical = false },
                },
            },

            ---- Lady Vashj ----
            vashj = {
                name  = "Lady Vashj",
                slots = {
                    { id = "phase1_tank",          label = "Phase 1 Main Tank",          role = "tank",   count = 1, priority = "HIGH",   critical = true  },
                    { id = "static_charge_call",   label = "Static Charge Call",         role = "any",    count = 1, priority = "HIGH",   critical = false, notes = "Call target — run away from raid" },
                    { id = "generator_teams",      label = "Phase 2 Generator Teams",    role = "any",    count = 4, priority = "HIGH",   critical = true,  notes = "4 teams assigned to one generator each" },
                    { id = "core_runners",         label = "Core Runners",               role = "dps",    count = 2, priority = "HIGH",   critical = true,  notes = "Pick up Tainted Cores — NOT tanks or main healers" },
                    { id = "tainted_elemental",    label = "Tainted Elemental Killers",  role = "ranged", count = 4, priority = "HIGH",   critical = true,  notes = "Kill Tainted Elementals immediately" },
                    { id = "strider_kiter",        label = "Strider Kiter",              role = "any",    count = 1, priority = "MEDIUM", critical = false, notes = "Hunter or fast class kiting Naga Striders" },
                    { id = "naga_tanks",           label = "Naga Tanks",                 role = "tank",   count = 2, priority = "MEDIUM", critical = false },
                    { id = "interrupt_support",    label = "Interrupt / Fear / Slow",    role = "melee",  count = 3, priority = "MEDIUM", critical = false },
                    { id = "phase3_burn",          label = "Phase 3 Burn Assignments",   role = "dps",    count = 8, priority = "HIGH",   critical = false, notes = "All DPS on Vashj — interrupt Entangle Roots" },
                    { id = "healer_groups",        label = "Healer Groups",              role = "healer", count = 5, priority = "MEDIUM", critical = false },
                },
            },

        }, -- bosses (SSC)
    }, -- SSC

    --------------------------------------------------------------------
    -- TEMPEST KEEP: THE EYE
    --------------------------------------------------------------------
    TK = {
        name            = "Tempest Keep: The Eye",
        short           = "TK",
        attunementShort = "TK",
        bossOrder       = { "alar", "voidreaver", "solarian", "kael" },
        bosses = {

            ---- Al'ar ----
            alar = {
                name  = "Al'ar",
                slots = {
                    { id = "platform_tank_1",    label = "Platform Tank 1 (Upper)",  role = "tank",   count = 1, priority = "HIGH",   critical = true  },
                    { id = "platform_tank_2",    label = "Platform Tank 2 (Lower)",  role = "tank",   count = 1, priority = "HIGH",   critical = true  },
                    { id = "add_tank",           label = "Add Tank",                 role = "tank",   count = 1, priority = "HIGH",   critical = true  },
                    { id = "ground_phase_tank",  label = "Ground Phase Tank (P2)",   role = "tank",   count = 1, priority = "HIGH",   critical = true  },
                    { id = "meteor_call",        label = "Meteor Call",              role = "any",    count = 1, priority = "HIGH",   critical = false, notes = "Call Meteor target — raid spreads to edges" },
                    { id = "platform_healers",   label = "Platform Healers",         role = "healer", count = 4, priority = "MEDIUM", critical = false, notes = "Distribute across both platforms" },
                    { id = "ember_control",      label = "Ember of Al'ar Control",   role = "ranged", count = 4, priority = "MEDIUM", critical = false, notes = "Kill Ember adds immediately" },
                    { id = "ranged_groups",      label = "Ranged Position Groups",   role = "ranged", count = 4, priority = "LOW",    critical = false },
                },
            },

            ---- Void Reaver ----
            voidreaver = {
                name  = "Void Reaver",
                slots = {
                    { id = "main_tank",          label = "Main Tank",                role = "tank",   count = 1, priority = "HIGH",   critical = true  },
                    { id = "off_tank",           label = "Off Tank",                 role = "tank",   count = 1, priority = "MEDIUM", critical = false },
                    { id = "orb_call",           label = "Pounding Orb Call",        role = "any",    count = 1, priority = "HIGH",   critical = false, notes = "Call orb landing — everyone dodge" },
                    { id = "melee_group",        label = "Melee Group",              role = "melee",  count = 4, priority = "MEDIUM", critical = false },
                    { id = "ranged_spread",      label = "Ranged Spread Groups",     role = "ranged", count = 4, priority = "MEDIUM", critical = false, notes = "25 yards apart to avoid shared Pounding" },
                    { id = "healer_assignments", label = "Healer Assignments",       role = "healer", count = 5, priority = "MEDIUM", critical = false },
                    { id = "threat_watch",       label = "Threat Watch",             role = "any",    count = 1, priority = "LOW",    critical = false },
                },
            },

            ---- High Astromancer Solarian ----
            solarian = {
                name  = "High Astromancer Solarian",
                slots = {
                    { id = "main_tank",          label = "Main Tank",                        role = "tank",   count = 1, priority = "HIGH",   critical = true  },
                    { id = "add_tanks",          label = "Add Tanks (Phase 2)",              role = "tank",   count = 2, priority = "MEDIUM", critical = false },
                    { id = "wrath_call",         label = "Wrath of the Astromancer Call",    role = "any",    count = 1, priority = "HIGH",   critical = false, notes = "Call target — run away from raid immediately" },
                    { id = "add_control",        label = "Portal / Add Control",             role = "dps",    count = 4, priority = "MEDIUM", critical = false },
                    { id = "dispel_support",     label = "Priest / Dispel Support",          role = "healer", count = 2, priority = "MEDIUM", critical = false, notes = "Dispel Arcane Vulnerability stacks" },
                    { id = "healer_assignments", label = "Healer Assignments",               role = "healer", count = 4, priority = "MEDIUM", critical = false },
                    { id = "spread_groups",      label = "Spread Groups",                    role = "any",    count = 4, priority = "MEDIUM", critical = false },
                    { id = "arcane_soaker",      label = "Arcane Resist Soaker (Optional)",  role = "any",    count = 1, priority = "LOW",    critical = false },
                },
            },

            ---- Kael'thas Sunstrider ----
            kael = {
                name   = "Kael'thas Sunstrider",
                phases = {
                    { id = "phase1_advisors", name = "Phase 1 — Advisors"         },
                    { id = "phase2_weapons",  name = "Phase 2 — Weapons"          },
                    { id = "phase3_return",   name = "Phase 3 — Advisors Return"  },
                    { id = "phase4_kael",     name = "Phase 4 — Kael'thas"        },
                    { id = "phase5_gravity",  name = "Phase 5 — Gravity Lapse"    },
                },
                slots = {
                    -- Phase 1 — Advisors
                    { id = "thaladred_call",  label = "Thaladred Call (Eye)",     role = "any",    count = 1, priority = "HIGH",   critical = true,  phase = "phase1_advisors", notes = "Call when Thaladred fixates — named target runs out" },
                    { id = "sanguinar_tank",  label = "Sanguinar Tank",           role = "tank",   count = 1, priority = "HIGH",   critical = true,  phase = "phase1_advisors" },
                    { id = "capernian_tank",  label = "Capernian Tank (Warlock)", role = "dps",    count = 1, priority = "HIGH",   critical = true,  phase = "phase1_advisors", requirements = { warlockTank = true }, notes = "Warlock tanks Capernian with shadow resist" },
                    { id = "telonicus_tank",  label = "Telonicus Tank",           role = "tank",   count = 1, priority = "HIGH",   critical = true,  phase = "phase1_advisors" },
                    { id = "interrupt_p1",    label = "Interrupt Team (P1)",      role = "melee",  count = 3, priority = "HIGH",   critical = true,  phase = "phase1_advisors", notes = "Interrupt Capernian Fireball" },

                    -- Phase 2 — Weapons
                    { id = "weapon_tanks",      label = "Weapon Tanks (5x)",      role = "tank",   count = 5, priority = "HIGH",   critical = true,  phase = "phase2_weapons" },
                    { id = "weapon_kill_order", label = "Weapon Kill Order",      role = "any",    count = 1, priority = "HIGH",   critical = false, phase = "phase2_weapons", notes = "Shard > Staff > Hammer > Orb > Sword" },
                    { id = "legendary_assigns", label = "Legendary Weapon Pickup", role = "any",   count = 1, priority = "LOW",    critical = false, phase = "phase2_weapons" },

                    -- Phase 3 — Advisors Return
                    { id = "mind_control",    label = "Mind Control (Priests)",   role = "healer", count = 2, priority = "HIGH",   critical = true,  phase = "phase3_return",  requirements = { priest = true }, notes = "MC Capernian for Conflagration damage" },

                    -- Phase 4 — Kael'thas
                    { id = "phoenix_tank",    label = "Phoenix Tank",             role = "tank",   count = 1, priority = "HIGH",   critical = true,  phase = "phase4_kael" },
                    { id = "egg_dps",         label = "Egg DPS",                  role = "ranged", count = 4, priority = "HIGH",   critical = true,  phase = "phase4_kael",    notes = "Kill phoenix egg before it hatches" },
                    { id = "healer_p4",       label = "Healer Assignments (P4)",  role = "healer", count = 5, priority = "HIGH",   critical = false, phase = "phase4_kael" },

                    -- Phase 5 — Gravity Lapse
                    { id = "gravity_lapse",   label = "Gravity Lapse Spread",     role = "any",    count = 8, priority = "HIGH",   critical = false, phase = "phase5_gravity", notes = "Assign positions on outer ring — kill Arcane Spheres" },
                    { id = "advisor_p5",      label = "Advisor Phase Calls",      role = "any",    count = 1, priority = "MEDIUM", critical = false, phase = "phase5_gravity" },
                },
            },

        }, -- bosses (TK)
    }, -- TK

} -- BRutus.RaidAssignmentTemplates
