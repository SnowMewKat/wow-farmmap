# FarmMap

A small, dependency-free WoW Retail addon. While you are mounted or in Druid
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

## Using it

There is a minimap button on the ring. **Left click** toggles FarmMap on and
off, **right click** opens the options panel, and you can **drag** it anywhere
around the ring.

| Command | Effect |
|---|---|
| `/farmmap` | Toggle on and off |
| `/farmmap config` | Open the options panel |
| `/farmmap test` | Force the overlay visible, ignoring mount state |
| `/farmmap mode map` | Move only the map circle (default) |
| `/farmmap mode cluster` | Move the whole minimap, zone text and buttons included |
| `/farmmap buttons` | Toggle hiding minimap buttons while farming |
| `/farmmap size 900` | Width of the map circle in UI units, 100 to 1600 |
| `/farmmap alpha 0.6` | Opacity, 0.1 to 1.0 |
| `/farmmap hud 1.0` | Scale of FarmMap's own button and panel, 0.5 to 4.0 |
| `/farmmap reset` | Force the minimap back to normal right now |
| `/farmmap status` | Print the current state |

Defaults: enabled, size 900, alpha 0.6, map mode, buttons hidden while farming.

## Can it copy the inside of the minimap instead of moving it?

No, and it is worth knowing why, because it shapes the whole design.

The minimap's terrain and its blips are drawn by the **game engine** straight
into the `Minimap` widget. An addon cannot read that back, cannot render it to a
texture, and cannot ask the engine for a second copy. There is nothing to clone.
Creating a second `Minimap` frame does not help either: the gathering blips and
every pin addon are bound to the real one, which is exactly what you need to see.

So the overlay **is** the real minimap, moved and scaled. What FarmMap can do is
be surgical about *how much* of it moves, which is what the two modes are:

- **`map` (default)** moves and scales `Minimap` alone. The zone name, the
  clock and the tracking button stay in the corner. Minimap buttons are hidden
  while you fly, so what lands in the middle of your screen is just terrain and
  gathering nodes. This is as close to "only the inside" as the API allows.
- **`cluster`** moves the whole `MinimapCluster`, furniture and all. This is the
  original behaviour, kept because it looks good if you like the buttons ringing
  the big map.

## How it works

In both modes FarmMap **scales** and never resizes. Pin addons place their nodes
from `Minimap:GetWidth()` (GatherMate2 does exactly this, in `Display.lua`), so
changing that width would scatter every gathering pin. Scaling leaves the maths
untouched and carries the pins along at the new size for free. This is also how
Leatrix_Plus sizes the minimap, so it is a well-trodden path on current retail.

Scale is relative to the parent, so map mode divides out whatever scale the
cluster already carries. That means `size 900` is 900 on screen whether or not
you have moved Edit Mode's minimap size slider.

Everything that gets changed is read back first and restored verbatim: scale,
alpha, the clamped-to-screen flag, every anchor point including which frame it
was relative to, which frames had mouse and wheel input, and which buttons were
showing.

Mouse input is switched off across the moved frame while the overlay is up, so
it never eats clicks, drags or scroll, and camera and character control work
straight through it.

Edit Mode owns the minimap anchors and can re-apply them underneath an addon.
FarmMap does not fight it: a 0.25s ticker notices drift and re-asserts, and
opening Edit Mode restores the minimap immediately and holds off until it closes.
The same ticker is a safety net for any mount or form change that does not fire
an event.

Travel forms treated as mounted, from `GetShapeshiftFormID()`: `3` Travel,
`4` Aquatic, `27` Swift Flight, `29` Flight.

## The icon

`FarmMap/Media/farmmap-icon.tga` is generated from `art/farmmap-icon-source.png`.
The client cannot read PNG, so the source is keyed and converted:

```bash
python tools/make_icon.py art/farmmap-icon-source.png
```

The art is an opaque medallion on black. Keying every dark pixel would punch
holes in the artwork's own outlines, so the converter flood fills inwards from
the four corners: only black connected to the edge becomes transparent.

## Tests

The real addon files are driven headlessly against a stub of the WoW API
(`lupa`, a real Lua runtime): mount, dismount, all four travel forms, non-travel
forms, missed events, mode switching mid-flight, Edit Mode drift, the minimap
button, every slash command, SavedVariables migration and logout. The core
assertion is a diff proving the minimap is restored exactly.

```bash
python -m venv .venv && .venv/Scripts/pip install lupa pillow && .venv/Scripts/python tests/run.py
```

## Known limits

- A gathering pin created *while* the overlay is already up keeps its mouse
  input, so it can still take a click. Pins that existed before it are handled.
- Minimap buttons are hidden while farming, by design. Turn it off with
  `/farmmap buttons` if you would rather they came along to the middle.
- In map mode the minimap's ring border may stay behind in the corner, since it
  belongs to the cluster rather than to the map. Switch to `cluster` mode if you
  want the framed look.
- `/farmmap reset` restores the minimap, but if you are still mounted the
  overlay comes back within 0.25s. Use `/farmmap` to actually turn it off.
