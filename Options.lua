local addonName, ns = ...
local L = ns.L

-- Settings under Options → AddOns → XPForever, built with Blizzard's Settings API.
-- Main page: experience bar. Sub pages: colors, info text, statistics & reset.
local Options = { settings = {}, categories = {} }
ns.Options = Options

StaticPopupDialogs["XPFOREVER_RESET_SETTINGS"] = {
    text = L.optResetSettingsConfirm,
    button1 = YES,
    button2 = NO,
    OnAccept = function() Options:ResetToDefaults() end,
    showAlert = true,
    hideOnEscape = true,
    whileDead = true,
    timeout = 0,
}

local function Header(category, text)
    local layout = SettingsPanel:GetLayout(category)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
end

local function Button(category, name, buttonText, onClick, tooltip)
    local layout = SettingsPanel:GetLayout(category)
    layout:AddInitializer(CreateSettingsButtonInitializer(name, buttonText, onClick, tooltip, true))
end

local function Register(category, key, name)
    local default = ns.defaults[key]
    local setting = Settings.RegisterAddOnSetting(category, "XPForever_" .. key, key, XPForeverDB,
        type(default), name, default)
    setting:SetValueChangedCallback(function() ns.ApplySettings() end)
    Options.settings[key] = setting
    return setting
end

local function Checkbox(category, key, name, tooltip)
    return Settings.CreateCheckbox(category, Register(category, key, name), tooltip)
end

local function FormatPercentLabel(value)
    return string.format("%d %%", value)
end

local function Slider(category, key, name, tooltip, min, max, step, formatter)
    local options = Settings.CreateSliderOptions(min, max, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
    return Settings.CreateSlider(category, Register(category, key, name), options, tooltip)
end

-- entries: list of { value, label }
local function Dropdown(category, key, name, tooltip, entries)
    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        for _, entry in ipairs(entries) do
            container:Add(entry[1], entry[2])
        end
        return container:GetData()
    end
    return Settings.CreateDropdown(category, Register(category, key, name), GetOptions, tooltip)
end

local function ColorSwatch(category, key, name)
    return Settings.CreateColorSwatch(category, Register(category, key, name))
end

-- Only enable a control while a condition is met (grayed out otherwise).
-- Blizzard re-evaluates the condition whenever the parent initializer's setting changes.
local function DependsOn(initializer, parentInitializer, predicate)
    initializer:SetParentInitializer(parentInitializer, predicate)
end

-- Checkboxes for all text items (ns.TEXT_ITEMS); prefix is "bar" or "info".
local function ContentCheckboxes(category, prefix, parentInitializer, predicate)
    for _, item in ipairs(ns.TEXT_ITEMS) do
        local name, tooltip = L["optItem" .. item.id], L["optItem" .. item.id .. "Tip"]
        local checkbox = Checkbox(category, prefix .. item.id, name, tooltip)
        DependsOn(checkbox, parentInitializer, predicate)
    end
end

local function RegisterBarPage(category)
    Header(category, L.optSectionLook)
    local style = Dropdown(category, "barStyle", L.optStyle, L.optStyleTip, {
        { "modern", L.optStyleModern },
        { "classic", L.optStyleClassic },
    })
    -- Height and our own segments only exist in the Modern style (Classic uses Blizzard's size).
    local function IsModern() return XPForeverDB.barStyle ~= "classic" end
    DependsOn(Slider(category, "height", L.optHeight, L.optHeightTip, 12, 32, 1), style, IsModern)
    DependsOn(Checkbox(category, "showSegments", L.optSegments, L.optSegmentsTip), style, IsModern)
    Checkbox(category, "showPercent", L.optPercent, L.optPercentTip)
    Checkbox(category, "animate", L.optAnimate, L.optAnimateTip)

    Header(category, L.optSectionPreview)
    Checkbox(category, "showQuestXP", L.optQuestXP, L.optQuestXPTip)
    Checkbox(category, "showRestedXP", L.optRestedXP, L.optRestedXPTip)
    local restIndicator = Checkbox(category, "showRestIndicator", L.optRestIndicator, L.optRestIndicatorTip)
    DependsOn(Checkbox(category, "showRestGlow", L.optRestGlow, L.optRestGlowTip), restIndicator,
        function() return XPForeverDB.showRestIndicator end)

    Header(category, L.optSectionMouse)
    Checkbox(category, "showTooltip", L.optTooltip, L.optTooltipTip)
    Checkbox(category, "showMinimapButton", L.optMinimap, L.optMinimapTip)

    Header(category, L.optSectionBarText)
    local mode = Dropdown(category, "barTextMode", L.optBarText, L.optBarTextTip, {
        { "hover", L.optBarTextHover },
        { "always", L.optBarTextAlways },
        { "never", L.optBarTextNever },
    })
    ContentCheckboxes(category, "bar", mode, function() return XPForeverDB.barTextMode ~= "never" end)

    -- End of the main page: name, author and version.
    Header(category, L.aboutLine:format(ns.BrandLine(), ns.VERSION))
end

local function RegisterColorsPage(category)
    Header(category, L.optSectionColors)
    -- Blizzard's settings color picker has no opacity, so there is a slider below each color.
    ColorSwatch(category, "colorXP", L.optColorXP)
    ColorSwatch(category, "colorQuest", L.optColorQuest)
    Slider(category, "questOpacity", L.optQuestOpacity, L.optOpacityTip, 10, 100, 5, FormatPercentLabel)
    ColorSwatch(category, "colorRested", L.optColorRested)
    Slider(category, "restedOpacity", L.optRestedOpacity, L.optOpacityTip, 10, 100, 5, FormatPercentLabel)
    Checkbox(category, "fillGradient", L.optGradient, L.optGradientTip)
end

local function RegisterInfoPage(category)
    Header(category, L.optSectionInfoGeneral)
    local enabled = Checkbox(category, "infoEnabled", L.optInfoEnabled, L.optInfoEnabledTip)
    local function IsEnabled() return XPForeverDB.infoEnabled end

    local position = Dropdown(category, "infoPosition", L.optInfoPosition, L.optInfoPositionTip, {
        { "auto", L.optInfoPositionAuto },
        { "free", L.optInfoPositionFree },
    })
    DependsOn(position, enabled, IsEnabled)

    local offset = Slider(category, "infoOffset", L.optInfoOffset, L.optInfoOffsetTip, 0, 40, 1)
    DependsOn(offset, position, function() return IsEnabled() and XPForeverDB.infoPosition == "auto" end)

    DependsOn(Slider(category, "infoFontSize", L.optInfoFontSize, nil, 9, 20, 1), enabled, IsEnabled)

    Header(category, L.optSectionInfoContent)
    ContentCheckboxes(category, "info", enabled, IsEnabled)
end

local function RegisterStatsPage(category)
    Header(category, L.optSectionStats)
    Dropdown(category, "rateWindow", L.optRateWindow, L.optRateWindowTip, {
        { 600, L.optRateWindow10 },
        { 1800, L.optRateWindow30 },
        { 0, L.optRateWindowSession },
    })

    -- Our own button instead of Blizzard's "Defaults", which resets either the whole game (including
    -- key bindings) or only the page that is currently open.
    Header(category, L.optSectionReset)
    Button(category, L.optResetSession, L.optResetSessionButton, function() ns.ResetSession() end,
        L.optResetSessionTip)
    Button(category, L.optResetSettings, L.optResetSettingsButton,
        function() StaticPopup_Show("XPFOREVER_RESET_SETTINGS") end, L.optResetSettingsTip)
end

-- Hide Blizzard's "Defaults" button (top right) on our pages (see above) and show it again on
-- other pages. We only touch it when necessary.
local function HideDefaultsButtonOnOurPages()
    local button = SettingsPanel:GetSettingsList().Header.DefaultsButton
    local hiddenByUs = false

    local function IsOurs(category)
        return category and Options.categories[category] or false
    end

    hooksecurefunc(SettingsPanel, "DisplayCategory", function(_, category)
        if IsOurs(category) then
            button:Hide()
            hiddenByUs = true
        elseif hiddenByUs then
            button:Show()
            hiddenByUs = false
        end
    end)
    -- Blizzard shows it again e.g. after the search box is cleared.
    button:HookScript("OnShow", function()
        if IsOurs(SettingsPanel:GetCurrentCategory()) then
            button:Hide()
            hiddenByUs = true
        end
    end)
end

function Options:Register()
    local category = Settings.RegisterVerticalLayoutCategory(addonName)
    RegisterBarPage(category)

    local colorsCategory = Settings.RegisterVerticalLayoutSubcategory(category, L.optColorsCategory)
    RegisterColorsPage(colorsCategory)

    local infoCategory = Settings.RegisterVerticalLayoutSubcategory(category, L.optInfoCategory)
    RegisterInfoPage(infoCategory)

    local statsCategory = Settings.RegisterVerticalLayoutSubcategory(category, L.optStatsCategory)
    RegisterStatsPage(statsCategory)

    Settings.RegisterAddOnCategory(category)
    self.category = category
    for _, ours in ipairs({ category, colorsCategory, infoCategory, statsCategory }) do
        self.categories[ours] = true
    end
    HideDefaultsButtonOnOurPages()
end

function Options:Open()
    if InCombatLockdown() then
        ns.Print(L.notInCombat)
        return
    end
    Settings.OpenToCategory(self.category:GetID())
end

-- Offer the style choice only once. In combat, wait until it is over.
local STYLE_PROMPT_DELAY = 3
local STYLE_PROMPT_RETRY = 5

function Options:ShowStylePromptOnce()
    if XPForeverDB.stylePromptSeen then return end
    C_Timer.After(STYLE_PROMPT_DELAY, function()
        if XPForeverDB.stylePromptSeen then return end
        if InCombatLockdown() then
            C_Timer.After(STYLE_PROMPT_RETRY, function() self:ShowStylePromptOnce() end)
            return
        end
        XPForeverDB.stylePromptSeen = true
        self:ShowStylePrompt()
    end)
end

-- Small chooser at the top center: Modern / Classic side by side. A click switches the bar live, so the
-- result is visible right away. Deliberately not added to UISpecialFrames (Escape): adding frames there
-- can taint Blizzard's window handling.
local PROMPT_WIDTH, PROMPT_HEIGHT = 360, 150
local PROMPT_BUTTON_WIDTH, PROMPT_BUTTON_HEIGHT = 120, 30

function Options:UpdateStylePrompt()
    local prompt = self.stylePrompt
    if not prompt then return end
    for style, button in pairs(prompt.buttons) do
        if XPForeverDB.barStyle == style then button:LockHighlight() else button:UnlockHighlight() end
    end
end

function Options:ShowStylePrompt()
    local prompt = self.stylePrompt
    if not prompt then
        prompt = CreateFrame("Frame", "XPForeverStylePrompt", UIParent)
        prompt:SetSize(PROMPT_WIDTH, PROMPT_HEIGHT)
        prompt:SetPoint("TOP", 0, -140)
        prompt:SetFrameStrata("DIALOG")
        prompt:SetToplevel(true)
        prompt:EnableMouse(true)

        -- Blizzard's dialog border as a child frame: the template uses setAllPoints and would stretch a
        -- window that inherits it directly to the size of the screen.
        local border = CreateFrame("Frame", nil, prompt, "DialogBorderTemplate")
        border:SetAllPoints()
        border:SetFrameLevel(prompt:GetFrameLevel())
        -- Texts on their own level above the border background.
        local content = CreateFrame("Frame", nil, prompt)
        content:SetAllPoints()
        content:SetFrameLevel(border:GetFrameLevel() + 5)

        local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -20)
        title:SetText(addonName)

        prompt.buttons = {}
        for index, entry in ipairs({ { "modern", L.optStyleModern }, { "classic", L.optStyleClassic } }) do
            local button = CreateFrame("Button", nil, prompt, "UIPanelButtonTemplate")
            button:SetSize(PROMPT_BUTTON_WIDTH, PROMPT_BUTTON_HEIGHT)
            button:SetPoint("TOP", (index == 1 and -1 or 1) * (PROMPT_BUTTON_WIDTH / 2 + 6), -52)
            button:SetText(entry[2])
            button:SetScript("OnClick", function()
                self:SetValue("barStyle", entry[1])
                self:UpdateStylePrompt()
            end)
            prompt.buttons[entry[1]] = button
        end

        -- One line on how to get to the settings, with the same mouse icon as in the tooltips.
        local hint = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        hint:SetPoint("TOP", 0, -92)
        hint:SetWordWrap(false)
        hint:SetText(ns.ClickHint("RightButton", nil, L.stylePromptHint, L.stylePromptHint))

        local ok = CreateFrame("Button", nil, prompt, "UIPanelButtonTemplate")
        ok:SetSize(100, 24)
        ok:SetPoint("BOTTOM", 0, 16)
        ok:SetText(OKAY)
        ok:SetScript("OnClick", function() prompt:Hide() end)

        local close = CreateFrame("Button", nil, prompt, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)

        self.stylePrompt = prompt
    end
    self:UpdateStylePrompt()
    prompt:Show()
end

-- Change a setting from outside (e.g. a minimap click) so the settings panel stays in sync.
function Options:SetValue(key, value)
    local setting = self.settings[key]
    if setting then
        setting:SetValue(value)
    else
        XPForeverDB[key] = value
        ns.ApplySettings()
    end
end

-- Reset through the registered settings so an open settings panel stays in sync.
function Options:ResetToDefaults()
    for key in pairs(ns.defaults) do
        local setting = self.settings[key]
        if setting then
            setting:SetValue(ns.GetDefault(key))
        else
            XPForeverDB[key] = ns.GetDefault(key)
        end
    end
    XPForeverDB.infoPoint = nil
    ns.ApplySettings()
    ns.Print(L.settingsReset)
end
