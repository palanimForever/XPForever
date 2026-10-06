local addonName, ns = ...
local L = ns.L

-- Einstellungen unter Optionen → AddOns → XPForever, aufgebaut mit Blizzards Settings-API.
-- Hauptseite: Erfahrungsleiste. Unterseiten: Farben, Info-Text, Statistik & Zurücksetzen.
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

-- entries: Liste aus { value, label }
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

-- Ein Steuerelement nur bedienbar machen, wenn eine Bedingung erfüllt ist (sonst ausgegraut).
-- Blizzard wertet die Bedingung neu aus, sobald sich das Setting des Eltern-Initializers ändert.
local function DependsOn(initializer, parentInitializer, predicate)
    initializer:SetParentInitializer(parentInitializer, predicate)
end

-- Checkboxen für alle Textbausteine (ns.TEXT_ITEMS); prefix ist "bar" oder "info".
local function ContentCheckboxes(category, prefix, parentInitializer, predicate)
    for _, item in ipairs(ns.TEXT_ITEMS) do
        local name, tooltip = L["optItem" .. item.id], L["optItem" .. item.id .. "Tip"]
        local checkbox = Checkbox(category, prefix .. item.id, name, tooltip)
        DependsOn(checkbox, parentInitializer, predicate)
    end
end

local function RegisterBarPage(category)
    Header(category, L.optSectionLook)
    Slider(category, "height", L.optHeight, L.optHeightTip, 12, 32, 1)
    Checkbox(category, "showSegments", L.optSegments, L.optSegmentsTip)
    Checkbox(category, "showPercent", L.optPercent, L.optPercentTip)
    Checkbox(category, "animate", L.optAnimate, L.optAnimateTip)

    Header(category, L.optSectionPreview)
    Checkbox(category, "showQuestXP", L.optQuestXP, L.optQuestXPTip)
    Checkbox(category, "showRestedXP", L.optRestedXP, L.optRestedXPTip)
    Checkbox(category, "showRestIndicator", L.optRestIndicator, L.optRestIndicatorTip)

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

    -- Abschluss der Hauptseite: Name, Autor und Version.
    Header(category, L.aboutLine:format(ns.BrandLine(), ns.VERSION))
end

local function RegisterColorsPage(category)
    Header(category, L.optSectionColors)
    -- Blizzards Farbwähler in den Settings bietet keine Deckkraft, deshalb je ein Regler darunter.
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

    -- Eigener Button statt Blizzards "Standard": Der setzt wahlweise das ganze Spiel (inkl.
    -- Tastenbelegung) oder nur die gerade offene Unterseite zurück.
    Header(category, L.optSectionReset)
    Button(category, L.optResetSession, L.optResetSessionButton, function() ns.ResetSession() end,
        L.optResetSessionTip)
    Button(category, L.optResetSettings, L.optResetSettingsButton,
        function() StaticPopup_Show("XPFOREVER_RESET_SETTINGS") end, L.optResetSettingsTip)
end

-- Blizzards "Standard"-Button oben rechts auf unseren Seiten ausblenden (siehe oben) und auf
-- fremden Seiten wieder einblenden. Wir fassen ihn nur an, wenn es nötig ist.
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
    -- Blizzard blendet ihn z. B. nach dem Leeren der Suche wieder ein.
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

-- Einstellung von außen ändern (z. B. per Minimap-Klick), damit das Optionsfenster mitzieht.
function Options:SetValue(key, value)
    local setting = self.settings[key]
    if setting then
        setting:SetValue(value)
    else
        XPForeverDB[key] = value
        ns.ApplySettings()
    end
end

-- Über die registrierten Settings zurücksetzen, damit das offene Optionsfenster mitzieht.
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
