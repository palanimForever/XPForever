local addonName, ns = ...
local L = ns.L

local PADDING = 6

local InfoText = {}
ns.InfoText = InfoText

-- Oberkante eines Frames in UIParent-Koordinaten (Aktionsleisten können eigene Skalierungen haben).
local function TopInUIParent(frame)
    local top = frame:GetTop()
    return top and top * frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function CenterXInUIParent(frame)
    local x = frame:GetCenter()
    return x and x * frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

function InfoText:Init()
    if self.frame then return end

    local f = CreateFrame("Frame", "XPForeverInfoText", UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    self.frame = f

    -- Nur sichtbar, solange der Text entsperrt ist und verschoben werden kann.
    local dragBackground = f:CreateTexture(nil, "BACKGROUND")
    dragBackground:SetAllPoints()
    dragBackground:SetColorTexture(0.3, 0.6, 1, 0.25)
    self.dragBackground = dragBackground

    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    self.text = text

    f:SetScript("OnDragStart", function()
        self.isMoving = true
        f:StartMoving()
    end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        -- Position speichern wir selbst, WoWs eigene Layout-Speicherung würde dazwischenfunken.
        f:SetUserPlaced(false)
        self.isMoving = false
        local x, y = f:GetCenter()
        XPForeverDB.infoPoint = { x = x, y = y }
        self:Anchor()
    end)
    f:SetScript("OnEnter", function()
        GameTooltip:SetOwner(f, "ANCHOR_TOP")
        GameTooltip:SetText(L.infoDragHint)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", GameTooltip_Hide)

    -- Aktionsleisten können sich im Edit Mode verschieben.
    EventRegistry:RegisterCallback("EditMode.Exit", function() self:Anchor() end, self)
end

function InfoText:ApplySettings()
    if not self.frame then return end
    local db = XPForeverDB
    local font = self.text:GetFont()
    self.text:SetFont(font, db.infoFontSize, "OUTLINE")
    self.text:SetShadowOffset(0, 0)

    local movable = db.infoPosition == "free" and not db.infoLocked
    self.frame:EnableMouse(movable)
    self.dragBackground:SetShown(movable)
    self:Anchor()
end

function InfoText:Anchor()
    local f = self.frame
    if not f or self.isMoving then return end
    local db = XPForeverDB
    f:ClearAllPoints()

    if db.infoPosition == "free" and db.infoPoint then
        f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", db.infoPoint.x, db.infoPoint.y)
        return
    end

    -- Automatisch: über der höchsten sichtbaren Leiste im unteren Block, mittig zur XP-Leiste.
    local top, centerX
    local bars = { ns.Bar.frame, MainActionBar, MultiBarBottomLeft, MultiBarBottomRight }
    -- Blizzard-Container mit z. B. der Rufleiste (der XP-Container ist von unserer Leiste verdeckt).
    for _, container in ipairs(StatusTrackingBarManager and StatusTrackingBarManager.barContainers or {}) do
        table.insert(bars, container)
    end
    for _, bar in ipairs(bars) do
        if bar and bar:IsShown() then
            local barTop = TopInUIParent(bar)
            if barTop and (not top or barTop > top) then top = barTop end
        end
    end
    if ns.Bar.frame then centerX = CenterXInUIParent(ns.Bar.frame) end

    if top and centerX then
        f:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", centerX, top + db.infoOffset)
    else
        f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 140)
    end
end

function InfoText:Refresh()
    local f = self.frame
    if not f then return end
    local text = XPForeverDB.infoEnabled and ns.ShouldShow() and ns.BuildText("info") or ""
    if text == "" then
        f:Hide()
        return
    end
    self.text:SetText(text)
    f:SetSize(self.text:GetStringWidth() + PADDING * 2, self.text:GetStringHeight() + PADDING)
    f:Show()
end
