-- FarmMap: minimap button and options panel.
-- Dependency free. No Ace, no LibDBIcon, no LibStub.

local ADDON_NAME, ns = ...

local ICON = [[Interface\AddOns\FarmMap\Media\farmmap-icon]]
local BUTTON_SIZE = 32

local button, panel
local refreshers = {}

-- math.atan2 exists in WoW's Lua 5.1. Newer Lua folds it into math.atan.
local atan2 = math.atan2 or math.atan

--------------------------------------------------------------------------------
-- Minimap button
--------------------------------------------------------------------------------

local function PositionButton()
	if not button or not Minimap then return end
	local angle = math.rad(FarmMapDB.button.angle or 200)
	local radius = (Minimap:GetWidth() / 2) + 8
	-- SetPoint offsets are in the button's own scale space, so divide the
	-- radius by the scale to keep it sitting on the ring at any HUD scale.
	local s = button:GetScale()
	if not s or s <= 0 then s = 1 end
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER",
		(math.cos(angle) * radius) / s, (math.sin(angle) * radius) / s)
end

local function BuildButton()
	button = CreateFrame("Button", "FarmMapMinimapButton", Minimap)
	ns.button = button

	button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetMovable(true)

	-- The art already carries its own gold ring, so no Blizzard border on top.
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture(ICON)
	button.icon = icon

	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetTexture([[Interface\Minimap\UI-Minimap-ZoomButton-Highlight]])
	highlight:SetBlendMode("ADD")

	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("FarmMap")
		GameTooltip:AddLine(FarmMapDB.enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r", 1, 1, 1)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Left click: toggle on and off", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("Right click: options", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("Drag: move around the ring", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)

	button:SetScript("OnClick", function(_, mouseButton)
		if mouseButton == "RightButton" then
			ns.ToggleOptions()
		else
			ns.SetEnabled(not FarmMapDB.enabled)
			ns.Print(FarmMapDB.enabled and "enabled." or "disabled.")
			ns.RefreshOptions()
		end
	end)

	button:SetScript("OnDragStart", function(self)
		self.dragging = true
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local px, py = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			if not mx or not scale or scale <= 0 then return end
			px, py = px / scale, py / scale
			FarmMapDB.button.angle = math.deg(atan2(py - my, px - mx))
			PositionButton()
		end)
	end)
	button:SetScript("OnDragStop", function(self)
		self.dragging = false
		self:SetScript("OnUpdate", nil)
	end)

	PositionButton()
	if FarmMapDB.button.shown == false then button:Hide() end
end

--------------------------------------------------------------------------------
-- Options panel widgets
--------------------------------------------------------------------------------

local function MakeCheckbox(parent, label, x, y, get, set)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	cb:SetPoint("TOPLEFT", x, y)

	-- Own FontString rather than poking at template internals, which move
	-- around between patches.
	local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
	fs:SetText(label)
	fs:SetJustifyH("LEFT")

	cb:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
		ns.RefreshOptions()
	end)

	refreshers[#refreshers + 1] = function() cb:SetChecked(get()) end
	return cb
end

local function MakeStepper(parent, label, x, y, step, minv, maxv, get, set, fmt)
	local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fs:SetPoint("TOPLEFT", x, y)
	fs:SetText(label)

	local value = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	value:SetPoint("TOPLEFT", x + 150, y)
	value:SetWidth(52)
	value:SetJustifyH("CENTER")

	local minus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	minus:SetSize(24, 22)
	minus:SetPoint("TOPLEFT", x + 118, y + 5)
	minus:SetText("-")

	local plus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	plus:SetSize(24, 22)
	plus:SetPoint("TOPLEFT", x + 204, y + 5)
	plus:SetText("+")

	local function nudge(delta)
		local n = get() + delta
		if n < minv then n = minv end
		if n > maxv then n = maxv end
		-- Kill floating point dust from repeated 0.05 steps.
		n = math.floor(n * 1000 + 0.5) / 1000
		set(n)
		ns.RefreshOptions()
	end

	minus:SetScript("OnClick", function() nudge(-step) end)
	plus:SetScript("OnClick", function() nudge(step) end)

	refreshers[#refreshers + 1] = function() value:SetText(string.format(fmt, get())) end
end

-- Deliberately small. Four more checkboxes lived here and every one of them
-- was a way to make the addon worse: two undid the look Snow actually wants,
-- one added nothing, and one was a debugging switch. They are still reachable
-- from chat (/farmmap test, buttons, art, ring) but they are not decisions
-- worth putting in front of anyone.
local function BuildPanel()
	panel = CreateFrame("Frame", "FarmMapOptionsPanel", UIParent, "BackdropTemplate")
	ns.panel = panel

	panel:SetSize(300, 258)
	panel:SetPoint("CENTER")
	panel:SetFrameStrata("DIALOG")
	panel:SetMovable(true)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", panel.StartMoving)
	panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
	panel:SetClampedToScreen(true)
	panel:Hide()

	if panel.SetBackdrop then
		panel:SetBackdrop({
			bgFile   = [[Interface\DialogFrame\UI-DialogBox-Background]],
			edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
	end

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -16)
	title:SetText("FarmMap")

	local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -6, -6)

	local y = -46
	MakeCheckbox(panel, "Enabled", 20, y,
		function() return FarmMapDB.enabled end,
		function(v) ns.SetEnabled(v) end)

	y = y - 28
	MakeCheckbox(panel, "Nodes only (hide the map)", 20, y,
		function() return ns.IsNodesOnly() end,
		function(v) ns.SetNodesOnly(v) end)

	y = y - 28
	MakeCheckbox(panel, "Move whole minimap", 20, y,
		function() return FarmMapDB.mode == "cluster" end,
		function(v) ns.SetMode(v and "cluster" or "map") end)

	y = y - 36
	MakeStepper(panel, "Map size", 24, y, 25, 100, 1600,
		function() return FarmMapDB.size end,
		function(n) ns.SetSize(n) end, "%d")

	y = y - 30
	MakeStepper(panel, "Map opacity", 24, y, 0.05, 0.05, 1.0,
		function() return FarmMapDB.alpha end,
		function(n) ns.SetAlpha(n) end, "%.2f")

	y = y - 30
	MakeStepper(panel, "HUD scale", 24, y, 0.25, 0.5, 4.0,
		function() return FarmMapDB.hudScale end,
		function(n) ns.SetHudScale(n) end, "%.2f")

	local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("BOTTOM", 0, 18)
	hint:SetText("/farmmap for the same options in chat")
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function ns.RefreshOptions()
	for _, fn in ipairs(refreshers) do fn() end
end

function ns.ToggleOptions()
	if not panel then return end
	if panel:IsShown() then
		panel:Hide()
	else
		ns.RefreshOptions()
		panel:Show()
	end
end

-- "HUD" here means FarmMap's own furniture: the minimap button and the options
-- panel. The farming map itself is sized with /farmmap size.
function ns.ApplyHudScale()
	local s = FarmMapDB.hudScale or 1
	if button then
		button:SetScale(s)
		PositionButton()
	end
	if panel then panel:SetScale(s) end
end

-- Our button is a minimap button like any other, so it goes away with the rest
-- of them while the overlay is up and comes back on dismount.
function ns.OnOverlayChanged(shown)
	if not button then return end
	if shown then
		button:Hide()
	elseif FarmMapDB.button.shown ~= false then
		button:Show()
	end
end

function ns.BuildUI()
	BuildButton()
	BuildPanel()
	ns.ApplyHudScale()
	ns.RefreshOptions()
end
