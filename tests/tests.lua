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

--------------------------------------------------------------------------------
-- 1. Load and defaults
--------------------------------------------------------------------------------
fire("ADDON_LOADED", "FarmMap")
check("default enabled", FarmMapDB.enabled == true)
check("default size 900", FarmMapDB.size == 900, FarmMapDB.size)
check("default alpha 0.6", FarmMapDB.alpha == 0.6, FarmMapDB.alpha)
check("default mode map", FarmMapDB.mode == "map", FarmMapDB.mode)
check("default hideButtons", FarmMapDB.hideButtons == true)
check("default hudScale 1", FarmMapDB.hudScale == 1.0, FarmMapDB.hudScale)

fire("PLAYER_LOGIN")
check("minimap button built", ns.button ~= nil)
check("button parented to Minimap", ns.button and ns.button.parent == Minimap)
check("options panel built", ns.panel ~= nil)
check("panel starts hidden", ns.panel and ns.panel.shown == false)

local baseline = STUB.Snapshot()
check("idle: minimap untouched", Minimap.scale == 1)
check("idle: cluster untouched", MinimapCluster.scale == 1)

--------------------------------------------------------------------------------
-- 2. Map mode: only the map circle moves
--------------------------------------------------------------------------------
STUB.mounted = true
fire("PLAYER_MOUNT_DISPLAY_CHANGED")
check("map mode: minimap scales", math.abs(Minimap.scale - (900 / 198)) < 0.0001, Minimap.scale)
check("map mode: CLUSTER left alone", MinimapCluster.scale == 1, MinimapCluster.scale)
check("map mode: cluster keeps its corner anchor",
	select(1, MinimapCluster:GetPoint(1)) == "TOPRIGHT", select(1, MinimapCluster:GetPoint(1)))
local p, rel = Minimap:GetPoint(1)
check("map mode: minimap centred on UIParent", p == "CENTER" and rel == UIParent, tostring(p))
check("map mode: alpha applied to minimap", Minimap.alpha == 0.6, Minimap.alpha)
check("map mode: cluster alpha untouched", MinimapCluster.alpha == 1, MinimapCluster.alpha)
check("map mode: Minimap width untouched", Minimap.width == 198, Minimap.width)

-- Furniture versus pins
check("addon button hidden while farming", AddonButton.shown == false)
check("calendar button hidden while farming", CalendarButton.shown == false)
check("GATHERING PIN STAYS VISIBLE", GatherPin.shown == true)
check("cluster header stays in the corner", ClusterHeader.shown == true)
check("farmmap button hidden while farming", ns.button.shown == false)

-- Mouse
check("minimap mouse off", Minimap.mouse == false)
check("minimap wheel off", Minimap.wheel == false)
check("pin mouse off", GatherPin.mouse == false)
check("cluster mouse untouched in map mode", MinimapCluster.mouse == true)

--------------------------------------------------------------------------------
-- 3. Dismount restores exactly
--------------------------------------------------------------------------------
STUB.mounted = false
fire("PLAYER_MOUNT_DISPLAY_CHANGED")
check("dismount restores exactly", #STUB.Diff(baseline, STUB.Snapshot()) == 0,
	diffStr(baseline, STUB.Snapshot()))
check("farmmap button comes back", ns.button.shown == true)

--------------------------------------------------------------------------------
-- 4. Cluster mode still works
--------------------------------------------------------------------------------
ns.SetMode("cluster")
STUB.mounted = true
STUB.Tick()
check("cluster mode: cluster scales", MinimapCluster.scale > 1.5, MinimapCluster.scale)
check("cluster mode: minimap scale untouched", Minimap.scale == 1, Minimap.scale)
STUB.mounted = false
STUB.Tick()
check("cluster mode restores exactly", #STUB.Diff(baseline, STUB.Snapshot()) == 0,
	diffStr(baseline, STUB.Snapshot()))
ns.SetMode("map")

--------------------------------------------------------------------------------
-- 5. Switching mode WHILE the overlay is up must not strand the old target
--------------------------------------------------------------------------------
STUB.mounted = true
STUB.Tick()
check("pre-switch: minimap is the target", Minimap.scale > 1.5)
ns.SetMode("cluster")
check("switch restores the minimap", Minimap.scale == 1, Minimap.scale)
check("switch moves the cluster", MinimapCluster.scale > 1.5, MinimapCluster.scale)
ns.SetMode("map")
check("switch back restores the cluster", MinimapCluster.scale == 1, MinimapCluster.scale)
STUB.mounted = false
STUB.Tick()
check("after mode churn, restore is still exact", #STUB.Diff(baseline, STUB.Snapshot()) == 0,
	diffStr(baseline, STUB.Snapshot()))

--------------------------------------------------------------------------------
-- 6. hideButtons off leaves the furniture alone
--------------------------------------------------------------------------------
ns.SetHideButtons(false)
STUB.mounted = true
STUB.Tick()
check("hideButtons off: addon button stays", AddonButton.shown == true)
check("hideButtons off: farmmap button stays", ns.button.shown == true)
STUB.mounted = false
STUB.Tick()
ns.SetHideButtons(true)
check("hideButtons toggle restores exactly", #STUB.Diff(baseline, STUB.Snapshot()) == 0,
	diffStr(baseline, STUB.Snapshot()))

--------------------------------------------------------------------------------
-- 7. Druid forms
--------------------------------------------------------------------------------
for _, form in ipairs({ 3, 4, 27, 29 }) do
	STUB.form = form
	fire("UPDATE_SHAPESHIFT_FORM")
	check("form " .. form .. " shows overlay", Minimap.scale > 1.5, Minimap.scale)
	STUB.form = nil
	fire("UPDATE_SHAPESHIFT_FORM")
	check("leaving form " .. form .. " restores", #STUB.Diff(baseline, STUB.Snapshot()) == 0)
end

for _, form in ipairs({ 1, 5, 31 }) do
	STUB.form = form
	fire("UPDATE_SHAPESHIFT_FORM")
	check("form " .. form .. " stays hidden", Minimap.scale == 1, Minimap.scale)
end
STUB.form = nil

--------------------------------------------------------------------------------
-- 8. Ticker safety net and Edit Mode drift
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
check("ticker catches a missed dismount", #STUB.Diff(baseline, STUB.Snapshot()) == 0,
	diffStr(baseline, STUB.Snapshot()))

--------------------------------------------------------------------------------
-- 9. Minimap button behaviour
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

-- Drag around the ring
ns.button.scripts.OnDragStart(ns.button)
STUB.cursor = { 620, 380 }
ns.button.scripts.OnUpdate(ns.button)
local angleA = FarmMapDB.button.angle
STUB.cursor = { 500, 500 }
ns.button.scripts.OnUpdate(ns.button)
ns.button.scripts.OnDragStop(ns.button)
check("drag changes the saved angle", FarmMapDB.button.angle ~= angleA, FarmMapDB.button.angle)
check("drag stops cleanly", ns.button.scripts.OnUpdate == nil)

--------------------------------------------------------------------------------
-- 10. HUD scale
--------------------------------------------------------------------------------
ns.SetHudScale(2)
check("hud scale on button", ns.button.scale == 2, ns.button.scale)
check("hud scale on panel", ns.panel.scale == 2, ns.panel.scale)
check("hud scale does not touch the map", Minimap.scale == 1, Minimap.scale)
ns.SetHudScale(1)

--------------------------------------------------------------------------------
-- 11. Slash commands
--------------------------------------------------------------------------------
STUB.Slash("")
check("slash toggle off", FarmMapDB.enabled == false)
STUB.Slash("")
check("slash toggle on", FarmMapDB.enabled == true)

STUB.Slash("test")
check("slash test shows overlay", Minimap.scale > 1.5, Minimap.scale)
STUB.Slash("test")
check("slash test off restores", #STUB.Diff(baseline, STUB.Snapshot()) == 0)

STUB.Slash("mode cluster")
check("slash mode cluster", FarmMapDB.mode == "cluster")
STUB.Slash("mode map")
check("slash mode map", FarmMapDB.mode == "map")
STUB.Slash("mode banana")
check("slash mode rejects nonsense", FarmMapDB.mode == "map")

STUB.Slash("buttons")
check("slash buttons toggles", FarmMapDB.hideButtons == false)
STUB.Slash("buttons")
check("slash buttons toggles back", FarmMapDB.hideButtons == true)

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
STUB.Slash("hud 99")
check("slash hud rejects out of range", FarmMapDB.hudScale == 2)
ns.SetHudScale(1)

STUB.Slash("config")
check("slash config opens panel", ns.panel.shown == true)
STUB.Slash("config")
check("slash config closes panel", ns.panel.shown == false)

STUB.Slash("status")
STUB.Slash("gibberish")
check("unknown command does not error", true)

STUB.mounted = true
STUB.Tick()
check("size 500 applied live", math.abs(Minimap.scale - (500 / 198)) < 0.0001, Minimap.scale)
check("alpha 0.45 applied live", Minimap.alpha == 0.45, Minimap.alpha)

STUB.Slash("reset")
check("reset restores while mounted", #STUB.Diff(baseline, STUB.Snapshot()) == 0,
	diffStr(baseline, STUB.Snapshot()))

--------------------------------------------------------------------------------
-- 12. Edit Mode and logout
--------------------------------------------------------------------------------
STUB.mounted = true
STUB.Tick()
check("overlay up before edit mode", Minimap.scale > 1.5)
EditModeManagerFrame.scripts.OnShow(EditModeManagerFrame)
check("edit mode opening restores", #STUB.Diff(baseline, STUB.Snapshot()) == 0,
	diffStr(baseline, STUB.Snapshot()))
EditModeManagerFrame:Show()
STUB.Tick()
check("does not re-show while edit mode open", Minimap.scale == 1, Minimap.scale)
EditModeManagerFrame:Hide()

STUB.mounted = true
STUB.Tick()
fire("PLAYER_LOGOUT")
check("logout restores", #STUB.Diff(baseline, STUB.Snapshot()) == 0,
	diffStr(baseline, STUB.Snapshot()))

--------------------------------------------------------------------------------
-- 13. Edit Mode minimap size slider must not compound with ours
--------------------------------------------------------------------------------
MinimapCluster.scale = 1.5   -- as if the player enlarged the minimap in Edit Mode
local editBaseline = STUB.Snapshot()
STUB.mounted = true
STUB.Tick()
local onScreen = Minimap.width * Minimap.scale * MinimapCluster.scale
check("map mode honours the requested on-screen size", math.abs(onScreen - FarmMapDB.size) < 0.5, onScreen)
STUB.mounted = false
STUB.Tick()
check("restores onto an Edit Mode scaled cluster", #STUB.Diff(editBaseline, STUB.Snapshot()) == 0,
	diffStr(editBaseline, STUB.Snapshot()))
MinimapCluster.scale = 1

--------------------------------------------------------------------------------
-- 14. SavedVariables migration. Runs last because it rewrites the DB.
--------------------------------------------------------------------------------
-- An existing v1 profile gets doubled once, and only once.
FarmMapDB = { enabled = true, size = 450, alpha = 0.6, button = {} }
fire("ADDON_LOADED", "FarmMap")
check("v1 profile is doubled to 900", FarmMapDB.size == 900, FarmMapDB.size)
check("migration stamps a version", FarmMapDB.dbVersion == 2, FarmMapDB.dbVersion)
fire("ADDON_LOADED", "FarmMap")
check("migration does not run twice", FarmMapDB.size == 900, FarmMapDB.size)

-- A custom size is doubled too, and clamped at the ceiling.
FarmMapDB = { size = 1000, button = {} }
fire("ADDON_LOADED", "FarmMap")
check("a big custom size clamps at 1600", FarmMapDB.size == 1600, FarmMapDB.size)

-- A brand new install must take the new default, NOT double it.
FarmMapDB = nil
fire("ADDON_LOADED", "FarmMap")
check("fresh install gets 900, not 1800", FarmMapDB.size == 900, FarmMapDB.size)
check("fresh install is stamped", FarmMapDB.dbVersion == 2)

FM_RESULT = { passes = passes, fails = table.concat(fails, "\n") }
