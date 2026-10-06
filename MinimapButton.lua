local addonName, ns = ...
local L = ns.L
local state = ns.state

-- Minimap button via LibDBIcon: round, can be dragged around the minimap, position stored in
-- XPForeverDB.minimap. Also adds an entry to Blizzard's addon menu at the minimap (addon compartment).

-- TGA (128x128, 32 bit) loads reliably in WoW.
local ICON = "Interface\\AddOns\\" .. addonName .. "\\Media\\icon"
local ICON_SIZE = 28 -- almost fills the 31 px button
-- LibDBIcon crops 5% from every edge (zoom effect). With these coordinates the icon's bronze ring
-- stays fully visible: -a + 0.05 * (1 + 2a) = 0  →  a = 0.05 / 0.9.
local ICON_COORDS = { -0.0556, 1.0556, -0.0556, 1.0556 }

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
    tooltip:AddLine(ns.ClickHint("LeftButton", nil, L.actionOptions, L.hintMinimapLeft), GRAY_FONT_COLOR:GetRGB())
    tooltip:AddLine(ns.ClickHint("RightButton", nil, L.actionToggleInfo, L.hintMinimapRight), GRAY_FONT_COLOR:GetRGB())
    tooltip:AddLine(ns.ClickHint("LeftButton", nil, L.actionDragMinimap, L.hintMinimapDrag), GRAY_FONT_COLOR:GetRGB())
end

local function OnClick(_, button)
    if button == "RightButton" then
        ns.ToggleInfoText()
    else
        ns.Options:Open()
    end
end

-- Must run before PLAYER_LOGIN (LibDBIcon positions its buttons on login), so in ADDON_LOADED.
function MinimapButton:Init()
    local LDB = LibStub("LibDataBroker-1.1", true)
    local DBIcon = LibStub("LibDBIcon-1.0", true)
    if not (LDB and DBIcon) then return end
    self.DBIcon = DBIcon

    local launcher = LDB:NewDataObject(addonName, {
        type = "launcher",
        icon = ICON,
        iconCoords = ICON_COORDS,
        label = addonName,
        OnClick = OnClick,
        OnTooltipShow = ShowTooltip,
    })
    XPForeverDB.minimap.hide = not XPForeverDB.showMinimapButton
    DBIcon:Register(addonName, launcher, XPForeverDB.minimap)

    -- Our icon has its own bronze ring. LibDBIcon's golden ring would sit around it twice and is
    -- slightly offset in Forever (which reports itself as Mainline), so remove it.
    DBIcon:RemoveButtonBorder(addonName)
    DBIcon:RemoveButtonBackground(addonName)
    DBIcon:SetButtonIcon(addonName, nil, ICON_SIZE, "CENTER", 0, 0)

    DBIcon:AddButtonToCompartment(addonName)
end

function MinimapButton:ApplySettings()
    if not self.DBIcon then return end
    XPForeverDB.minimap.hide = not XPForeverDB.showMinimapButton
    -- Refresh also picks up a new db table (e.g. after "Restore defaults").
    self.DBIcon:Refresh(addonName, XPForeverDB.minimap)
end
