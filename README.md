# FarmMap

A small, dependency-free WoW Retail addon. While you are mounted or in Druid
Travel / Flight Form, it moves the minimap's contents to the centre of the
screen, enlarged, so gathering nodes are front and centre while you fly. Turn the
map opacity to zero and you get the nodes alone, no scrolling terrain. The minimap
buttons stay home in the corner, and everything is put back the moment you dismount.

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

The panel is deliberately five controls: Enabled, Nodes only, Move whole
minimap, Map size, Map opacity, HUD scale. Four more used to live there and
every one of them was a way to make the addon worse, so they moved to chat
where they belong: `/farmmap test`, `buttons`, `art` and `ring`.

| Command | Effect |
|---|---|
| `/farmmap` | Toggle on and off |
| `/farmmap config` | Open the options panel |
| `/farmmap nodes` | Nodes only: hide the map, keep the gathering blips |
| `/farmmap test` | Force the overlay visible, ignoring mount state |
| `/farmmap mode map` | Move only the map contents (default) |
| `/farmmap mode cluster` | Move the whole minimap, zone text and buttons included |
| `/farmmap buttons` | Hide the minimap buttons while flying, or dock them in the corner |
| `/farmmap ring` | Show or hide the corner socket ring |
| `/farmmap art` | Hide or show the compass and border rings while flying |
| `/farmmap size 900` | Width of the map circle in UI units, 100 to 1600 |
| `/farmmap alpha 0.6` | Map opacity, 0.05 to 1.0 |
| `/farmmap hud 1.0` | Scale of FarmMap's own button and panel, 0.5 to 4.0 |
| `/farmmap dump` | List the minimap's children and how each one is classified |
| `/farmmap reset` | Force the minimap back to normal right now |
| `/farmmap status` | Print the current state |

Defaults, which are Snow's settings: enabled, nodes only (opacity 0.1), size
900, map mode, buttons hidden while flying, compass art hidden, corner ring off.

## Nodes only, which is the point of the whole addon

Drop the map opacity to 0.1 and the terrain fades away, leaving the gathering
blips hanging in space in the middle of the screen.

**Not zero.** Zero fades the blips out along with the terrain and leaves only
the compass ring, a big bright circle around your character. 0.1 is the value
that works, so it is the constant `NODES_ONLY_ALPHA` and the opacity floor is
0.05. FarmMap also hides the compass and border rings while flying, because at
that opacity they are otherwise the loudest thing on screen.

This is better than a big translucent map, and not by a small margin. A map
scrolling under your character while you fly is a motion sickness machine, and
it is visual noise on top of the one thing you actually care about. With it
gone, the ore and herb icons are the only thing on screen, exactly where your
eyes already are.

`/farmmap nodes`, or the first checkbox in the options panel. Turning it back
off returns the map to whatever opacity you had before, never to an invisible one.

## Can it copy the inside of the minimap instead of moving it?

No, and it is worth knowing why, because it shapes the whole design.

The minimap's terrain and its blips are drawn by the **game engine** straight
into the `Minimap` widget. An addon cannot read that back, cannot render it to a
texture, and cannot ask the engine for a second copy. There is nothing to clone.
Creating a second `Minimap` frame does not help either: the gathering blips and
every pin addon are bound to the real one, which is exactly what you need to see.

So the overlay **is** the real minimap, moved and scaled. What FarmMap can do is
be surgical about *what comes along*, which is the whole trick in map mode.

## Docking, and why it exists

Minimap buttons are children of `Minimap`, anchored out on the ring. Scale the
map 4.5x and they fly out to 4.5x the radius, scattering across the screen. That
is exactly what happened on the first attempt.

Hiding them is the default and is what Snow prefers. If you would rather keep
them reachable while flying, `/farmmap buttons` docks them instead. FarmMap
creates a **dock**: an invisible stand-in frame sitting precisely where the
minimap normally is, wearing a gold socket ring so the corner still reads as a
minimap. When the overlay goes up, every button is:

- detached from the map's scale and opacity with `SetIgnoreParentScale` and
  `SetIgnoreParentAlpha`, so it keeps its normal size and stays fully opaque,
- re-anchored from `Minimap` onto the dock, so it does not move,
- left **clickable**, because it is in the corner where clicking it is the point.

It stays a child of `Minimap` throughout. Nothing an addon believes about its own
button changes, and on dismount every anchor, flag and parent goes back exactly.

### Telling a button apart from a gathering pin

This is the part that has to be right, because docking a gathering pin would
strand a node icon in the corner. Three tests, in order:

1. **Unnamed?** Then it is map content. Pins are usually created without a name,
   buttons are almost always named.
2. **Does the name look like a pin** (`Pin`, `Node`, `Blip`, `GatherMate`,
   `HandyNotes`, `POI`, `Arrow`)? Then it is map content, no matter where it sits.
   This is what protects an edge-clamped pin, which sits right on the ring and
   would otherwise look exactly like a button.
3. **Otherwise, where is it?** Anything named and sitting outside the ring radius
   is furniture. This is the test that catches addon buttons FarmMap has never
   heard of, which was the real problem: a hardcoded name list missed most of them.

`/farmmap dump` prints the verdict for every child of the minimap, so if
something is misfiled it takes one command to see it.

## How it works

In both modes FarmMap **scales** and never resizes. Pin addons place their nodes
from `Minimap:GetWidth()` (GatherMate2 does exactly this, in `Display.lua`), so
changing that width would scatter every gathering pin. Scaling leaves the maths
untouched and carries the pins along at the new size for free.

Scale is relative to the parent, so map mode divides out whatever scale the
cluster already carries. That means `size 900` is 900 on screen whether or not
you have moved Edit Mode's minimap size slider.

Everything that gets changed is read back first and restored verbatim: scale,
alpha, the clamped-to-screen flag, every anchor point including which frame it
was relative to, the ignore-parent-scale and ignore-parent-alpha flags, which
frames had mouse and wheel input, and which buttons were showing.

Mouse input is switched off across the moved map while the overlay is up, so it
never eats clicks, drags or scroll, and camera and character control work
straight through it. Docked furniture is deliberately skipped.

Edit Mode owns the minimap anchors and can re-apply them underneath an addon.
FarmMap does not fight it: a 0.25s ticker notices drift and re-asserts, and
opening Edit Mode restores the minimap immediately and holds off until it closes.
The same ticker is a safety net for any mount or form change that does not fire
an event.

Travel forms treated as mounted, from `GetShapeshiftFormID()`: `3` Travel,
`4` Aquatic, `27` Swift Flight, `29` Flight.

## Art

Both textures are generated, because the client cannot read PNG:

```bash
python tools/make_icon.py art/farmmap-icon-source.png   # the minimap button
python tools/make_ring.py                               # the corner socket ring
```

The icon source is an opaque medallion on black. Keying every dark pixel would
punch holes in the artwork's own outlines, so the converter flood fills inwards
from the four corners: only black connected to the edge becomes transparent.

## Tests

The real addon files are driven headlessly against a stub of the WoW API
(`lupa`, a real Lua runtime), with the minimap laid out with real geometry so the
furniture classification is genuinely exercised. 164 checks covering mount,
dismount, all four travel forms, nodes-only mode, docking versus pin survival, the
edge-clamped pin case, mode switching mid-flight, Edit Mode drift and scaling, the
minimap button, every slash command, SavedVariables migration and logout. The core
assertion is a diff proving everything is restored exactly.

```bash
python -m venv .venv && .venv/Scripts/pip install lupa pillow && .venv/Scripts/python tests/run.py
```

## Known limits

- A gathering pin created *while* the overlay is already up keeps its mouse
  input, so it can still take a click. Pins that existed before it are handled.
- A button dragged inside the ring radius, and not named like a LibDBIcon or a
  Blizzard button, will be treated as map content and travel with the map.
  `/farmmap dump` will show it. Tell me the name and it goes on the list.
- Blizzard's own minimap ring belongs to the map, so it travels to the centre.
  The dock draws its own gold ring in its place. Turn that off with
  `/farmmap ring` if you would rather have nothing there.
- `/farmmap reset` restores the minimap, but if you are still mounted the
  overlay comes back within 0.25s. Use `/farmmap` to actually turn it off.
- The compass and border art is hidden by name. If some other ring is still
  drawn over the centre of your screen, `/farmmap dump` now lists the minimap's
  art layers as well as its children, which will name it.
