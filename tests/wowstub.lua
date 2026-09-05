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
function Region:Show() self.shown = true end
function Region:Hide() self.shown = false end
function Region:IsShown() return self.shown end

local function NewRegion()
	return setmetatable({ shown = true }, Region)
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
	f.cx, f.cy = 500, 400          -- centre, in this stub's flat screen space
	f.ignoreScale = false
	f.ignoreAlpha = false
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
function Frame:GetRegions() return table.unpack(self.regions or {}) end
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
function Frame:GetCenter() return self.cx, self.cy end
function Frame:IsShown() return self.shown end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:SetShown(v) self.shown = v and true or false end
function Frame:SetIgnoreParentScale(v) self.ignoreScale = v and true or false end
function Frame:IsIgnoringParentScale() return self.ignoreScale end
function Frame:SetIgnoreParentAlpha(v) self.ignoreAlpha = v and true or false end
function Frame:IsIgnoringParentAlpha() return self.ignoreAlpha end
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

--------------------------------------------------------------------------------
-- The minimap, laid out with real geometry so the furniture test is exercised.
-- Minimap centre is (500, 400) and its width is 198, so the ring radius is 99.
--------------------------------------------------------------------------------

UIParent = NewFrame("UIParent", nil)
UIParent.width = 1920
UIParent.cx, UIParent.cy = 960, 540

MinimapCluster = NewFrame("MinimapCluster", UIParent)
MinimapCluster.width = 220
MinimapCluster.cx, MinimapCluster.cy = 500, 410
MinimapCluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -30)
MinimapCluster.mouse = true

Minimap = NewFrame("Minimap", MinimapCluster)
Minimap.width, Minimap.height = 198, 198
Minimap.cx, Minimap.cy = 500, 400
Minimap.mouse = true
Minimap.wheel = true
Minimap:SetPoint("CENTER", MinimapCluster, "CENTER", 0, -10)

-- Cluster furniture. Never moves in map mode because it is not a child of Minimap.
ClusterHeader = NewFrame("MinimapZoneTextButton", MinimapCluster)
ClusterHeader.mouse = true

-- On the ring, named by LibDBIcon: furniture by name AND by geometry.
AddonButton = NewFrame("LibDBIcon10_SomeAddon", Minimap)
AddonButton.cx, AddonButton.cy = 607, 400   -- 107 from centre, outside the ring
AddonButton.mouse = true
AddonButton:SetPoint("CENTER", Minimap, "CENTER", 107, 0)

-- On the ring, named by nothing we recognise. ONLY the geometric test can
-- catch this one, and Snow's screenshot was full of them.
StrayButton = NewFrame("RareScannerMinimapToggle", Minimap)
StrayButton.cx, StrayButton.cy = 500, 512   -- 112 from centre, outside the ring
StrayButton.mouse = true
StrayButton:SetPoint("CENTER", Minimap, "CENTER", 0, 112)

-- A gathering pin well inside the ring.
GatherPin = NewFrame("GatherMatePin1", Minimap)
GatherPin.cx, GatherPin.cy = 530, 420
GatherPin.mouse = true
GatherPin:SetPoint("CENTER", Minimap, "CENTER", 30, 20)

-- A gathering pin clamped to the very edge, so geometry says "outside" but the
-- name says pin. It MUST travel with the map or nodes end up stuck in a corner.
ClampedPin = NewFrame("GatherMatePin2", Minimap)
ClampedPin.cx, ClampedPin.cy = 500, 505     -- 105 from centre, outside the ring
ClampedPin.mouse = true
ClampedPin:SetPoint("CENTER", Minimap, "CENTER", 0, 105)

-- An unnamed child on the ring. Unnamed means map content, so leave it alone.
UnnamedChild = NewFrame(nil, Minimap)
UnnamedChild.cx, UnnamedChild.cy = 610, 400
UnnamedChild:SetPoint("CENTER", Minimap, "CENTER", 110, 0)

CalendarButton = NewFrame("GameTimeFrame", Minimap)
CalendarButton.cx, CalendarButton.cy = 570, 470
CalendarButton.mouse = true
CalendarButton:SetPoint("CENTER", Minimap, "CENTER", 70, 70)

-- The compass ring: decoration that is neither map nor node, and the thing
-- that was left alone on screen once the map faded out.
MinimapCompassTexture = NewFrame("MinimapCompassTexture", Minimap)
MinimapCompassTexture.cx, MinimapCompassTexture.cy = 500, 400
MinimapBorder = NewFrame("MinimapBorder", Minimap)
MinimapBorder.cx, MinimapBorder.cy = 500, 400

EditModeManagerFrame = NewFrame("EditModeManagerFrame", UIParent)
EditModeManagerFrame.shown = false

CreateFrame = function(frameType, name, parent, template)
	local f = NewFrame(name, parent)
	f.frameType = frameType
	f.template = template
	-- Real Buttons accept mouse input the moment they exist, which is what
	-- makes "is this still clickable after docking" a meaningful question.
	if frameType == "Button" or frameType == "CheckButton" then f.mouse = true end
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

--------------------------------------------------------------------------------
-- Snapshot / diff, so a test can prove the restore is exact
--------------------------------------------------------------------------------

local function snapFrame(frame)
	local s = {
		scale = frame.scale, alpha = frame.alpha, clamped = frame.clamped,
		ignoreScale = frame.ignoreScale, ignoreAlpha = frame.ignoreAlpha,
		mouse = frame.mouse, wheel = frame.wheel, shown = frame.shown,
		points = {},
	}
	for i, pt in ipairs(frame.points) do
		s.points[i] = { pt[1], pt[2] and (pt[2].name or "<unnamed>") or "nil", pt[3], pt[4], pt[5] }
	end
	return s
end

STUB.watched = {
	cluster    = function() return MinimapCluster end,
	minimap    = function() return Minimap end,
	header     = function() return ClusterHeader end,
	addonBtn   = function() return AddonButton end,
	strayBtn   = function() return StrayButton end,
	gatherPin  = function() return GatherPin end,
	clampedPin = function() return ClampedPin end,
	unnamed    = function() return UnnamedChild end,
	calendar   = function() return CalendarButton end,
	compass    = function() return MinimapCompassTexture end,
	border     = function() return MinimapBorder end,
}

function STUB.Snapshot()
	local out = {}
	for key, get in pairs(STUB.watched) do
		out[key] = snapFrame(get())
	end
	return out
end

function STUB.Diff(a, b)
	local out = {}
	local function cmp(label, x, y)
		if x ~= y then table.insert(out, label .. ": " .. tostring(x) .. " -> " .. tostring(y)) end
	end
	for key in pairs(STUB.watched) do
		local fa, fb = a[key], b[key]
		for _, field in ipairs({ "scale", "alpha", "clamped", "ignoreScale", "ignoreAlpha", "mouse", "wheel", "shown" }) do
			cmp(key .. "." .. field, fa[field], fb[field])
		end
		cmp(key .. ".numPoints", #fa.points, #fb.points)
		for i = 1, math.max(#fa.points, #fb.points) do
			local pa, pb = fa.points[i], fb.points[i]
			if pa and pb then
				for j = 1, 5 do
					cmp(key .. ".point" .. i .. "[" .. j .. "]", pa[j], pb[j])
				end
			end
		end
	end
	return out
end

-- Where is a frame's first anchor pointing right now?
function STUB.AnchorName(frame)
	local _, rel = frame:GetPoint(1)
	return rel and (rel.name or "<unnamed>") or "nil"
end
