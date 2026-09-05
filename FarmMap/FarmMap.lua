-- FarmMap
-- Shows an enlarged, centred, semi-transparent minimap while the player is
-- mounted or in Druid Travel / Flight Form, and puts everything back afterwards.
--
-- Implementation note (the whole design in one paragraph):
-- There is only one real Minimap object in WoW, so the overlay IS the real
-- minimap, temporarily scaled and re-anchored. We scale MinimapCluster and
-- never touch the width of Minimap itself, because pin addons such as
-- GatherMate2 and HandyNotes parent their nodes to Minimap and position them
-- from Minimap:GetWidth(). Scaling the cluster keeps that maths exactly correct
-- and carries every gathering blip along for free. Every value we change is
-- read back first and restored verbatim on the way out.

local ADDON_NAME = ...

local DEFAULTS = {
	enabled = true,
	size    = 450,   -- desired on-screen width of the map circle, in UI units
	alpha   = 0.6,
}

-- GetShapeshiftFormID() values that count as mounted for our purposes.
-- Verified against current retail: 3 Travel, 4 Aquatic, 27 Swift Flight, 29 Flight.
local TRAVEL_FORMS = {
	[3]  = true, -- Travel Form (stag)
	[4]  = true, -- Aquatic Form
	[27] = true, -- Swift Flight Form
	[29] = true, -- Flight Form
}

local active     = false -- overlay currently applied
local testMode   = false -- /farmmap test override
local saved      = nil   -- original cluster state, restored verbatim
local mouseSaved = nil   -- frames whose mouse input we switched off
local wantScale  = nil   -- scale we last applied, for drift detection
local ticker     = nil

local function Print(msg)
	print("|cff33ff99FarmMap|r: " .. msg)
end

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

--------------------------------------------------------------------------------
-- Mouse pass-through
--------------------------------------------------------------------------------
-- The overlay must not eat clicks, drags or the scroll wheel. The minimap
-- normally takes all three. We walk the cluster, record which frames had mouse
-- or wheel input enabled, switch them off, and put them back later.

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
		if kind == "mouse" then
			frame:EnableMouse(true)
		else
			frame:EnableMouseWheel(true)
		end
	end
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

-- Anchor the cluster so that the MAP CIRCLE, not the cluster box, sits at the
-- centre of the screen. The cluster is taller than the map because of the zone
-- header, so a plain CENTER anchor would sit the map low.
local function ApplyLayout()
	local cluster = MinimapCluster
	if not cluster or not Minimap then return end

	local width = Minimap:GetWidth()
	wantScale = (width and width > 0) and (FarmMapDB.size / width) or 2

	cluster:SetClampedToScreen(false)
	cluster:ClearAllPoints()
	cluster:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	cluster:SetScale(wantScale)
	cluster:SetAlpha(FarmMapDB.alpha)

	-- Correct for the header offset, in screen pixels, then convert back into
	-- UIParent units for SetPoint.
	local ms = Minimap:GetEffectiveScale()
	local us = UIParent:GetEffectiveScale()
	local mx, my = Minimap:GetCenter()
	local ux, uy = UIParent:GetCenter()
	if mx and my and ux and uy and us > 0 then
		local dx = (ux * us - mx * ms) / us
		local dy = (uy * us - my * ms) / us
		cluster:SetPoint("CENTER", UIParent, "CENTER", dx, dy)
	end
end

-- Edit Mode owns the anchors of MinimapCluster and may re-apply them underneath
-- us. Rather than fight it, notice the drift and re-assert. Cheap, self-healing.
local function ReassertIfDrifted()
	local cluster = MinimapCluster
	if not cluster or not wantScale then return end

	if math.abs(cluster:GetScale() - wantScale) > 0.001 then
		ApplyLayout()
		return
	end

	local point, relativeTo = cluster:GetPoint(1)
	if point ~= "CENTER" or relativeTo ~= UIParent then
		ApplyLayout()
	end
end

--------------------------------------------------------------------------------
-- Show / hide
--------------------------------------------------------------------------------

local function Show()
	if active then return end
	local cluster = MinimapCluster
	if not cluster or not Minimap then return end

	-- Never wrestle Edit Mode while the player is actually using it.
	if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return end

	local points = {}
	for i = 1, cluster:GetNumPoints() do
		points[i] = { cluster:GetPoint(i) }
	end

	saved = {
		scale   = cluster:GetScale(),
		alpha   = cluster:GetAlpha(),
		clamped = cluster:IsClampedToScreen(),
		points  = points,
	}

	mouseSaved = {}
	DisableMouse(cluster, mouseSaved, 0)

	ApplyLayout()
	active = true
end

local function Hide()
	if not active then return end
	local cluster = MinimapCluster

	if cluster and saved then
		cluster:SetScale(saved.scale)
		cluster:SetAlpha(saved.alpha)
		cluster:SetClampedToScreen(saved.clamped)
		cluster:ClearAllPoints()

		if #saved.points > 0 then
			for _, p in ipairs(saved.points) do
				-- p = point, relativeTo, relativePoint, x, y
				cluster:SetPoint(p[1], p[2], p[3], p[4], p[5])
			end
		else
			-- Should not happen, but never leave the cluster unanchored.
			cluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -30)
		end
	end

	if mouseSaved then
		RestoreMouse(mouseSaved)
	end

	saved, mouseSaved, wantScale, active = nil, nil, nil, false
end

local function Update()
	if ShouldShow() then Show() else Hide() end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
f:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
f:RegisterEvent("PLAYER_LOGOUT")

f:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON_NAME then return end
		FarmMapDB = FarmMapDB or {}
		for k, v in pairs(DEFAULTS) do
			if FarmMapDB[k] == nil then FarmMapDB[k] = v end
		end

	elseif event == "PLAYER_LOGIN" then
		-- If the player opens Edit Mode, get out of the way immediately.
		if EditModeManagerFrame then
			EditModeManagerFrame:HookScript("OnShow", function()
				testMode = false
				Hide()
			end)
		end
		-- Safety net for any mount or form transition that does not fire an event.
		ticker = C_Timer.NewTicker(0.25, function()
			if active then
				if not ShouldShow() then Hide() else ReassertIfDrifted() end
			elseif ShouldShow() then
				Show()
			end
		end)
		Update()

	elseif event == "PLAYER_LOGOUT" then
		Hide() -- hand the minimap back before the client saves its layout

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
		FarmMapDB.enabled = not FarmMapDB.enabled
		if not FarmMapDB.enabled then testMode = false end
		Print(FarmMapDB.enabled and "enabled." or "disabled.")
		Update()

	elseif cmd == "test" then
		testMode = not testMode
		Print("test mode " .. (testMode and "ON, overlay forced visible." or "off."))
		Update()

	elseif cmd == "size" then
		local n = tonumber(rest)
		if n and n >= 100 and n <= 1200 then
			FarmMapDB.size = n
			Print("size set to " .. n .. ".")
			if active then ApplyLayout() end
		else
			Print("usage: /farmmap size 100-1200 (current: " .. FarmMapDB.size .. ")")
		end

	elseif cmd == "alpha" then
		local n = tonumber(rest)
		if n and n > 0 and n <= 1 then
			FarmMapDB.alpha = n
			Print("opacity set to " .. n .. ".")
			if active then ApplyLayout() end
		else
			Print("usage: /farmmap alpha 0.1-1.0 (current: " .. FarmMapDB.alpha .. ")")
		end

	elseif cmd == "reset" then
		testMode = false
		Hide()
		Print("minimap restored. Use /reload if anything still looks wrong.")

	elseif cmd == "status" then
		Print(string.format(
			"enabled=%s test=%s overlay=%s size=%s alpha=%s mounted=%s form=%s",
			tostring(FarmMapDB.enabled), tostring(testMode), tostring(active),
			tostring(FarmMapDB.size), tostring(FarmMapDB.alpha),
			tostring(IsMounted()), tostring(GetShapeshiftFormID())))

	else
		Print("commands: /farmmap (toggle), test, size N, alpha N, reset, status")
	end
end
