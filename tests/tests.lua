-- Drives FarmMap through the real farming lifecycle against the stub.
local fails, passes = {}, 0

local function check(label, cond, extra)
	if cond then
		passes = passes + 1
	else
		table.insert(fails, label .. (extra and ("  [" .. tostring(extra) .. "]") or ""))
	end
end

local ev = FM_EVENT_FRAME -- set by the runner
local function fire(event, arg1)
	ev.scripts.OnEvent(ev, event, arg1)
end

-- 1. Load
fire("ADDON_LOADED", "FarmMap")
check("db defaults enabled", FarmMapDB.enabled == true)
check("db default size 450", FarmMapDB.size == 450, FarmMapDB.size)
check("db default alpha 0.6", FarmMapDB.alpha == 0.6, FarmMapDB.alpha)

fire("PLAYER_LOGIN")
local baseline = STUB.Snapshot()
check("idle: no overlay applied", MinimapCluster.scale == 1)

-- 2. Mount up
STUB.mounted = true
fire("PLAYER_MOUNT_DISPLAY_CHANGED")
check("mounted: scale enlarges", math.abs(MinimapCluster.scale - (450 / 198)) < 0.0001, MinimapCluster.scale)
check("mounted: alpha 0.6", MinimapCluster.alpha == 0.6, MinimapCluster.alpha)
local p, rel = MinimapCluster:GetPoint(1)
check("mounted: centred on UIParent", p == "CENTER" and rel == UIParent, tostring(p))
check("mounted: exactly one anchor", MinimapCluster:GetNumPoints() == 1, MinimapCluster:GetNumPoints())
check("mounted: minimap mouse off", Minimap.mouse == false)
check("mounted: minimap wheel off", Minimap.wheel == false)
check("mounted: cluster mouse off", MinimapCluster.mouse == false)
check("mounted: header mouse off", ClusterHeader.mouse == false)
check("mounted: gather pin mouse off", GatherPin.mouse == false)
check("mounted: Minimap width untouched", Minimap.width == 198, Minimap.width)

-- 3. Dismount, and demand an exact restore
STUB.mounted = false
fire("PLAYER_MOUNT_DISPLAY_CHANGED")
local after = STUB.Snapshot()
local diff = STUB.Diff(baseline, after)
check("dismount: restores exactly", #diff == 0, table.concat(diff, "; "))

-- 4. Druid travel and flight forms
for _, form in ipairs({ 3, 4, 27, 29 }) do
	STUB.form = form
	fire("UPDATE_SHAPESHIFT_FORM")
	check("form " .. form .. " shows overlay", MinimapCluster.scale > 1.5, MinimapCluster.scale)
	STUB.form = nil
	fire("UPDATE_SHAPESHIFT_FORM")
	check("leaving form " .. form .. " restores", #STUB.Diff(baseline, STUB.Snapshot()) == 0)
end

-- 5. Non travel forms must NOT trigger it
for _, form in ipairs({ 1, 5, 31 }) do
	STUB.form = form
	fire("UPDATE_SHAPESHIFT_FORM")
	check("form " .. form .. " stays hidden", MinimapCluster.scale == 1, MinimapCluster.scale)
end
STUB.form = nil

-- 6. Missed event: the ticker must catch it both ways
STUB.mounted = true
STUB.Tick()
check("ticker catches a missed mount", MinimapCluster.scale > 1.5)
STUB.mounted = false
STUB.Tick()
check("ticker catches a missed dismount", #STUB.Diff(baseline, STUB.Snapshot()) == 0)

-- 7. Edit Mode drift: something re-anchors the cluster underneath us
STUB.mounted = true
STUB.Tick()
MinimapCluster:ClearAllPoints()
MinimapCluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -30)
STUB.Tick()
local dp, dr = MinimapCluster:GetPoint(1)
check("re-asserts after drift", dp == "CENTER" and dr == UIParent, tostring(dp))
STUB.mounted = false
STUB.Tick()

-- 8. Slash: toggle off hides even while mounted
STUB.mounted = true
STUB.Tick()
STUB.Slash("")
check("toggle off disables", FarmMapDB.enabled == false)
check("toggle off restores while mounted", #STUB.Diff(baseline, STUB.Snapshot()) == 0,
	table.concat(STUB.Diff(baseline, STUB.Snapshot()), "; "))
STUB.Tick()
check("stays hidden while disabled and mounted", MinimapCluster.scale == 1)

-- 9. /farmmap test forces it visible even while disabled and dismounted
STUB.mounted = false
STUB.Slash("test")
check("test mode shows while disabled", MinimapCluster.scale > 1.5, MinimapCluster.scale)
STUB.Slash("test")
check("test mode off restores", #STUB.Diff(baseline, STUB.Snapshot()) == 0)

STUB.Slash("") -- back on
check("toggle on re-enables", FarmMapDB.enabled == true)

-- 10. Tuning commands
STUB.Slash("size 500")
check("size accepted", FarmMapDB.size == 500, FarmMapDB.size)
STUB.Slash("alpha 0.45")
check("alpha accepted", FarmMapDB.alpha == 0.45, FarmMapDB.alpha)
STUB.Slash("size 99999")
check("bad size rejected", FarmMapDB.size == 500, FarmMapDB.size)
STUB.Slash("alpha 7")
check("bad alpha rejected", FarmMapDB.alpha == 0.45, FarmMapDB.alpha)

STUB.mounted = true
STUB.Tick()
check("size 500 applied live", math.abs(MinimapCluster.scale - (500 / 198)) < 0.0001, MinimapCluster.scale)
check("alpha 0.45 applied live", MinimapCluster.alpha == 0.45)

-- 11. reset while mounted, and logout safety
STUB.Slash("reset")
check("reset restores while mounted", #STUB.Diff(baseline, STUB.Snapshot()) == 0,
	table.concat(STUB.Diff(baseline, STUB.Snapshot()), "; "))
STUB.Tick()
STUB.mounted = true
STUB.Tick()
fire("PLAYER_LOGOUT")
check("logout restores", #STUB.Diff(baseline, STUB.Snapshot()) == 0)

-- 12. Edit Mode opening while the overlay is up
STUB.mounted = true
STUB.Tick()
check("overlay up before edit mode", MinimapCluster.scale > 1.5)
EditModeManagerFrame.scripts.OnShow(EditModeManagerFrame)
check("edit mode opening restores", #STUB.Diff(baseline, STUB.Snapshot()) == 0,
	table.concat(STUB.Diff(baseline, STUB.Snapshot()), "; "))
EditModeManagerFrame:Show()
STUB.Tick()
check("does not re-show while edit mode open", MinimapCluster.scale == 1, MinimapCluster.scale)
EditModeManagerFrame:Hide()
STUB.mounted = false
STUB.Tick()

FM_RESULT = { passes = passes, fails = table.concat(fails, "\n") }
