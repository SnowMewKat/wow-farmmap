"""Headless FarmMap test harness.

    python -m venv .venv
    .venv/Scripts/pip install lupa
    .venv/Scripts/python tests/run.py

Loads the real addon files into a Lua runtime against a stub of the WoW API and
drives them through mount, dismount, travel forms, mode switches, the minimap
button and every slash command, asserting the minimap is restored exactly.
"""
import io
import os
import sys

from lupa import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ADDON_DIR = os.path.join(ROOT, "FarmMap")
FILES = ["FarmMap.lua", "FarmMapUI.lua"]


def read(path):
    return io.open(path, encoding="utf-8").read()


lua = LuaRuntime(unpack_returned_tuples=False)
lua.execute(read(os.path.join(HERE, "wowstub.lua")))

g = lua.globals()

# WoW hands every file in an addon the same two varargs: the addon name and a
# shared private table. Reproduce that exactly.
ns = lua.eval("{}")

event_frame = None
for name in FILES:
    path = os.path.join(ADDON_DIR, name)
    try:
        chunk = lua.compile(read(path))
    except Exception as exc:
        print("SYNTAX ERROR in %s:" % name)
        print(exc)
        sys.exit(1)
    chunk("FarmMap", ns)
    if event_frame is None:
        event_frame = g.STUB.lastCreated
print("syntax: OK (%s)" % ", ".join(FILES))

if event_frame is None:
    print("could not capture the addon event frame")
    sys.exit(1)

g.FM_EVENT_FRAME = event_frame
g.FM_NS = ns

lua.execute(read(os.path.join(HERE, "tests.lua")))

result = g.FM_RESULT
print("passed: %d" % result["passes"])
if result["fails"]:
    print("")
    print("FAILURES:")
    print(result["fails"])
    sys.exit(1)
print("all checks passed")
