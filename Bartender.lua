local addonName, ns = ...
local L = ns.L

-- Bartender4 support (work in progress).
-- Bartender hides Blizzard's StatusTrackingBarManager and, with its "Status Tracking Bar" module, moves it
-- into a bar of its own that can be placed, scaled and faded. In that case our bar becomes a child of
-- Blizzard's experience bar container, so it inherits Bartender's position, scale, alpha and visibility.

local HINT_DELAY = 6 -- seconds after login, so the hint isn't lost among other login messages
local HINT_RETRY = 5 -- seconds; Blizzard's containers need a moment to be placed

-- Bartender action bars that can sit above the experience bar (bars 11 and 12 don't exist).
local ACTION_BAR_IDS = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 13, 14, 15 }

local Bartender = {}
ns.Bartender = Bartender

function Bartender:IsActive()
    if self.active == nil then
        self.active = C_AddOns.IsAddOnLoaded("Bartender4") and true or false
    end
    return self.active
end

-- True while Bartender's status bar is turned off: Blizzard's containers are then hidden, and so is our bar.
function Bartender:IsStatusBarHidden()
    local container = MainStatusTrackingBarContainer
    return self:IsActive() and container ~= nil and UIParent:IsVisible() and not container:IsVisible()
end

-- Visible Bartender action bars, for placing the info text above them.
function Bartender:VisibleActionBars()
    local bars = {}
    if not self:IsActive() then return bars end
    for _, id in ipairs(ACTION_BAR_IDS) do
        local bar = _G["BT4Bar" .. id]
        if bar and bar:IsVisible() then table.insert(bars, bar) end
    end
    return bars
end

-- Once per account: XPForever now follows Bartender. Separately, once: Bartender's status bar is off.
function Bartender:ShowHintOnce()
    if not self:IsActive() then return end
    C_Timer.After(HINT_DELAY, function()
        local db = XPForeverDB
        if not db.bartenderHintSeen then
            db.bartenderHintSeen = true
            ns.Print(L.bartenderDetected)
        end
        if not db.bartenderOffHintSeen and self:IsStatusBarHidden() then
            -- Check again shortly: right after login the container may not be placed yet.
            C_Timer.After(HINT_RETRY, function()
                if db.bartenderOffHintSeen or not self:IsStatusBarHidden() then return end
                db.bartenderOffHintSeen = true
                ns.Print(L.bartenderStatusBarOff)
            end)
        end
    end)
end

-- For /xpf debug: where Blizzard's containers hang and how Bartender scales them.
function Bartender:DebugInfo()
    local result = { loaded = self:IsActive(), statusBarHidden = self:IsStatusBarHidden() }
    local manager = StatusTrackingBarManager
    if manager then
        local parent = manager:GetParent()
        result.managerParent = parent and parent:GetDebugName()
        result.managerVisible = manager:IsVisible()
        result.managerScale = manager:GetEffectiveScale()
    end
    local bar = ns.Bar.frame
    if bar then
        result.barParent = bar:GetParent():GetDebugName()
        result.barVisible = bar:IsVisible()
        result.barWidth = bar:GetWidth()
    end
    return result
end
