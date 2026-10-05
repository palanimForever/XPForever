# XPForever

An improved experience bar for **World of Warcraft: Forever** – by Palanim.

XPForever replaces the default experience bar with a thicker, clearer bar in the Forever style and shows everything you need while levelling at a glance.

## Features

- **Clear colors** for your XP, XP from completed quests that haven't been turned in yet, and rested XP – with adjustable colors and opacity
- **Percentage** in the middle of the bar, more details on mouseover
- **Info text** above your action bars with freely selectable values: XP per hour, time to level, kills to level, quest XP, rested XP and more
- **Kills to level** – estimated from your recent kills, quest turn-ins are excluded
- **Rested indicator** – a subtle golden glow and “Zzz” while you rest in an inn or a city
- **Smooth animations** when you gain XP or level up
- **Minimap button** (draggable) and an entry in the addon menu at the minimap
- Works with tracked reputations and Edit Mode – the bar follows Blizzard's experience bar position
- English and German

## Usage

| Action | Effect |
|---|---|
| Hover the bar | Show details and the tooltip |
| Ctrl-click the bar | Reset session statistics |
| Right-click the bar | Open settings |
| `/xpf` | Open settings |
| `/xpf reset` | Reset session statistics |
| `/xpf perf` | Show CPU time and memory usage |

Settings: *Options → AddOns → XPForever*.

## Development

- Interface `16001` (World of Warcraft: Forever)
- Static checks: `luacheck XPForever` (configuration in the workspace)
- Embedded libraries in `Libs/`: LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0

## License

MIT – see [LICENSE](LICENSE). Embedded libraries keep their own licenses.
