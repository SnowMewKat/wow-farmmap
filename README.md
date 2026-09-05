# FarmMap

A small, dependency-free WoW Retail addon.

While you are mounted or in Druid Travel / Flight Form, FarmMap moves the
minimap's gathering nodes to the centre of your screen, large, with the map
terrain faded out. The nodes are the only thing you have to look at, and there
is no scrolling map underneath to make you motion sick. Everything goes back to
normal the moment you dismount.

Built and verified against **retail 12.1.0** (`## Interface: 120100`).

## Install

Grab the zip from `dist/` and unzip it into:

```
World of Warcraft/_retail_/Interface/AddOns/
```

You should end up with `Interface/AddOns/FarmMap/FarmMap.toc`.

## Working on it

The source lives here and the game reads it through a directory junction, so
there is no copy step: edit a file, `/reload` in game, done.

On Hades (the Windows desktop) that junction already exists:

```
C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\FarmMap
  -> C:\Users\setos\OneDrive\Desktop\Claude Code\wow-farmmap\FarmMap
```

### On the other machine

The repo is the only thing that travels, so start by cloning it:

```bash
git clone https://github.com/SnowMewKat/wow-farmmap.git
```

Then point the game at it. On Windows, a junction needs no admin rights:

```bash
cmd /c mklink /J "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\FarmMap" "<repo>\FarmMap"
```

On macOS:

```bash
ln -s "<repo>/FarmMap" "/Applications/World of Warcraft/_retail_/Interface/AddOns/FarmMap"
```

Everything needed to rebuild the artwork and run the tests is committed, so a
fresh clone is self-sufficient. That is checked by cloning it and running the
suite from the clone, not assumed.

## Using it

A button appears on your minimap. **Left click** toggles FarmMap on and off,
**right click** opens the options, and you can **drag** it around the ring.

| Command | Effect |
|---|---|
| `/farmmap` | Toggle on and off |
| `/farmmap config` | Open the options panel |
| `/farmmap nodes` | Nodes only: fade the map, keep the blips |
| `/farmmap size 900` | Width of the node view, 100 to 1600 |
| `/farmmap alpha 0.1` | Map opacity, 0.05 to 1.0 |
| `/farmmap hud 1.0` | Scale of FarmMap's own button and panel |
| `/farmmap mode map` | Move only the map contents (default) |
| `/farmmap mode cluster` | Move the whole minimap, zone text and buttons included |
| `/farmmap art` | Show or hide the compass and border rings while flying |
| `/farmmap test` | Force the overlay on, ignoring mount state |
| `/farmmap dump` | List the minimap's children and how each is classified |
| `/farmmap reset` | Put the minimap back right now |
| `/farmmap status` | Print the current state |

The options panel is deliberately six controls: Enabled, Nodes only, Move whole
minimap, Map size, Map opacity, HUD scale. Four more used to live there and
every one of them was a way to make the addon worse, so they moved to chat
where they belong. A test pins the checkbox count so it does not grow back.

Defaults are the settings arrived at by actually farming with it: nodes only at
opacity 0.1, size 900, map mode, compass art hidden.

## Nodes only, which is the point of the whole addon

Drop the map opacity to 0.1 and the terrain fades away, leaving the gathering
blips hanging in space in the middle of the screen.

**Not zero.** Zero fades the blips out along with the terrain and leaves only
the compass ring, a big bright circle around your character. 0.1 is the value
that works, so it is the constant `NODES_ONLY_ALPHA` and the opacity floor is
0.05. FarmMap also hides the compass and border rings while flying, because at
that opacity they are otherwise the loudest thing on screen.

A map scrolling under your character while you fly is a motion sickness machine
and it is visual noise on top of the one thing you actually care about. With it
gone, the ore and herb icons are the only thing there.

## Can it copy the inside of the minimap instead of moving it?

No, and it is worth knowing why, because it shapes the whole design.

The minimap's terrain and its blips are drawn by the **game engine** straight
into the `Minimap` widget. An addon cannot read that back, cannot render it to a
texture, and cannot ask the engine for a second copy. There is nothing to clone.
Creating a second `Minimap` frame does not help either: the gathering blips and
every pin addon are bound to the real one, which is exactly what you need to see.

So the overlay **is** the real minimap, moved and scaled. What FarmMap can do is
be surgical about what comes along.

## How it works

FarmMap **scales** and never resizes. Pin addons place their nodes from
`Minimap:GetWidth()` (GatherMate2 does exactly this, in `Display.lua`), so
changing that width would scatter every gathering pin. Scaling leaves the maths
untouched and carries the pins along at the new size for free.

Scale is relative to the parent, so map mode divides out whatever scale the
cluster already carries. `size 900` is 900 on screen whether or not you have
moved Edit Mode's minimap size slider.

Minimap buttons are children of `Minimap` anchored out on the ring, so scaling
the map would fling them to 4.5x the radius and scatter them across the screen.
They are hidden for the duration instead, and come back on dismount.

### Telling a button apart from a gathering pin

This has to be right, because hiding a gathering pin would defeat the point.
Three tests, in order:

1. **Unnamed?** Then it is map content. Pins are usually created without a name,
   buttons are almost always named.
2. **Does the name look like a pin** (`Pin`, `Node`, `Blip`, `GatherMate`,
   `HandyNotes`, `POI`, `Arrow`)? Then it is map content, no matter where it
   sits. This protects an edge-clamped pin, which sits right on the ring and
   would otherwise look exactly like a button.
3. **Otherwise, where is it?** Anything named and sitting outside the ring
   radius is furniture. This catches addon buttons FarmMap has never heard of,
   which was the real problem: a hardcoded name list missed most of them.

`/farmmap dump` prints the verdict for every child of the minimap, plus its art
layers, so anything misfiled takes one command to name.

### Everything else

Every value that gets changed is read back first and restored verbatim: scale,
alpha, the clamped-to-screen flag, every anchor point including which frame it
was relative to, which frames had mouse and wheel input, and which buttons and
art layers were showing.

Mouse input is switched off across the moved map while the overlay is up, so it
never eats clicks, drags or scroll, and camera and character control work
straight through it.

Edit Mode owns the minimap anchors and can re-apply them underneath an addon.
FarmMap does not fight it: a 0.25s ticker notices drift and re-asserts, and
opening Edit Mode restores the minimap immediately and holds off until it
closes. The same ticker is a safety net for any mount or form change that does
not fire an event.

Travel forms treated as mounted, from `GetShapeshiftFormID()`: `3` Travel,
`4` Aquatic, `27` Swift Flight, `29` Flight.

## The icon

The client cannot read PNG, so the texture is generated from the source art:

```bash
python tools/make_icon.py art/farmmap-icon-source.png
```

The source is an opaque medallion on black. Keying every dark pixel would punch
holes in the artwork's own outlines, so the converter flood fills inwards from
the four corners: only black connected to the edge becomes transparent.

## Tests

The real addon files are driven headlessly against a stub of the WoW API
(`lupa`, a real Lua runtime), with the minimap laid out with real geometry so
the button-versus-pin classification is genuinely exercised. 129 checks covering
mount, dismount, all four travel forms, nodes-only mode, furniture hiding versus
pin survival, the edge-clamped pin case, mode switching mid-flight, Edit Mode
drift and scaling, the minimap button, every slash command, SavedVariables
migration and logout. The core assertion is a diff proving everything is
restored exactly.

```bash
python -m venv .venv
.venv/Scripts/pip install lupa pillow
.venv/Scripts/python tests/run.py
```

## Releasing

Bump `## Version` in `FarmMap/FarmMap.toc`, then:

```bash
python tools/package.py
```

That writes `dist/FarmMap-<version>.zip` with a single top-level `FarmMap`
folder, which is what AddOns expects. The file list is explicit rather than
globbed, so nothing stray can ride along, and the script re-opens the zip
afterwards to check the layout.

## License

MIT, see [LICENSE](LICENSE). It is declared in the TOC as `## X-License: MIT`,
which is where CurseForge reads it from, and a copy ships inside the zip as
`FarmMap/LICENSE.txt` so it travels with what people actually download.

## Known limits

- A gathering pin created *while* the overlay is already up keeps its mouse
  input, so it can still take a click. Pins that existed before it are handled.
- A button dragged inside the ring radius, and not named like a LibDBIcon or a
  Blizzard button, will be treated as map content and travel with the map.
  `/farmmap dump` will show it.
- The compass and border art is hidden by name. If some other ring is still
  drawn over the centre of the screen, `/farmmap dump` lists the minimap's art
  layers, which will name it.
- `/farmmap reset` restores the minimap, but if you are still mounted the
  overlay comes back within 0.25s. Use `/farmmap` to actually turn it off.
