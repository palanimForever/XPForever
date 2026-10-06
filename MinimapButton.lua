local addonName, ns = ...
local L = ns.L
local state = ns.state

-- Minimap-Button über LibDBIcon: rund, mit gedrückter Maustaste um die Minimap ziehbar, Position in
-- XPForeverDB.minimap. Zusätzlich ein Eintrag in Blizzards Addon-Menü an der Minimap (Addon Compartment).

-- TGA (128x128, 32 Bit) lädt WoW sicher; Quelle: design/icons/XPForeverIcon.png im Workspace.
local ICON = "Interface\\AddOns\\" .. addonName .. "\\Media\\icon"

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local function ShowTooltip(tooltip)
    tooltip:AddLine(ns.BrandLine())

    if ns.ShouldShow() then
        local percent = ns.FormatPercent(state.xp / math.max(state.max, 1) * 100)
        tooltip:AddDoubleLine(L.itemLabelLevel .. " " .. state.level, percent .. " %", 1, 1, 1, 1, 1, 1)
        local rate, seconds, kills = ns.GetRate(), ns.GetTimeToLevel(), ns.GetKillsToLevel()
        tooltip:AddDoubleLine(L.itemLabelRate, rate and ns.FormatNumber(rate * 3600) or L.itemUnknown,
            1, 1, 1, 1, 1, 1)
        tooltip:AddDoubleLine(L.itemLabelTime, seconds and ns.FormatDuration(seconds) or L.itemUnknown,
            1, 1, 1, 1, 1, 1)
        tooltip:AddDoubleLine(L.tooltipKills, kills and "~" .. ns.FormatNumber(kills) or L.itemUnknown,
            1, 1, 1, 1, 1, 1)
    end

    tooltip:AddLine(" ")
    tooltip:AddLine(L.hintMinimapLeft, GRAY_FONT_COLOR:GetRGB())
    tooltip:AddLine(L.hintMinimapRight, GRAY_FONT_COLOR:GetRGB())
    tooltip:AddLine(L.hintMinimapDrag, GRAY_FONT_COLOR:GetRGB())
end

local function OnClick(_, button)
    if button == "RightButton" then
        ns.Options:SetValue("infoEnabled", not XPForeverDB.infoEnabled)
    else
        ns.Options:Open()
    end
end

-- Muss vor PLAYER_LOGIN laufen (LibDBIcon positioniert die Buttons beim Login), also in ADDON_LOADED.
function MinimapButton:Init()
    local LDB = LibStub("LibDataBroker-1.1", true)
    local DBIcon = LibStub("LibDBIcon-1.0", true)
    if not (LDB and DBIcon) then return end
    self.DBIcon = DBIcon

    local launcher = LDB:NewDataObject(addonName, {
        type = "launcher",
        icon = ICON,
        label = addonName,
        OnClick = OnClick,
        OnTooltipShow = ShowTooltip,
    })
    XPForeverDB.minimap.hide = not XPForeverDB.showMinimapButton
    DBIcon:Register(addonName, launcher, XPForeverDB.minimap)
    DBIcon:AddButtonToCompartment(addonName)
end

function MinimapButton:ApplySettings()
    if not self.DBIcon then return end
    XPForeverDB.minimap.hide = not XPForeverDB.showMinimapButton
    -- Refresh übernimmt auch eine neue db-Tabelle (z. B. nach "Standardeinstellungen").
    self.DBIcon:Refresh(addonName, XPForeverDB.minimap)
end
