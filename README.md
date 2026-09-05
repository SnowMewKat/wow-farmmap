# FarmMap

A tiny, dependency-free WoW Retail addon. While you are mounted or in Druid
Travel / Flight Form, it enlarges the minimap, centres it on screen and makes it
semi-transparent, so gathering nodes are easy to see while flying. The moment
you dismount it puts everything back.

Built and verified against **retail 12.1.0** (`## Interface: 120100`).

## Install

The addon folder is already junctioned into the game:

```
C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\FarmMap
  -> C:\Users\setos\OneDrive\Desktop\Claude Code\wow-farmmap\FarmMap
```

Edit the files here, then `/reload` in game. No copy step. On a fresh machine,
recreate the junction:

```bash
cmd /c mklink /J "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\FarmMap" "<repo>\FarmMap"
```

## Commands

| Command | Effect |
|---|---|
| `/farmmap` | Toggle the addon on and off (saved per account) |
| `/farmmap test` | Force the overlay visible, ignoring mount state. Toggle again to clear |
| `/farmmap size 450` | Width of the map circle in UI units, 100 to 1200 |
| `/farmmap alpha 0.6` | Opacity, 0.1 to 1.0 |
| `/farmmap reset` | Force the minimap back to normal right now |
| `/farmmap status` | Print enabled / test / overlay / mounted / form ID |

Defaults: enabled, size 450, alpha 0.6.

## How it works, and why it is built this way

There is only one real `Minimap` object in WoW, so a second "farm map" is not
possible without losing the gathering blips. The overlay therefore **is** the
real minimap, temporarily scaled and re-anchored.

The key decision: **scale `MinimapCluster`, never resize `Minimap` itself.**
Pin addons parent their nodes to `Minimap` and place them from
`Minimap:GetWidth()` (GatherMate2 does exactly this, in `Display.lua`). Changing
the width of `Minimap` would put every gathering pin in the wrong place;
scaling the cluster leaves that maths untouched and carries the pins along at
the new size for free. This is also how Leatrix_Plus sizes the minimap, so it is
a well-trodden path on current retail.

Everything that gets changed is read back first and restored verbatim:

- cluster scale, alpha and clamped-to-screen flag
- every anchor point, including which frame it was relative to
- which frames had mouse and mouse-wheel input enabled

Mouse input is switched off across the cluster tree while the overlay is up, so
it never eats clicks, drags or scroll, and camera and character control work
straight through it. It is switched back on afterwards.

Edit Mode owns the cluster anchors and can re-apply them underneath an addon.
FarmMap does not fight it: a 0.25s ticker notices drift and re-asserts, and
opening Edit Mode restores the minimap immediately and holds off until it closes.
The same ticker is a safety net for any mount or form change that does not fire
an event.

Travel forms treated as mounted, from `GetShapeshiftFormID()`: `3` Travel,
`4` Aquatic, `27` Swift Flight, `29` Flight.

## Tests

`FarmMap.lua` is driven headlessly against a stub of the WoW API (`lupa`, a real
Lua runtime), covering mount, dismount, all four travel forms, non-travel forms,
missed events, Edit Mode drift, every slash command, and logout. The core
assertion is a byte-for-byte diff proving the minimap is restored exactly.

## Known limits (V1)

- A gathering pin created *while* the overlay is already up keeps its mouse
  input, so it can still take a click. Pins created before it are handled.
- Minimap buttons are deliberately unclickable while mounted, since the whole
  point is that the overlay does not intercept mouse input. Dismount to click.
- `/farmmap reset` restores the minimap, but if you are still mounted the
  overlay comes back within 0.25s. Use `/farmmap` to actually turn it off.
