# CooldownManagerKeybinds (Improved)

Shows your action bar keybinds directly on Blizzard's Cooldown Manager icons — and on the extra bars added by **BetterCooldownManager** and **Ayije_CDM** — so you can see at a glance which key casts which cooldown, without hovering.

## Features

- **Keybind text overlay on cooldown icons** — adds a small keybind label (e.g. `1`, `S2`, `M4`) to each icon in:
  - Blizzard's built-in **Essential**, **Utility**, **Buff Icon**, and **Buff Bar** Cooldown Viewers
  - **BetterCooldownManager (BCDM)**: Custom Spells, Custom Item Spell Bar, Custom Items, and Trinket Bar
  - **Ayije_CDM**: Defensives, Trinkets, and Racials containers
- **Works with any action bar addon** — auto-detects and reads keybinds from Dominos, Bartender4, ElvUI, or the default Blizzard action bars (including MultiBars).
- **Smart macro resolution** — figures out the real spell or item behind a macro by parsing `#showtooltip`, `/cast`, `/castsequence`, `/use`, and `/item` lines, so macro'd cooldowns still show the correct key.
- **Handles spell variants** — matches overridden and base spell IDs (e.g. talent-swapped or form-changed abilities) so the key doesn't disappear when the spell changes shape.
- **Trinkets & equipped items** — resolves keybinds for on-use trinkets and equipped items, including macros that reference equip slots 13/14.
- **Per-viewer styling** — independently configure, for each bar/category:
  - Show/hide keybinds
  - Font family (via LibSharedMedia, if installed)
  - Font size and outline style
  - Font colour (with alpha/transparency)
  - Anchor point and X/Y offset
- **Assisted Combat rotation highlight** (opt-in, Essential and Utility viewers) — animates Blizzard's own rotation-helper ants on whichever Cooldown Manager icon `C_AssistedCombat` currently suggests casting next, so the rotation helper is visible on the Cooldown Manager rather than only on your action bars. Per viewer you can toggle it, restrict it to combat, set the colour/transparency, and adjust how far the highlight extends past the icon edge. Off by default.
- **Combat-safe and low overhead** — all scans and rebuilds are deferred until you leave combat; updates run on a light retry schedule instead of every frame.
- **Reacts automatically** to keybind changes, spec changes, talent changes, equipment changes, macro edits, Edit Mode layout changes, and vehicle/override/possess action bars.
- **Blizzard-native options panel** — settings are embedded directly into `Options > AddOns` instead of a separate floating window.

## Requirements

- World of Warcraft: Midnight, patch 12.1.0 (Interface 120100)
- Optional, for extra bars: [BetterCooldownManager](https://www.curseforge.com/wow/addons/bettercooldownmanager) and/or Ayije_CDM
- Optional, for extra fonts: LibSharedMedia-3.0 (a copy is bundled, but a shared-media font pack will add more choices)

No other dependencies — all required libraries (Ace3, LibSharedMedia, LibStub) are bundled with the addon.

## Installation

1. Download and extract into your `World of Warcraft/_retail_/Interface/AddOns` folder.
2. Make sure the folder is named `CooldownManagerKeybinds_Improved`, so that it matches `CooldownManagerKeybinds_Improved.toc`. WoW only loads an addon whose `.toc` filename is identical to its folder name.
3. Enable the addon at the character select screen (AddOns list) if it isn't already.

## Usage

Open the settings from **Game Menu → Options → AddOns → CooldownManagerKeybinds (Improved)**, or with the slash command:

```
/cmk options
```

For each viewer group (Essential, Utility, Buff Icons, Buff Bars, and any BCDM/Ayije_CDM groups you have installed) you can toggle keybinds on/off and adjust:

- Font family, size, and outline
- Font colour and transparency
- Anchor point (corner/edge of the icon) and X/Y offset

Groups for BetterCooldownManager or Ayije_CDM only appear in the options once that addon is installed and loaded.

### Slash commands

| Command | Effect |
|---|---|
| `/cmk` or `/cmk options` | Open the settings panel |
| `/cmk on` | Enable the addon |
| `/cmk off` | Disable the addon |
| `/cmk reset` | Reset all settings back to defaults |

## Notes

- Keybind text is purely visual — it never changes what your keys actually do, and it never taps the secure/protected action bar system.
- The rotation highlight is drawn by this addon, not by Blizzard: Blizzard renders its rotation helper on action buttons only, and the Cooldown Manager has no rotation category. If you also run **CooldownManagerCentered**, enable its rotation highlight or this one, not both — they draw on the same icons.
- Unlike the keybind labels, the rotation highlight updates live *during* combat. It runs on its own lightweight path (a precomputed spell index plus a poll at Blizzard's `assistedCombatIconUpdateRate`), so it never triggers the addon's action-bar rescan.
- Midnight (12.0+) introduced **secret values**: the client hides some combat-sensitive data from addons, and any attempt to inspect it raises a Lua error. Every ID this addon reads from a Cooldown Manager icon is checked with `issecretvalue` first, and an icon whose spell/item ID is hidden simply shows no keybind rather than erroring. This mainly affects the Buff Icon and Buff Bar viewers, where some entries may stay blank.
- Updates are intentionally delayed until you're out of combat to avoid any risk of tainting protected UI code.

## Credits

Original addon by **ahux**. This repository is a maintained/improved fork.
