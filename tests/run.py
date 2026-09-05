"""Headless FarmMap test harness.

    python -m venv .venv
    .venv/Scripts/pip install lupa
    .venv/Scripts/python tests/run.py

Loads FarmMap.lua into a real Lua runtime against a stub of the WoW API and
drives it through mount, dismount, travel forms, Edit Mode drift and every
slash command, asserting the minimap is restored exactly.
"""
import io
import os
import sys

from lupa import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ADDON = os.path.join(ROOT, "FarmMap", "FarmMap.lua")


def read(path):
    return io.open(path, encoding="utf-8").read()


lua = LuaRuntime(unpack_returned_tuples=False)
lua.execute(read(os.path.join(HERE, "wowstub.lua")))

try:
    chunk = lua.compile(read(ADDON))
except Exception as exc:
    print("SYNTAX ERROR in FarmMap.lua:")
    print(exc)
    sys.exit(1)
print("syntax: OK")

chunk("FarmMap")  # WoW passes the addon name as the chunk vararg

g = lua.globals()
g.FM_EVENT_FRAME = g.STUB.lastCreated
if g.FM_EVENT_FRAME is None:
    print("could not capture the addon event frame")
    sys.exit(1)

lua.execute(read(os.path.join(HERE, "tests.lua")))

result = g.FM_RESULT
print("passed: %d" % result["passes"])
if result["fails"]:
    print("")
    print("FAILURES:")
    print(result["fails"])
    sys.exit(1)
print("all checks passed")
