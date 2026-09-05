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
check("default alpha is nodes only", FarmMapDB.alpha == 0.1, FarmMapDB.alpha)
check("default IS nodes only", ns.IsNodesOnly() == true)
check("default mode map", FarmMapDB.mode == "map", FarmMapDB.mode)
check("default hides the compass art", FarmMapDB.hideMapArt == true)
check("default hudScale 1", FarmMapDB.hudScale == 1.0, FarmMapDB.hudScale)

fire("PLAYER_LOGIN")
check("minimap button built", ns.button ~= nil)
check("button parented to Minimap", ns.button and ns.button.parent == Minimap)
check("options panel built", ns.panel ~= nil)
check("panel starts hidden", ns.panel and ns.panel.shown == false)

-- The panel is deliberately small. Every extra checkbox that lived here was a
-- way to make the addon worse, so this pins it.
local checkboxes = 0
for _, child in ipairs({ ns.panel:GetChildren() }) do
	if child.frameType == "CheckButton" then checkboxes = checkboxes + 1 end
end
check("panel has exactly three checkboxes", checkboxes == 3, checkboxes)

local baseline = STUB.Snapshot()
check("idle: minimap untouched", Minimap.scale == 1)
check("idle: cluster untouched", MinimapCluster.scale == 1)

--------------------------------------------------------------------------------
-- 2. Classification: buttons versus gathering pins
--------------------------------------------------------------------------------
check("LibDBIcon button is furniture", ns.IsFurniture(AddonButton) == true)
check("unrecognised ring button is furniture (geometry)", ns.IsFurniture(StrayButton) == true)
check("named Blizzard button is furniture", ns.IsFurniture(CalendarButton) == true)
check("gathering pin is NOT furniture", ns.IsFurniture(GatherPin) == false)
check("EDGE CLAMPED PIN IS NOT FURNITURE", ns.IsFurniture(ClampedPin) == false)
check("unnamed child is NOT furniture", ns.IsFurniture(UnnamedChild) == false)
check("our own button is furniture", ns.IsFurniture(ns.button) == true)

--------------------------------------------------------------------------------
-- 3. Map mode: nodes go to the centre, everything else gets out of the way
--------------------------------------------------------------------------------
STUB.mounted = true
fire("PLAYER_MOUNT_DISPLAY_CHANGED")

check("minimap scales", math.abs(Minimap.scale - (900 / 198)) < 0.0001, Minimap.scale)
check("cluster left alone", MinimapCluster.scale == 1, MinimapCluster.scale)
check("cluster keeps its corner anchor",
	select(1, MinimapCluster:GetPoint(1)) == "TOPRIGHT", select(1, MinimapCluster:GetPoint(1)))
local p, rel = Minimap:GetPoint(1)
check("minimap centred on UIParent", p == "CENTER" and rel == UIParent, tostring(p))
check("map faded to the nodes-only value", Minimap.alpha == 0.1, Minimap.alpha)
check("Minimap width untouched", Minimap.width == 198, Minimap.width)

-- Furniture out of the way
check("addon button hidden", AddonButton.shown == false)
check("unrecognised ring button hidden", StrayButton.shown == false)
check("calendar button hidden", CalendarButton.shown == false)
check("our own button hidden", ns.button.shown == false)
check("COMPASS RING HIDDEN", MinimapCompassTexture.shown == false)
check("border ring hidden", MinimapBorder.shown == false)
check("cluster header untouched", ClusterHeader.shown == true)

-- Nodes stay
check("GATHERING PIN STAYS VISIBLE", GatherPin.shown == true)
check("CLAMPED PIN STAYS VISIBLE", ClampedPin.shown == true)
check("unnamed child stays visible", UnnamedChild.shown == true)

-- Mouse
check("minimap mouse off", Minimap.mouse == false)
check("minimap wheel off", Minimap.wheel == false)
check("pin mouse off", GatherPin.mouse == false)
check("cluster mouse untouched in map mode", MinimapCluster.mouse == true)

--------------------------------------------------------------------------------
-- 4. Dismount restores exactly
--------------------------------------------------------------------------------
STUB.mounted = false
fire("PLAYER_MOUNT_DISPLAY_CHANGED")
restored(baseline, "dismount restores exactly")
check("our button comes back", ns.button.shown == true)
check("compass ring comes back", MinimapCompassTexture.shown == true)

--------------------------------------------------------------------------------
-- 5. Leaving the compass art alone is still possible
--------------------------------------------------------------------------------
ns.SetHideMapArt(false)
STUB.mounted = true
STUB.Tick()
check("compass ring left alone when asked", MinimapCompassTexture.shown == true)
check("buttons still hidden regardless", AddonButton.shown == false)
STUB.mounted = false
STUB.Tick()
ns.SetHideMapArt(true)
restored(baseline, "art toggle restores exactly")

--------------------------------------------------------------------------------
-- 6. Cluster mode
--------------------------------------------------------------------------------
ns.SetMode("cluster")
STUB.mounted = true
STUB.Tick()
check("cluster mode: cluster scales", MinimapCluster.scale > 1.5, MinimapCluster.scale)
check("cluster mode: minimap scale untouched", Minimap.scale == 1, Minimap.scale)
check("cluster mode: buttons come along, not hidden", AddonButton.shown == true)
STUB.mounted = false
STUB.Tick()
restored(baseline, "cluster mode restores exactly")
ns.SetMode("map")

--------------------------------------------------------------------------------
-- 7. Switching mode WHILE the overlay is up must not strand anything
--------------------------------------------------------------------------------
STUB.mounted = true
STUB.Tick()
check("pre-switch: minimap is the target", Minimap.scale > 1.5)
ns.SetMode("cluster")
check("switch restores the minimap", Minimap.scale == 1, Minimap.scale)
check("switch brings the buttons back", AddonButton.shown == true)
check("switch moves the cluster", MinimapCluster.scale > 1.5, MinimapCluster.scale)
ns.SetMode("map")
check("switch back restores the cluster", MinimapCluster.scale == 1, MinimapCluster.scale)
STUB.mounted = false
STUB.Tick()
restored(baseline, "after mode churn, restore is still exact")

--------------------------------------------------------------------------------
-- 8. Druid forms
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
-- 9. Ticker safety net and Edit Mode drift
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
-- 10. Minimap button behaviour
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

--------------------------------------------------------------------------------
-- 11. HUD scale
--------------------------------------------------------------------------------
ns.SetHudScale(2)
check("hud scale on button", ns.button.scale == 2, ns.button.scale)
check("hud scale on panel", ns.panel.scale == 2, ns.panel.scale)
check("hud scale does not touch the map", Minimap.scale == 1, Minimap.scale)
ns.SetHudScale(1)

--------------------------------------------------------------------------------
-- 12. Nodes only
--------------------------------------------------------------------------------
ns.SetAlpha(0.45)
check("not nodes only at 0.45", ns.IsNodesOnly() == false)
ns.SetNodesOnly(true)
check("nodes only uses the known-good 0.1", FarmMapDB.alpha == 0.1, FarmMapDB.alpha)
check("previous opacity remembered", FarmMapDB.prevAlpha == 0.45, FarmMapDB.prevAlpha)
ns.SetNodesOnly(false)
check("turning it off restores the old opacity", FarmMapDB.alpha == 0.45, FarmMapDB.alpha)

-- Never come back to a map you cannot see
FarmMapDB.prevAlpha = 0.1
ns.SetNodesOnly(true)
ns.SetNodesOnly(false)
check("never restores into the nodes-only band", FarmMapDB.alpha == 0.6, FarmMapDB.alpha)

-- Opacity zero took the blips with it, so it is floored now
ns.SetAlpha(0)
check("SetAlpha floors at the minimum", FarmMapDB.alpha == 0.05, FarmMapDB.alpha)

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

STUB.Slash("art")
check("slash art toggles", FarmMapDB.hideMapArt == false)
STUB.Slash("art")
check("slash art toggles back", FarmMapDB.hideMapArt == true)

STUB.Slash("size 500")
check("slash size", FarmMapDB.size == 500, FarmMapDB.size)
STUB.Slash("size 99999")
check("slash size rejects out of range", FarmMapDB.size == 500)

ns.SetAlpha(0.45)
STUB.Slash("alpha 0")
check("slash alpha refuses zero", FarmMapDB.alpha == 0.45, FarmMapDB.alpha)
STUB.Slash("alpha 0.5")
check("slash alpha", FarmMapDB.alpha == 0.5)
STUB.Slash("nodes")
check("slash nodes turns it on", FarmMapDB.alpha == 0.1, FarmMapDB.alpha)
STUB.Slash("nodes")
check("slash nodes turns it off", ns.IsNodesOnly() == false, FarmMapDB.alpha)

STUB.Slash("hud 2")
check("slash hud", FarmMapDB.hudScale == 2)
STUB.Slash("hud 99")
check("slash hud rejects out of range", FarmMapDB.hudScale == 2)
ns.SetHudScale(1)

STUB.Slash("config")
check("slash config opens panel", ns.panel.shown == true)
STUB.Slash("config")
check("slash config closes panel", ns.panel.shown == false)

STUB.Slash("dump")
STUB.Slash("status")
STUB.Slash("gibberish")
check("diagnostics and unknown commands do not error", true)

ns.SetSize(900)
ns.SetNodesOnly(true)
STUB.mounted = true
STUB.Tick()
check("size 900 applied live", math.abs(Minimap.scale - (900 / 198)) < 0.0001, Minimap.scale)
check("nodes-only opacity applied live", Minimap.alpha == 0.1, Minimap.alpha)

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
-- A v1 profile: size doubled once.
FarmMapDB = { enabled = true, size = 450, alpha = 0.6, button = {} }
fire("ADDON_LOADED", "FarmMap")
check("v1 size doubled to 900", FarmMapDB.size == 900, FarmMapDB.size)
check("v1 stamped at version 4", FarmMapDB.dbVersion == 4, FarmMapDB.dbVersion)
check("v1 opacity left alone", FarmMapDB.alpha == 0.6, FarmMapDB.alpha)
fire("ADDON_LOADED", "FarmMap")
check("migration does not run twice", FarmMapDB.size == 900, FarmMapDB.size)

-- A later profile is left exactly as the player had it.
FarmMapDB = { dbVersion = 3, size = 700, alpha = 0.35, mode = "cluster", button = {} }
fire("ADDON_LOADED", "FarmMap")
check("size left alone", FarmMapDB.size == 700, FarmMapDB.size)
check("opacity left alone", FarmMapDB.alpha == 0.35, FarmMapDB.alpha)
check("MODE PREFERENCE LEFT ALONE", FarmMapDB.mode == "cluster", FarmMapDB.mode)
check("prevAlpha seeded from their own opacity", FarmMapDB.prevAlpha == 0.35, FarmMapDB.prevAlpha)

-- A profile stranded at opacity zero, which hid the blips too. That is broken
-- data rather than a preference, so it gets repaired.
FarmMapDB = { dbVersion = 4, size = 900, alpha = 0, button = {} }
fire("ADDON_LOADED", "FarmMap")
check("opacity zero rescued to 0.1", FarmMapDB.alpha == 0.1, FarmMapDB.alpha)

-- A custom size is doubled too, and clamped at the ceiling.
FarmMapDB = { size = 1000, button = {} }
fire("ADDON_LOADED", "FarmMap")
check("a big custom size clamps at 1600", FarmMapDB.size == 1600, FarmMapDB.size)

-- A brand new install must take the defaults, NOT migrate them.
FarmMapDB = nil
fire("ADDON_LOADED", "FarmMap")
check("fresh install gets 900, not 1800", FarmMapDB.size == 900, FarmMapDB.size)
check("fresh install is nodes only", FarmMapDB.alpha == 0.1, FarmMapDB.alpha)
check("fresh install is stamped", FarmMapDB.dbVersion == 4)

FM_RESULT = { passes = passes, fails = table.concat(fails, "\n") }
