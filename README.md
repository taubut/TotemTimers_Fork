# TotemTimers Fork - TBC Anniversary Edition

A fork of the TotemTimers addon fixed for **World of Warcraft TBC Anniversary Edition** (January 2025).

## About

TotemTimers is a comprehensive Shaman addon that provides totem timers, cooldown tracking, shield tracking, weapon enchant tracking, and more. This fork contains fixes specifically for TBC Anniversary Edition compatibility.

**Original addon by Xianghar** - [CurseForge](https://www.curseforge.com/wow/addons/totemtimers)

## Fixes in this Fork

TBC Anniversary Edition (WOW_PROJECT_ID = 5) introduced several compatibility issues that are fixed in this fork:

- **GetSpecialization fix** - TBC Anniversary uses talent point position 5, not 3
- **TimeColor/TimerBarColor nil errors** - Added defensive checks for GUI accessing profile before initialization
- **XiTimers.timers nil errors** - Fixed multiple files accessing timers before they're created
- **MaelstromIcon nil error** - Added nil check (Maelstrom Weapon only exists in WotLK+)
- **ActionButton_Update hook error** - Function doesn't exist in TBC Anniversary
- **BuffFrame.BuffAlphaValue nil error** - Added fallback value for flash animations
- **Yellow triangle overlays** - Hidden Dragonflight UI textures (IDs 4613342, 130840) that showed on button clicks
- **Negative timer display fix** - Added guard against negative cooldown calculations
- **TOC Interface version** - Updated to 20505

## Installation

1. Download the latest release from the [Releases page](https://github.com/taubut/TotemTimers_Fork/releases)
2. Extract the zip file
3. Copy the folder to your `World of Warcraft/_anniversary_/Interface/AddOns/` directory
4. Rename the folder from `TotemTimers_Fork-x.x.x` to `TotemTimers`
5. Restart World of Warcraft

## Usage

Type `/totemtimers` or `/tt` in-game to open the options panel.

## Requirements

- World of Warcraft TBC Anniversary Edition
- Shaman class character

## Credits

- **Xianghar** - Original TotemTimers addon author
- **taubut** - TBC Anniversary fixes
- **Claude** - AI pair programming assistant

## License

This addon is released under the same license as the original TotemTimers addon.
