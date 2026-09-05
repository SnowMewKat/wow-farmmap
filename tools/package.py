"""Build the installable zip.

Produces dist/FarmMap-<version>.zip containing a single top-level FarmMap
folder, which is what WoW's AddOns directory expects: unzip it into
Interface/AddOns and you are done.

The version comes from the .toc, so there is one place to bump it.

    python tools/package.py
"""
import io
import os
import re
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ADDON = os.path.join(ROOT, "FarmMap")
DIST = os.path.join(ROOT, "dist")

# Exactly what ships. Listed rather than globbed, so nothing stray (a backup
# file, an editor swap file, a stale texture) can ride along into a release.
FILES = [
    "FarmMap.toc",
    "FarmMap.lua",
    "FarmMapUI.lua",
    os.path.join("Media", "farmmap-icon.tga"),
]

README = """FarmMap
=======

While you are mounted or in Druid Travel / Flight Form, FarmMap moves the
minimap's gathering nodes to the centre of your screen, large, with the map
terrain faded out. The nodes are the only thing you have to look at, and there
is no scrolling map underneath to make you motion sick. Everything goes back
to normal the moment you dismount.

Install
-------
Unzip into:
  World of Warcraft/_retail_/Interface/AddOns/

You should end up with Interface/AddOns/FarmMap/FarmMap.toc

Using it
--------
A button appears on your minimap. Left click toggles FarmMap on and off,
right click opens the options, and you can drag it around the ring.

  /farmmap            toggle on and off
  /farmmap config     open the options panel
  /farmmap nodes      nodes only: fade the map, keep the blips
  /farmmap size 900   width of the node view, 100 to 1600
  /farmmap alpha 0.1  map opacity, 0.05 to 1.0
  /farmmap hud 1.0    scale of FarmMap's own button and panel
  /farmmap mode       map (default) or cluster
  /farmmap art        show or hide the compass and border rings
  /farmmap test       force the overlay on, for testing
  /farmmap dump       diagnostics, if a button ends up in the wrong place
  /farmmap reset      put the minimap back right now
  /farmmap status     print the current state

Notes
-----
Gathering pins from GatherMate2, HandyNotes and similar addons come along and
stay in the right places. FarmMap scales the minimap rather than resizing it,
which is what keeps their maths correct.

The overlay never takes mouse input, so your camera and character controls
work straight through it.

Requires no other addons. %s
"""


def version():
    toc = io.open(os.path.join(ADDON, "FarmMap.toc"), encoding="utf-8").read()
    match = re.search(r"^## Version:\s*(.+)$", toc, re.M)
    if not match:
        raise SystemExit("no ## Version in FarmMap.toc")
    return match.group(1).strip()


def interface():
    toc = io.open(os.path.join(ADDON, "FarmMap.toc"), encoding="utf-8").read()
    match = re.search(r"^## Interface:\s*(.+)$", toc, re.M)
    return match.group(1).strip() if match else "unknown"


def main():
    ver = version()
    os.makedirs(DIST, exist_ok=True)
    out = os.path.join(DIST, "FarmMap-%s.zip" % ver)

    missing = [f for f in FILES if not os.path.exists(os.path.join(ADDON, f))]
    if missing:
        raise SystemExit("missing from the addon folder: %s" % ", ".join(missing))

    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for rel in FILES:
            z.write(os.path.join(ADDON, rel), "FarmMap/" + rel.replace(os.sep, "/"))
        z.writestr("FarmMap/README.txt",
                   README % ("Built for interface %s." % interface()))
        # The licence lives at the repo root, but it has to travel inside the
        # addon folder or it is not in what anyone actually downloads.
        licence = os.path.join(ROOT, "LICENSE")
        if not os.path.exists(licence):
            raise SystemExit("no LICENSE at the repo root")
        z.write(licence, "FarmMap/LICENSE.txt")

    with zipfile.ZipFile(out) as z:
        names = z.namelist()
        bad = z.testzip()
        if bad:
            raise SystemExit("corrupt entry in the zip: %s" % bad)

    print("wrote %s" % out)
    print("  %d bytes" % os.path.getsize(out))
    for n in sorted(names):
        print("  %s" % n)

    roots = set(n.split("/")[0] for n in names)
    if roots != {"FarmMap"}:
        raise SystemExit("zip must contain exactly one top-level FarmMap folder, got %s" % roots)
    print("  layout OK: one top-level FarmMap folder")


if __name__ == "__main__":
    main()
