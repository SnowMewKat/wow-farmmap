-- FarmMap: core
-- Enlarged, centred, semi-transparent minimap while mounted or in Druid
-- Travel / Flight Form, restored exactly when you dismount.
--
-- Why the overlay IS the real minimap, and not a copy:
-- the minimap's terrain and its blips are drawn by the game engine straight
-- into the Minimap widget. Addons cannot read that back, render it to a
-- texture, or ask for a second copy of it, so there is nothing to clone. What
-- we can do is move and scale the widget itself, which is what this does.
--
-- Two modes:
--   "map"     move and scale Minimap alone, so the zone header, clock and
--             tracking button stay put in the corner. Closest thing to
--             showing just the inside of the minimap. Default.
--   "cluster" move and scale the whole MinimapCluster, furniture and all.
--
-- In both modes we SCALE and never resize. Pin addons such as GatherMate2 and
-- HandyNotes place their nodes from Minimap:GetWidth(), so changing that width
-- would scatter every gathering pin. Scaling leaves the maths untouched and
-- carries the pins along at the new size for free.

local ADDON_NAME, ns = ...

local DB_VERSION = 2

local DEFAULTS = {
	enabled     = true,
	size        = 900,     -- on-screen width of the map circle, in UI units
	alpha       = 0.6,
	mode        = "map",   -- "map" or "cluster"
	hideButtons = true,    -- hide minimap furniture while the overlay is up
	hudScale    = 1.0,     -- scale of FarmMap's own UI (button and panel)
	button      = { angle = 200, shown = true },
}

-- GetShapeshiftFormID() values that count as mounted for our purposes.
-- Verified against current retail: 3 Travel, 4 Aquatic, 27 Swift Flight, 29 Flight.
local TRAVEL_FORMS = { [3] = true, [4] = true, [27] = true, [29] = true }

-- Minimap furniture: buttons and widgets that sit on the ring rather than
-- being map content. Hidden while the overlay is up so the centred map is
-- just terrain and gathering nodes. Pins are deliberately NOT in here.
local FURNITURE = {
	GameTimeFrame                    = true,
	MiniMapMailFrame                 = true,
	MinimapZoneTextButton            = true,
	QueueStatusButton                = true,
	QueueStatusMinimapButton         = true,
	ExpansionLandingPageMinimapButton = true,
	AddonCompartmentFrame            = true,
	MiniMapTracking                  = true,
	MinimapBackdrop                  = true,
}

local active     = false
local testMode   = false
local saved      = nil
local mouseSaved = nil
local hiddenBits = nil
local wantScale  = nil
local wantTarget = nil

local function Print(msg)
	print("|cff33ff99FarmMap|r: " .. msg)
end
ns.Print = Print

--------------------------------------------------------------------------------
-- State test
--------------------------------------------------------------------------------

local function ShouldShow()
	if testMode then return true end
	if not FarmMapDB.enabled then return false end
	if IsMounted() then return true end
	local form = GetShapeshiftFormID()
	if form and TRAVEL_FORMS[form] then return true end
	return false
end

-- The frame we move. Minimap alone, or the whole cluster.
local function Target()
	if FarmMapDB.mode == "cluster" then return MinimapCluster end
	return Minimap
end

--------------------------------------------------------------------------------
-- Mouse pass-through
--------------------------------------------------------------------------------
-- The minimap normally eats clicks, drags and scroll. Record what was enabled,
-- switch it off so the overlay never intercepts input, put it back afterwards.

local function DisableMouse(frame, store, depth)
	if depth > 6 then return end

	if frame.IsMouseEnabled and frame:IsMouseEnabled() then
		store[#store + 1] = { frame, "mouse" }
		frame:EnableMouse(false)
	end
	if frame.IsMouseWheelEnabled and frame:IsMouseWheelEnabled() then
		store[#store + 1] = { frame, "wheel" }
		frame:EnableMouseWheel(false)
	end

	for _, child in ipairs({ frame:GetChildren() }) do
		DisableMouse(child, store, depth + 1)
	end
end

local function RestoreMouse(store)
	for i = #store, 1, -1 do
		local frame, kind = store[i][1], store[i][2]
		if kind == "mouse" then frame:EnableMouse(true) else frame:EnableMouseWheel(true) end
	end
end

--------------------------------------------------------------------------------
-- Furniture
--------------------------------------------------------------------------------

local function IsFurniture(frame)
	local name = frame.GetName and frame:GetName()
	if not name then return false end
	if FURNITURE[name] then return true end
	-- Every well behaved addon button goes through LibDBIcon.
	return string.find(name, "^LibDBIcon") ~= nil
end

local function HideFurniture(store)
	if not Minimap.GetChildren then return end
	for _, child in ipairs({ Minimap:GetChildren() }) do
		if child.IsShown and child:IsShown() and IsFurniture(child) then
			store[#store + 1] = child
			child:Hide()
		end
	end
	if ns.button and ns.button:IsShown() then
		store[#store + 1] = ns.button
		ns.button:Hide()
	end
end

local function ShowFurniture(store)
	for i = #store, 1, -1 do
		store[i]:Show()
	end
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

local function ApplyLayout()
	local target = wantTarget or Target()
	if not target or not Minimap then return end

	-- Scale is relative to the parent, so in map mode we are stacking on top of
	-- whatever scale the cluster already has (Edit Mode's minimap size slider
	-- sets exactly that). Divide it out so "450" means 450 on screen either way.
	local parentScale = 1
	local parent = target.GetParent and target:GetParent()
	if parent and parent ~= UIParent and parent.GetEffectiveScale then
		local ps, us = parent:GetEffectiveScale(), UIParent:GetEffectiveScale()
		if ps and us and ps > 0 and us > 0 then parentScale = ps / us end
	end

	local width = (Minimap:GetWidth() or 0) * parentScale
	wantScale = (width > 0) and (FarmMapDB.size / width) or 2

	target:SetClampedToScreen(false)
	target:ClearAllPoints()
	target:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	target:SetScale(wantScale)
	target:SetAlpha(FarmMapDB.alpha)

	-- In cluster mode the box is taller than the map because of the zone
	-- header, so a plain CENTER anchor sits the circle low. Correct for it.
	-- In map mode the target IS the circle, so no correction is needed.
	if target ~= Minimap then
		local ms, us = Minimap:GetEffectiveScale(), UIParent:GetEffectiveScale()
		local mx, my = Minimap:GetCenter()
		local ux, uy = UIParent:GetCenter()
		if mx and my and ux and uy and us > 0 then
			target:SetPoint("CENTER", UIParent, "CENTER",
				(ux * us - mx * ms) / us, (uy * us - my * ms) / us)
		end
	end
end

-- Edit Mode owns these anchors and can re-apply them underneath us. Rather
-- than fight it, notice the drift and re-assert. Cheap, and self-healing.
local function ReassertIfDrifted()
	local target = wantTarget
	if not target or not wantScale then return end

	if math.abs(target:GetScale() - wantScale) > 0.001 then
		ApplyLayout()
		return
	end

	local point, relativeTo = target:GetPoint(1)
	if point ~= "CENTER" or relativeTo ~= UIParent then
		ApplyLayout()
	end
end

--------------------------------------------------------------------------------
-- Apply / remove
--------------------------------------------------------------------------------

local function ApplyOverlay()
	if active then return end
	if not MinimapCluster or not Minimap then return end
	if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return end

	local target = Target()
	wantTarget = target

	local points = {}
	for i = 1, target:GetNumPoints() do
		points[i] = { target:GetPoint(i) }
	end

	saved = {
		target  = target,
		scale   = target:GetScale(),
		alpha   = target:GetAlpha(),
		clamped = target:IsClampedToScreen(),
		points  = points,
	}

	mouseSaved = {}
	DisableMouse(target, mouseSaved, 0)

	hiddenBits = {}
	if FarmMapDB.hideButtons then
		HideFurniture(hiddenBits)
	end

	ApplyLayout()
	active = true
	if ns.OnOverlayChanged then ns.OnOverlayChanged(true) end
end

local function RemoveOverlay()
	if not active then return end

	if saved and saved.target then
		local target = saved.target
		target:SetScale(saved.scale)
		target:SetAlpha(saved.alpha)
		target:SetClampedToScreen(saved.clamped)
		target:ClearAllPoints()

		if #saved.points > 0 then
			for _, p in ipairs(saved.points) do
				-- p = point, relativeTo, relativePoint, x, y
				target:SetPoint(p[1], p[2], p[3], p[4], p[5])
			end
		elseif target == Minimap then
			target:SetPoint("CENTER", MinimapCluster, "CENTER", 0, 0)
		else
			target:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -30)
		end
	end

	if hiddenBits then ShowFurniture(hiddenBits) end
	if mouseSaved then RestoreMouse(mouseSaved) end

	saved, mouseSaved, hiddenBits, wantScale, wantTarget, active = nil, nil, nil, nil, nil, false
	if ns.OnOverlayChanged then ns.OnOverlayChanged(false) end
end

local function Update()
	if ShouldShow() then ApplyOverlay() else RemoveOverlay() end
end

--------------------------------------------------------------------------------
-- Public API, used by FarmMapUI.lua
--------------------------------------------------------------------------------

ns.Update      = Update
ns.IsActive    = function() return active end
ns.IsTest      = function() return testMode end
ns.ApplyLayout = ApplyLayout

function ns.SetTest(on)
	testMode = on and true or false
	Update()
end

function ns.SetEnabled(on)
	FarmMapDB.enabled = on and true or false
	if not FarmMapDB.enabled then testMode = false end
	Update()
end

-- Anything that changes WHICH frame we move, or what we hide, has to put the
-- current overlay away first or we would restore the wrong frame later.
local function Restyle(apply)
	local wasActive = active
	if wasActive then RemoveOverlay() end
	apply()
	if wasActive then Update() end
end

function ns.SetMode(mode)
	if mode ~= "map" and mode ~= "cluster" then return end
	Restyle(function() FarmMapDB.mode = mode end)
end

function ns.SetHideButtons(on)
	Restyle(function() FarmMapDB.hideButtons = on and true or false end)
end

function ns.SetSize(n)
	FarmMapDB.size = n
	if active then ApplyLayout() end
end

function ns.SetAlpha(n)
	FarmMapDB.alpha = n
	if active then ApplyLayout() end
end

function ns.SetHudScale(n)
	FarmMapDB.hudScale = n
	if ns.ApplyHudScale then ns.ApplyHudScale() end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local f = CreateFrame("Frame")
ns.eventFrame = f
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
f:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
f:RegisterEvent("PLAYER_LOGOUT")

f:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON_NAME then return end
		-- Decide this BEFORE the defaults land, or a fresh install looks like an
		-- un-migrated one and gets its brand new default doubled.
		local fresh = (FarmMapDB == nil) or (next(FarmMapDB) == nil)

		FarmMapDB = FarmMapDB or {}
		for k, v in pairs(DEFAULTS) do
			if FarmMapDB[k] == nil then FarmMapDB[k] = v end
		end
		for k, v in pairs(DEFAULTS.button) do
			if FarmMapDB.button[k] == nil then FarmMapDB.button[k] = v end
		end

		-- v1 saved a size before "2x bigger" was asked for. Double an existing
		-- profile once, so the change lands without anyone retyping it.
		if not fresh and FarmMapDB.dbVersion == nil then
			FarmMapDB.size = math.min(FarmMapDB.size * 2, 1600)
		end
		FarmMapDB.dbVersion = DB_VERSION

	elseif event == "PLAYER_LOGIN" then
		if EditModeManagerFrame then
			EditModeManagerFrame:HookScript("OnShow", function()
				testMode = false
				RemoveOverlay()
			end)
		end
		if ns.BuildUI then ns.BuildUI() end
		-- Safety net for any mount or form change that does not fire an event.
		C_Timer.NewTicker(0.25, function()
			if active then
				if not ShouldShow() then RemoveOverlay() else ReassertIfDrifted() end
			elseif ShouldShow() then
				ApplyOverlay()
			end
		end)
		Update()

	elseif event == "PLAYER_LOGOUT" then
		RemoveOverlay() -- hand the minimap back before the client saves its layout

	else
		Update()
	end
end)

--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------

SLASH_FARMMAP1 = "/farmmap"
SlashCmdList["FARMMAP"] = function(msg)
	local cmd, rest = msg:lower():match("^%s*(%S*)%s*(.-)%s*$")

	if cmd == "" then
		ns.SetEnabled(not FarmMapDB.enabled)
		Print(FarmMapDB.enabled and "enabled." or "disabled.")

	elseif cmd == "test" then
		ns.SetTest(not testMode)
		Print("test mode " .. (testMode and "ON, overlay forced visible." or "off."))

	elseif cmd == "config" or cmd == "options" then
		if ns.ToggleOptions then ns.ToggleOptions() else Print("options panel unavailable.") end

	elseif cmd == "mode" then
		if rest == "map" or rest == "cluster" then
			ns.SetMode(rest)
			Print("mode set to " .. rest .. ".")
		else
			Print("usage: /farmmap mode map|cluster (current: " .. FarmMapDB.mode .. ")")
		end

	elseif cmd == "buttons" then
		ns.SetHideButtons(not FarmMapDB.hideButtons)
		Print("minimap buttons while farming: " .. (FarmMapDB.hideButtons and "hidden." or "shown."))

	elseif cmd == "size" then
		local n = tonumber(rest)
		if n and n >= 100 and n <= 1600 then
			ns.SetSize(n)
			Print("size set to " .. n .. ".")
		else
			Print("usage: /farmmap size 100-1600 (current: " .. FarmMapDB.size .. ")")
		end

	elseif cmd == "alpha" then
		local n = tonumber(rest)
		if n and n > 0 and n <= 1 then
			ns.SetAlpha(n)
			Print("opacity set to " .. n .. ".")
		else
			Print("usage: /farmmap alpha 0.1-1.0 (current: " .. FarmMapDB.alpha .. ")")
		end

	elseif cmd == "hud" then
		local n = tonumber(rest)
		if n and n >= 0.5 and n <= 4 then
			ns.SetHudScale(n)
			Print("HUD scale set to " .. n .. ".")
		else
			Print("usage: /farmmap hud 0.5-4.0 (current: " .. FarmMapDB.hudScale .. ")")
		end

	elseif cmd == "reset" then
		testMode = false
		RemoveOverlay()
		Print("minimap restored. Use /reload if anything still looks wrong.")

	elseif cmd == "status" then
		Print(string.format(
			"enabled=%s test=%s overlay=%s mode=%s size=%s alpha=%s hud=%s mounted=%s form=%s",
			tostring(FarmMapDB.enabled), tostring(testMode), tostring(active),
			tostring(FarmMapDB.mode), tostring(FarmMapDB.size), tostring(FarmMapDB.alpha),
			tostring(FarmMapDB.hudScale), tostring(IsMounted()), tostring(GetShapeshiftFormID())))

	else
		Print("commands: /farmmap (toggle), config, test, mode map|cluster, buttons, size N, alpha N, hud N, reset, status")
	end
end
