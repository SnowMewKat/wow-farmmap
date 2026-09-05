-- Minimal WoW API stub, just enough to load and drive FarmMap.
STUB = {}
STUB.mounted = false
STUB.form = nil
STUB.tickers = {}
STUB.output = {}
STUB.cursor = { 500, 380 }

local Frame = {}
Frame.__index = Frame

local Region = {}
Region.__index = Region

function Region:SetAllPoints() end
function Region:SetPoint() end
function Region:SetTexture(t) self.texture = t end
function Region:GetTexture() return self.texture end
function Region:SetBlendMode() end
function Region:SetVertexColor() end
function Region:SetText(t) self.text = t end
function Region:GetText() return self.text end
function Region:SetJustifyH() end
function Region:SetWidth() end
function Region:SetHeight() end
function Region:SetSize() end
function Region:Show() end
function Region:Hide() end

local function NewRegion()
	return setmetatable({}, Region)
end

local function NewFrame(name, parent)
	local f = setmetatable({}, Frame)
	f.name = name
	f.parent = parent
	f.children = {}
	f.points = {}
	f.scale = 1
	f.alpha = 1
	f.clamped = false
	f.mouse = false
	f.wheel = false
	f.shown = true
	f.checked = false
	f.level = 1
	f.scripts = {}
	f.events = {}
	f.width = 100
	f.height = 100
	if parent then table.insert(parent.children, f) end
	return f
end

function Frame:SetScale(v) self.scale = v end
function Frame:GetScale() return self.scale end
function Frame:SetAlpha(v) self.alpha = v end
function Frame:GetAlpha() return self.alpha end
function Frame:SetClampedToScreen(v) self.clamped = v end
function Frame:IsClampedToScreen() return self.clamped end
function Frame:ClearAllPoints() self.points = {} end
function Frame:SetPoint(p, rel, rp, x, y)
	-- A real frame replaces a point set on the same anchor point.
	for i, pt in ipairs(self.points) do
		if pt[1] == p then table.remove(self.points, i) break end
	end
	table.insert(self.points, { p, rel, rp, x, y })
end
function Frame:GetNumPoints() return #self.points end
function Frame:GetPoint(i)
	local pt = self.points[i or 1]
	if not pt then return nil end
	return pt[1], pt[2], pt[3], pt[4], pt[5]
end
function Frame:GetChildren() return table.unpack(self.children) end
function Frame:GetName() return self.name end
function Frame:GetParent() return self.parent end
function Frame:EnableMouse(v) self.mouse = v end
function Frame:IsMouseEnabled() return self.mouse end
function Frame:EnableMouseWheel(v) self.wheel = v end
function Frame:IsMouseWheelEnabled() return self.wheel end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:SetSize(w, h) self.width, self.height = w, h end
function Frame:SetWidth(w) self.width = w end
function Frame:SetHeight(h) self.height = h end
function Frame:GetEffectiveScale()
	local s, p = self.scale, self.parent
	while p do s = s * p.scale; p = p.parent end
	return s
end
function Frame:GetCenter() return 500, 400 end
function Frame:IsShown() return self.shown end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:SetShown(v) self.shown = v and true or false end
function Frame:RegisterEvent(e) self.events[e] = true end
function Frame:UnregisterEvent(e) self.events[e] = nil end
function Frame:SetScript(k, fn) self.scripts[k] = fn end
function Frame:GetScript(k) return self.scripts[k] end
function Frame:HookScript(k, fn)
	local old = self.scripts[k]
	self.scripts[k] = function(...)
		if old then old(...) end
		return fn(...)
	end
end
function Frame:CreateTexture() return NewRegion() end
function Frame:CreateFontString() return NewRegion() end
function Frame:RegisterForClicks() end
function Frame:RegisterForDrag() end
function Frame:SetMovable() end
function Frame:StartMoving() end
function Frame:StopMovingOrSizing() end
function Frame:SetFrameStrata(s) self.strata = s end
function Frame:GetFrameStrata() return self.strata end
function Frame:SetFrameLevel(l) self.level = l end
function Frame:GetFrameLevel() return self.level end
function Frame:SetChecked(v) self.checked = v and true or false end
function Frame:GetChecked() return self.checked end
function Frame:SetBackdrop() end
function Frame:SetText(t) self.text = t end
function Frame:GetText() return self.text end
function Frame:SetToplevel() end
function Frame:SetNormalTexture() end
function Frame:SetHighlightTexture() end

STUB.NewFrame = NewFrame

-- The globals FarmMap touches.
UIParent = NewFrame("UIParent", nil)
UIParent.width = 1920
function UIParent:GetCenter() return 960, 540 end
function UIParent:GetEffectiveScale() return 1 end

MinimapCluster = NewFrame("MinimapCluster", UIParent)
MinimapCluster.width = 220
MinimapCluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -30)
MinimapCluster.mouse = true

Minimap = NewFrame("Minimap", MinimapCluster)
Minimap.width = 198
Minimap.mouse = true
Minimap.wheel = true
Minimap:SetPoint("CENTER", MinimapCluster, "CENTER", 0, -10)
function Minimap:GetCenter() return 500, 380 end

-- Cluster furniture that must stay put in "map" mode.
ClusterHeader = NewFrame("MinimapZoneTextButton", MinimapCluster)
ClusterHeader.mouse = true

-- An addon button on the ring, and a gathering pin. The pin must survive the
-- furniture pass; the button must not.
AddonButton = NewFrame("LibDBIcon10_SomeAddon", Minimap)
AddonButton.mouse = true
GatherPin = NewFrame("GatherMatePin1", Minimap)
GatherPin.mouse = true
CalendarButton = NewFrame("GameTimeFrame", Minimap)
CalendarButton.mouse = true

EditModeManagerFrame = NewFrame("EditModeManagerFrame", UIParent)
EditModeManagerFrame.shown = false

CreateFrame = function(frameType, name, parent, template)
	local f = NewFrame(name, parent)
	f.frameType = frameType
	f.template = template
	STUB.lastCreated = f
	return f
end

function IsMounted() return STUB.mounted end
function GetShapeshiftFormID() return STUB.form end
function GetCursorPosition() return STUB.cursor[1], STUB.cursor[2] end

GameTooltip = NewFrame("GameTooltip", UIParent)
function GameTooltip:SetOwner() end
function GameTooltip:AddLine() end

C_Timer = {}
function C_Timer.NewTicker(interval, fn)
	local t = { interval = interval, fn = fn }
	table.insert(STUB.tickers, t)
	return t
end

SlashCmdList = {}

function print(msg)
	table.insert(STUB.output, msg)
end

function STUB.Tick(n)
	for _ = 1, (n or 1) do
		for _, t in ipairs(STUB.tickers) do t.fn() end
	end
end

function STUB.Slash(args)
	SlashCmdList["FARMMAP"](args or "")
end

-- Snapshot every piece of state FarmMap is allowed to touch, so a test can
-- prove the restore is exact. Covers BOTH candidate targets.
local function snapFrame(frame)
	local s = { scale = frame.scale, alpha = frame.alpha, clamped = frame.clamped, points = {} }
	for i, pt in ipairs(frame.points) do
		s.points[i] = { pt[1], pt[2] and pt[2].name or "nil", pt[3], pt[4], pt[5] }
	end
	return s
end

function STUB.Snapshot()
	return {
		cluster = snapFrame(MinimapCluster),
		minimap = snapFrame(Minimap),
		mouse = {
			cluster  = MinimapCluster.mouse,
			minimap  = Minimap.mouse,
			wheel    = Minimap.wheel,
			header   = ClusterHeader.mouse,
			addonBtn = AddonButton.mouse,
			pin      = GatherPin.mouse,
		},
		shown = {
			addonBtn = AddonButton.shown,
			pin      = GatherPin.shown,
			calendar = CalendarButton.shown,
			header   = ClusterHeader.shown,
		},
	}
end

function STUB.Diff(a, b)
	local out = {}
	local function cmp(label, x, y)
		if x ~= y then table.insert(out, label .. ": " .. tostring(x) .. " -> " .. tostring(y)) end
	end
	local function cmpFrame(label, fa, fb)
		cmp(label .. ".scale", fa.scale, fb.scale)
		cmp(label .. ".alpha", fa.alpha, fb.alpha)
		cmp(label .. ".clamped", fa.clamped, fb.clamped)
		cmp(label .. ".numPoints", #fa.points, #fb.points)
		for i = 1, math.max(#fa.points, #fb.points) do
			local pa, pb = fa.points[i], fb.points[i]
			if pa and pb then
				for j = 1, 5 do
					cmp(label .. ".point" .. i .. "[" .. j .. "]", pa[j], pb[j])
				end
			end
		end
	end
	cmpFrame("cluster", a.cluster, b.cluster)
	cmpFrame("minimap", a.minimap, b.minimap)
	for k, v in pairs(a.mouse) do cmp("mouse." .. k, v, b.mouse[k]) end
	for k, v in pairs(a.shown) do cmp("shown." .. k, v, b.shown[k]) end
	return out
end
