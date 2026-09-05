-- Drives FarmMap through the real farming lifecycle against the stub.
local fails, passes = {}, 0

local function check(label, cond, extra)
	if cond then
		passes = passes + 1
	else
		table.insert(fails, label .. (extra and ("  [" .. tostring(extra) .. "]") or ""))
	end
end

local ns = FM_NS
local ev = FM_EVENT_FRAME
local function fire(event, arg1)
	ev.scripts.OnEvent(ev, event, arg1)
end
local function diffStr(a, b)
	return table.concat(STUB.Diff(a, b), "; ")
end
local function restored(baseline, label)
	local now = STUB.Snapshot()
	check(label, #STUB.Diff(baseline, now) == 0, diffStr(baseline, now))
end

--------------------------------------------------------------------------------
-- 1. Load and defaults
--------------------------------------------------------------------------------
fire("ADDON_LOADED", "FarmMap")
check("default enabled", FarmMapDB.enabled == true)
check("default size 900", FarmMapDB.size == 900, FarmMapDB.size)
check("default alpha 0.6", FarmMapDB.alpha == 0.6, FarmMapDB.alpha)
check("default mode map", FarmMapDB.mode == "map", FarmMapDB.mode)
check("default docks buttons rather than hiding", FarmMapDB.hideButtons == false)
check("default ring on", FarmMapDB.ring == true)
check("default hudScale 1", FarmMapDB.hudScale == 1.0, FarmMapDB.hudScale)

fire("PLAYER_LOGIN")
check("dock built", ns.dock ~= nil)
check("dock starts hidden", ns.dock and ns.dock.shown == false)
check("minimap button built", ns.button ~= nil)
check("options panel built", ns.panel ~= nil)

local baseline = STUB.Snapshot()
check("idle: minimap untouched", Minimap.scale == 1)
check("idle: cluster untouched", MinimapCluster.scale == 1)

--------------------------------------------------------------------------------
-- 2. Classification, the thing that went wrong on screen
--------------------------------------------------------------------------------
check("LibDBIcon button is furniture", ns.IsFurniture(AddonButton) == true)
check("unrecognised ring button is furniture (geometry)", ns.IsFurniture(StrayButton) == true)
check("named Blizzard button is furniture", ns.IsFurniture(CalendarButton) == true)
check("gathering pin is NOT furniture", ns.IsFurniture(GatherPin) == false)
check("EDGE CLAMPED PIN IS NOT FURNITURE", ns.IsFurniture(ClampedPin) == false)
check("unnamed child is NOT furniture", ns.IsFurniture(UnnamedChild) == false)
check("our own button is furniture", ns.IsFurniture(ns.button) == true)

--------------------------------------------------------------------------------
-- 3. Map mode: content goes to the centre, furniture stays in the corner
--------------------------------------------------------------------------------
STUB.mounted = true
fire("PLAYER_MOUNT_DISPLAY_CHANGED")

check("minimap scales", math.abs(Minimap.scale - (900 / 198)) < 0.0001, Minimap.scale)
check("cluster left alone", MinimapCluster.scale == 1, MinimapCluster.scale)
local p, rel = Minimap:GetPoint(1)
check("minimap centred on UIParent", p == "CENTER" and rel == UIParent, tostring(p))
check("Minimap width untouched", Minimap.width == 198, Minimap.width)

-- The dock stands in for the minimap
check("dock shown", ns.dock.shown == true)
check("dock matches the minimap size", ns.dock.width == 198, ns.dock.width)
check("dock takes the minimap's old anchor", STUB.AnchorName(ns.dock) == "MinimapCluster",
	STUB.AnchorName(ns.dock))
check("ring texture shown", ns.dock.ring.shown == true)

-- Furniture is docked: same corner, normal size, still usable
for label, frame in pairs({ addonBtn = AddonButton, strayBtn = StrayButton, calendar = CalendarButton }) do
	check(label .. " re-anchored to the dock", STUB.AnchorName(frame) == "FarmMapDock",
		STUB.AnchorName(frame))
	check(label .. " detached from the map scale", frame.ignoreScale == true)
	check(label .. " detached from the map alpha", frame.ignoreAlpha == true)
	check(label .. " still visible", frame.shown == true)
	check(label .. " STILL CLICKABLE", frame.mouse == true)
end
check("our button docked too", STUB.AnchorName(ns.button) == "FarmMapDock", STUB.AnchorName(ns.button))
check("our button still clickable", ns.button.mouse == true)

-- Map content travels with the map and stops taking mouse input
check("gathering pin still anchored to the map", STUB.AnchorName(GatherPin) == "Minimap")
check("gathering pin still visible", GatherPin.shown == true)
check("gathering pin mouse off", GatherPin.mouse == false)
check("CLAMPED PIN TRAVELS WITH THE MAP", STUB.AnchorName(ClampedPin) == "Minimap",
	STUB.AnchorName(ClampedPin))
check("unnamed child travels with the map", STUB.AnchorName(UnnamedChild) == "Minimap")
check("minimap mouse off", Minimap.mouse == false)
check("minimap wheel off", Minimap.wheel == false)

--------------------------------------------------------------------------------
-- 4. Dismount restores exactly
--------------------------------------------------------------------------------
STUB.mounted = false
fire("PLAYER_MOUNT_DISPLAY_CHANGED")
restored(baseline, "dismount restores exactly")
check("dock hidden again", ns.dock.shown == false)
check("button back on the minimap", STUB.AnchorName(ns.button) == "Minimap", STUB.AnchorName(ns.button))

--------------------------------------------------------------------------------
-- 5. Hiding furniture instead of docking
--------------------------------------------------------------------------------
ns.SetHideButtons(true)
STUB.mounted = true
STUB.Tick()
check("hide mode: addon button hidden", AddonButton.shown == false)
check("hide mode: stray button hidden", StrayButton.shown == false)
check("hide mode: gathering pin still visible", GatherPin.shown == true)
check("hide mode: clamped pin still visible", ClampedPin.shown == true)
check("hide mode: dock not used", ns.dock.shown == false)
STUB.mounted = false
STUB.Tick()
ns.SetHideButtons(false)
restored(baseline, "hide mode restores exactly")

--------------------------------------------------------------------------------
-- 6. Ring toggle
--------------------------------------------------------------------------------
STUB.mounted = true
STUB.Tick()
ns.SetRing(false)
check("ring can be turned off live", ns.dock.ring.shown == false)
ns.SetRing(true)
check("ring can be turned back on", ns.dock.ring.shown == true)
STUB.mounted = false
STUB.Tick()

--------------------------------------------------------------------------------
-- 7. Cluster mode
--------------------------------------------------------------------------------
ns.SetMode("cluster")
STUB.mounted = true
STUB.Tick()
check("cluster mode: cluster scales", MinimapCluster.scale > 1.5, MinimapCluster.scale)
check("cluster mode: minimap scale untouched", Minimap.scale == 1, Minimap.scale)
check("cluster mode: nothing is docked", STUB.AnchorName(AddonButton) == "Minimap")
STUB.mounted = false
STUB.Tick()
restored(baseline, "cluster mode restores exactly")
ns.SetMode("map")

--------------------------------------------------------------------------------
-- 8. Switching mode WHILE the overlay is up must not strand anything
--------------------------------------------------------------------------------
STUB.mounted = true
STUB.Tick()
check("pre-switch: minimap is the target", Minimap.scale > 1.5)
ns.SetMode("cluster")
check("switch restores the minimap", Minimap.scale == 1, Minimap.scale)
check("switch undocks the furniture", STUB.AnchorName(AddonButton) == "Minimap")
check("switch moves the cluster", MinimapCluster.scale > 1.5, MinimapCluster.scale)
ns.SetMode("map")
check("switch back restores the cluster", MinimapCluster.scale == 1, MinimapCluster.scale)
STUB.mounted = false
STUB.Tick()
restored(baseline, "after mode churn, restore is still exact")

--------------------------------------------------------------------------------
-- 9. Druid forms
--------------------------------------------------------------------------------
for _, form in ipairs({ 3, 4, 27, 29 }) do
	STUB.form = form
	fire("UPDATE_SHAPESHIFT_FORM")
	check("form " .. form .. " shows overlay", Minimap.scale > 1.5, Minimap.scale)
	STUB.form = nil
	fire("UPDATE_SHAPESHIFT_FORM")
	restored(baseline, "leaving form " .. form .. " restores")
end

for _, form in ipairs({ 1, 5, 31 }) do
	STUB.form = form
	fire("UPDATE_SHAPESHIFT_FORM")
	check("form " .. form .. " stays hidden", Minimap.scale == 1, Minimap.scale)
end
STUB.form = nil

--------------------------------------------------------------------------------
-- 10. Ticker safety net and Edit Mode drift
--------------------------------------------------------------------------------
STUB.mounted = true
STUB.Tick()
check("ticker catches a missed mount", Minimap.scale > 1.5)

Minimap:ClearAllPoints()
Minimap:SetPoint("CENTER", MinimapCluster, "CENTER", 0, -10)
STUB.Tick()
local dp, dr = Minimap:GetPoint(1)
check("re-asserts after drift", dp == "CENTER" and dr == UIParent, tostring(dr and dr.name))

STUB.mounted = false
STUB.Tick()
restored(baseline, "ticker catches a missed dismount")

--------------------------------------------------------------------------------
-- 11. Minimap button behaviour
--------------------------------------------------------------------------------
ns.button.scripts.OnClick(ns.button, "LeftButton")
check("left click disables", FarmMapDB.enabled == false)
ns.button.scripts.OnClick(ns.button, "LeftButton")
check("left click re-enables", FarmMapDB.enabled == true)

ns.button.scripts.OnClick(ns.button, "RightButton")
check("right click opens options", ns.panel.shown == true)
ns.button.scripts.OnClick(ns.button, "RightButton")
check("right click closes options", ns.panel.shown == false)

ns.button.scripts.OnEnter(ns.button)
ns.button.scripts.OnLeave(ns.button)
check("tooltip handlers do not error", true)

ns.button.scripts.OnDragStart(ns.button)
STUB.cursor = { 620, 380 }
ns.button.scripts.OnUpdate(ns.button)
local angleA = FarmMapDB.button.angle
STUB.cursor = { 500, 500 }
ns.button.scripts.OnUpdate(ns.button)
ns.button.scripts.OnDragStop(ns.button)
check("drag changes the saved angle", FarmMapDB.button.angle ~= angleA, FarmMapDB.button.angle)
check("drag stops cleanly", ns.button.scripts.OnUpdate == nil)

-- Dragging while docked must orbit the dock, not the centred map
STUB.mounted = true
STUB.Tick()
ns.button.scripts.OnDragStart(ns.button)
STUB.cursor = { 560, 400 }
ns.button.scripts.OnUpdate(ns.button)
ns.button.scripts.OnDragStop(ns.button)
check("drag while docked keeps the button on the dock",
	STUB.AnchorName(ns.button) == "FarmMapDock", STUB.AnchorName(ns.button))
STUB.mounted = false
STUB.Tick()

--------------------------------------------------------------------------------
-- 12. HUD scale
--------------------------------------------------------------------------------
ns.SetHudScale(2)
check("hud scale on button", ns.button.scale == 2, ns.button.scale)
check("hud scale on panel", ns.panel.scale == 2, ns.panel.scale)
check("hud scale does not touch the map", Minimap.scale == 1, Minimap.scale)
ns.SetHudScale(1)

--------------------------------------------------------------------------------
-- 13. Slash commands
--------------------------------------------------------------------------------
STUB.Slash("")
check("slash toggle off", FarmMapDB.enabled == false)
STUB.Slash("")
check("slash toggle on", FarmMapDB.enabled == true)

STUB.Slash("test")
check("slash test shows overlay", Minimap.scale > 1.5, Minimap.scale)
STUB.Slash("test")
restored(baseline, "slash test off restores")

STUB.Slash("mode cluster")
check("slash mode cluster", FarmMapDB.mode == "cluster")
STUB.Slash("mode map")
check("slash mode map", FarmMapDB.mode == "map")
STUB.Slash("mode banana")
check("slash mode rejects nonsense", FarmMapDB.mode == "map")

STUB.Slash("buttons")
check("slash buttons toggles", FarmMapDB.hideButtons == true)
STUB.Slash("buttons")
check("slash buttons toggles back", FarmMapDB.hideButtons == false)

STUB.Slash("ring")
check("slash ring toggles", FarmMapDB.ring == false)
STUB.Slash("ring")
check("slash ring toggles back", FarmMapDB.ring == true)

STUB.Slash("size 500")
check("slash size", FarmMapDB.size == 500, FarmMapDB.size)
STUB.Slash("size 99999")
check("slash size rejects out of range", FarmMapDB.size == 500)
STUB.Slash("alpha 0.45")
check("slash alpha", FarmMapDB.alpha == 0.45)
STUB.Slash("alpha 7")
check("slash alpha rejects out of range", FarmMapDB.alpha == 0.45)
STUB.Slash("hud 2")
check("slash hud", FarmMapDB.hudScale == 2)
ns.SetHudScale(1)

STUB.Slash("config")
check("slash config opens panel", ns.panel.shown == true)
STUB.Slash("config")
check("slash config closes panel", ns.panel.shown == false)

STUB.Slash("dump")
check("dump does not error", true)
STUB.Slash("status")
STUB.Slash("gibberish")
check("unknown command does not error", true)

STUB.mounted = true
STUB.Tick()
check("size 500 applied live", math.abs(Minimap.scale - (500 / 198)) < 0.0001, Minimap.scale)
check("alpha 0.45 applied live", Minimap.alpha == 0.45, Minimap.alpha)

STUB.Slash("reset")
restored(baseline, "reset restores while mounted")

--------------------------------------------------------------------------------
-- 14. Edit Mode and logout
--------------------------------------------------------------------------------
STUB.mounted = true
STUB.Tick()
check("overlay up before edit mode", Minimap.scale > 1.5)
EditModeManagerFrame.scripts.OnShow(EditModeManagerFrame)
restored(baseline, "edit mode opening restores")
EditModeManagerFrame:Show()
STUB.Tick()
check("does not re-show while edit mode open", Minimap.scale == 1, Minimap.scale)
EditModeManagerFrame:Hide()

STUB.mounted = true
STUB.Tick()
fire("PLAYER_LOGOUT")
restored(baseline, "logout restores")

--------------------------------------------------------------------------------
-- 15. Edit Mode minimap size slider must not compound with ours
--------------------------------------------------------------------------------
MinimapCluster.scale = 1.5
local editBaseline = STUB.Snapshot()
STUB.mounted = true
STUB.Tick()
local onScreen = Minimap.width * Minimap.scale * MinimapCluster.scale
check("map mode honours the requested on-screen size", math.abs(onScreen - FarmMapDB.size) < 0.5, onScreen)
STUB.mounted = false
STUB.Tick()
restored(editBaseline, "restores onto an Edit Mode scaled cluster")
MinimapCluster.scale = 1

--------------------------------------------------------------------------------
-- 16. SavedVariables migration. Runs last because it rewrites the DB.
--------------------------------------------------------------------------------
-- A v1 profile: size doubled once, and moved off hidden buttons.
FarmMapDB = { enabled = true, size = 450, alpha = 0.6, button = {} }
fire("ADDON_LOADED", "FarmMap")
check("v1 size doubled to 900", FarmMapDB.size == 900, FarmMapDB.size)
check("v1 stamped at version 3", FarmMapDB.dbVersion == 3, FarmMapDB.dbVersion)
fire("ADDON_LOADED", "FarmMap")
check("migration does not run twice", FarmMapDB.size == 900, FarmMapDB.size)

-- A v2 profile: size already doubled, but it hid the buttons. Move it to docking.
FarmMapDB = { dbVersion = 2, size = 900, hideButtons = true, button = {} }
fire("ADDON_LOADED", "FarmMap")
check("v2 size left alone", FarmMapDB.size == 900, FarmMapDB.size)
check("v2 moved onto docking", FarmMapDB.hideButtons == false)

-- A custom size is doubled too, and clamped at the ceiling.
FarmMapDB = { size = 1000, button = {} }
fire("ADDON_LOADED", "FarmMap")
check("a big custom size clamps at 1600", FarmMapDB.size == 1600, FarmMapDB.size)

-- A brand new install must take the new defaults, NOT migrate them.
FarmMapDB = nil
fire("ADDON_LOADED", "FarmMap")
check("fresh install gets 900, not 1800", FarmMapDB.size == 900, FarmMapDB.size)
check("fresh install docks buttons", FarmMapDB.hideButtons == false)
check("fresh install is stamped", FarmMapDB.dbVersion == 3)

FM_RESULT = { passes = passes, fails = table.concat(fails, "\n") }
