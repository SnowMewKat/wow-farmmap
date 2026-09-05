-- Minimal WoW API stub, just enough to load and drive FarmMap.lua.
STUB = {}
STUB.mounted = false
STUB.form = nil
STUB.tickers = {}
STUB.output = {}

local Frame = {}
Frame.__index = Frame

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
	f.shown = false
	f.scripts = {}
	f.events = {}
	f.width = 100
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
function Frame:EnableMouse(v) self.mouse = v end
function Frame:IsMouseEnabled() return self.mouse end
function Frame:EnableMouseWheel(v) self.wheel = v end
function Frame:IsMouseWheelEnabled() return self.wheel end
function Frame:GetWidth() return self.width end
function Frame:GetEffectiveScale() return 1 end
function Frame:GetCenter() return 500, 400 end
function Frame:IsShown() return self.shown end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
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
function Minimap:GetCenter() return 500, 380 end

-- A header child, and a fake gathering pin parented to Minimap, so we can prove
-- the recursive mouse pass reaches pin addons like GatherMate2.
ClusterHeader = NewFrame("ClusterHeader", MinimapCluster)
ClusterHeader.mouse = true
GatherPin = NewFrame("GatherMatePin1", Minimap)
GatherPin.mouse = true

EditModeManagerFrame = NewFrame("EditModeManagerFrame", UIParent)

CreateFrame = function(frameType, name, parent)
	local f = NewFrame(name, parent)
	STUB.lastCreated = f
	return f
end

function IsMounted() return STUB.mounted end
function GetShapeshiftFormID() return STUB.form end

C_Timer = {}
function C_Timer.NewTicker(interval, fn)
	local t = { interval = interval, fn = fn }
	table.insert(STUB.tickers, t)
	return t
end

SlashCmdList = {}

local realprint = print
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

-- Snapshot every piece of state FarmMap is allowed to touch, so the test can
-- prove the restore is exact.
function STUB.Snapshot()
	local snap = { points = {} }
	snap.scale = MinimapCluster.scale
	snap.alpha = MinimapCluster.alpha
	snap.clamped = MinimapCluster.clamped
	for i, pt in ipairs(MinimapCluster.points) do
		snap.points[i] = { pt[1], pt[2] and pt[2].name or "nil", pt[3], pt[4], pt[5] }
	end
	snap.mouse = {
		cluster = MinimapCluster.mouse,
		minimap = Minimap.mouse,
		minimapWheel = Minimap.wheel,
		header = ClusterHeader.mouse,
		pin = GatherPin.mouse,
	}
	return snap
end

function STUB.Diff(a, b)
	local out = {}
	local function cmp(label, x, y)
		if x ~= y then table.insert(out, label .. ": " .. tostring(x) .. " -> " .. tostring(y)) end
	end
	cmp("scale", a.scale, b.scale)
	cmp("alpha", a.alpha, b.alpha)
	cmp("clamped", a.clamped, b.clamped)
	cmp("numPoints", #a.points, #b.points)
	for i = 1, math.max(#a.points, #b.points) do
		local pa, pb = a.points[i], b.points[i]
		if pa and pb then
			for j = 1, 5 do
				cmp("point" .. i .. "[" .. j .. "]", pa[j], pb[j])
			end
		end
	end
	for k, v in pairs(a.mouse) do
		cmp("mouse." .. k, v, b.mouse[k])
	end
	return out
end
