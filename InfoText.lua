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

    -- Rahmen, der nur bei gedrückter Shift-Taste erscheint und zeigt, dass der Text verschiebbar ist.
    local dragBackground = f:CreateTexture(nil, "BACKGROUND")
    dragBackground:SetAllPoints()
    dragBackground:SetColorTexture(0.3, 0.6, 1, 0.25)
    dragBackground:Hide()
    self.dragBackground = dragBackground

    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    self.text = text

    -- Verschieben mit Shift + Ziehen; danach gilt die Position als "frei".
    f:SetScript("OnDragStart", function()
        if not IsShiftKeyDown() then return end
        self.isMoving = true
        f:StartMoving()
    end)
    f:SetScript("OnDragStop", function()
        if not self.isMoving then return end
        f:StopMovingOrSizing()
        -- Position speichern wir selbst, WoWs eigene Layout-Speicherung würde dazwischenfunken.
        f:SetUserPlaced(false)
        self.isMoving = false
        local x, y = f:GetCenter()
        XPForeverDB.infoPoint = { x = x, y = y }
        ns.Options:SetValue("infoPosition", "free")
        self:Anchor()
        self:UpdateMouse()
    end)
    -- Shift + Rechtsklick: zurück an den automatischen Platz über den Aktionsleisten.
    f:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and IsShiftKeyDown() then
            XPForeverDB.infoPoint = nil
            ns.Options:SetValue("infoPosition", "auto")
            self:Anchor()
        end
    end)
    f:SetScript("OnEnter", function()
        GameTooltip:SetOwner(f, "ANCHOR_TOP")
        GameTooltip:SetText(ns.BrandLine())
        GameTooltip:AddLine(ns.ClickHint("LeftButton", "SHIFT", L.actionDragMove, L.infoDragHint),
            GRAY_FONT_COLOR:GetRGB())
        GameTooltip:AddLine(ns.ClickHint("RightButton", "SHIFT", L.actionResetPosition, L.infoResetHint),
            GRAY_FONT_COLOR:GetRGB())
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", GameTooltip_Hide)

    -- Ohne Shift ist der Text für die Maus durchlässig (Klicks und Kameradrehen darunter gehen normal).
    f:RegisterEvent("MODIFIER_STATE_CHANGED")
    f:SetScript("OnEvent", function() self:UpdateMouse() end)

    -- Aktionsleisten können sich im Edit Mode verschieben.
    EventRegistry:RegisterCallback("EditMode.Exit", function() self:Anchor() end, self)
end

-- Maus nur bei gedrückter Shift-Taste annehmen; dann auch den Verschiebe-Rahmen zeigen.
function InfoText:UpdateMouse()
    local movable = IsShiftKeyDown() or self.isMoving
    self.frame:EnableMouse(movable)
    self.dragBackground:SetShown(movable)
    if not movable and GameTooltip:GetOwner() == self.frame then
        GameTooltip_Hide()
    end
end

function InfoText:ApplySettings()
    if not self.frame then return end
    local font = self.text:GetFont()
    self.text:SetFont(font, XPForeverDB.infoFontSize, "OUTLINE")
    self.text:SetShadowOffset(0, 0)
    self:UpdateMouse()
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
