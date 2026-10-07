<div align="center">

<img src="https://raw.githubusercontent.com/palanimForever/XPForever/main/docs/images/logo.png" alt="XPForever logo" width="128">

# XPForever

**See how close your next level is – right on your experience bar.**
Quest XP from completed quests, rested XP, XP per hour, time to level and kills to level. Made for World of Warcraft: Forever.

[![CurseForge downloads](https://img.shields.io/curseforge/dt/1729338?label=CurseForge&color=9966ff)](https://www.curseforge.com/wow/addons/xpforever)
[![CurseForge version](https://img.shields.io/curseforge/v/1729338?label=version&color=9966ff)](https://www.curseforge.com/wow/addons/xpforever)
[![License: MIT](https://img.shields.io/badge/license-MIT-9966ff)](https://github.com/palanimForever/XPForever/blob/main/LICENSE)
![Game: WoW Forever](https://img.shields.io/badge/WoW-Forever%201.60-9e7a45)

by **Palanim**

<img src="https://raw.githubusercontent.com/palanimForever/XPForever/main/docs/images/gallery-hero.jpg" alt="XPForever: the experience bar with tooltip and info text" width="900">

</div>

## Highlights

- **Quest XP on the bar** – completed quests light up in amber before you turn them in
- **Stats on mouseover** – XP, missing XP, session XP, XP per hour and kills to level
- **Info text above your action bars** – pick any of 10 values
- **Modern or Classic** – a thicker bronze bar, or Blizzard's own look with every feature
- **Rested XP preview**, a golden glow while resting and smooth animations
- **Fully configurable** – colors, opacity, texts, position, all in *Options → AddOns*
- **Lightweight** – nothing runs while nothing happens (`/xpf perf` shows it)
- English and German

## Features

### See your quest XP before you turn in

Every quest you have completed but not turned in yet adds its XP to the bar in amber. One look tells you whether your turn-ins will level you up. Rested XP follows in blue.

<img src="https://raw.githubusercontent.com/palanimForever/XPForever/main/docs/images/gallery-quest-xp.jpg" alt="Quest XP and rested XP on the bar" width="900">

### Your stats on mouseover

Hover the bar for your level, XP and time to level right on the bar, plus a tooltip with your whole session: XP gained, XP per hour and how many kills you still need. You choose which values the bar text shows.

<img src="https://raw.githubusercontent.com/palanimForever/XPForever/main/docs/images/gallery-mouseover.jpg" alt="Tooltip with session statistics" width="900">

### Your numbers above the action bars

One short line that stays in view while you quest. Choose from level, current XP, missing XP, progress in percent, quest XP, rested XP, XP per hour, time to level, kills to level and XP this session. It follows your action bars automatically, or you place it anywhere you like.

<img src="https://raw.githubusercontent.com/palanimForever/XPForever/main/docs/images/gallery-info-text.jpg" alt="Info text above the action bars" width="900">

### Modern or Classic

**Modern** is a thicker bar with a bronze border and segments. **Classic** keeps Blizzard's original experience bar and adds everything XPForever offers: quest XP and rested XP previews, animations, the golden rested glow and your own colors. On first start XPForever asks which one you like; switch any time in the settings or with `/xpf style`.

<img src="https://raw.githubusercontent.com/palanimForever/XPForever/main/docs/images/gallery-styles.jpg" alt="Modern and Classic style" width="900">

### Kills to level

XPForever learns how much XP your recent kills gave you and estimates how many more you need. Quest turn-ins are recognized and left out, so the estimate stays honest.

### Smooth animations

The bar glides to its new state instead of jumping, and the XP you just gained lights up briefly. Turn in a quest and watch your XP grow into the quest XP preview.

<img src="https://raw.githubusercontent.com/palanimForever/XPForever/main/docs/images/animation.gif" alt="The bar animating when quest XP changes" width="900">

### Resting

While you rest in an inn or a city, the frame of the bar glows softly in gold and a small “Zzz” appears – the same style as the player frame.

<img src="https://raw.githubusercontent.com/palanimForever/XPForever/main/docs/images/resting.png" alt="Golden glow while resting" width="900">

### Settings

Everything is configurable in *Options → AddOns → XPForever*: style, height, segments, colors and opacity, what the bar text and the info text show, how XP per hour is calculated and more.

<p>
<img src="https://raw.githubusercontent.com/palanimForever/XPForever/main/docs/images/options.png" alt="XPForever settings" width="32%">
<img src="https://raw.githubusercontent.com/palanimForever/XPForever/main/docs/images/options-colors.png" alt="Color settings" width="32%">
<img src="https://raw.githubusercontent.com/palanimForever/XPForever/main/docs/images/options-info-text.png" alt="Info text settings" width="32%">
</p>

### Minimap button

Drag it around the minimap. Left-click opens the settings, right-click shows or hides the info text, and the tooltip gives you a quick summary. Don't like minimap buttons? Turn it off – XPForever is also listed in the addon menu at the minimap.
## Usage

| Action | Effect |
|---|---|
| Hover the bar | Show the bar text and the tooltip |
| Click the bar | Show or hide the info text |
| <kbd>Ctrl</kbd>-click the bar | Reset session statistics |
| Right-click the bar | Open settings |
| <kbd>Shift</kbd>-drag the info text | Move it anywhere |
| <kbd>Shift</kbd>-right-click the info text | Put it back above the action bars |
| `/xpf` | Open settings |
| `/xpf style` | Choose between Modern and Classic |
| `/xpf reset` | Reset session statistics |
| `/xpf perf` | Show CPU time and memory usage |

## FAQ

**Can I move the bar?**
Yes – XPForever follows Blizzard's experience bar. Move it in Edit Mode and the bar moves with it.

**What happens when I track a reputation?**
Blizzard shows the reputation bar in its own place, and XPForever stays on the experience bar.

**Why does it say “–” for XP per hour or kills?**
XPForever needs a minute of play time for XP per hour and at least one kill for the kill estimate.

**Does it work at max level?**
At max level the bar hides itself, just like Blizzard's experience bar.

## Feedback

Found a bug or have an idea? Please [open an issue](https://github.com/palanimForever/XPForever/issues).

## Credits

XPForever is made by **Palanim**. It embeds [LibStub](https://www.wowace.com/projects/libstub), [CallbackHandler-1.0](https://www.wowace.com/projects/callbackhandler), [LibDataBroker-1.1](https://github.com/tekkub/libdatabroker-1-1) and [LibDBIcon-1.0](https://www.curseforge.com/wow/addons/libdbicon-1-0) for the minimap button.

## License

MIT – see [LICENSE](https://github.com/palanimForever/XPForever/blob/main/LICENSE). Embedded libraries keep their own licenses.
