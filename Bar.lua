local addonName, ns = ...
local L = ns.L
local state = ns.state

local WHITE = "Interface\\Buttons\\WHITE8x8"
local NUM_SEGMENTS = 20
local BORDER = 2 -- Bronze-Rand in Pixeln
local INNER_SHADOW = 1 -- dunkle Linie zwischen Rand und Füllung
local TEXT_FADE_DURATION = 0.15
local GLOW_SIZE = 6
local GRADIENT_SHADE = 0.55 -- Helligkeit der Unterkante beim Farbverlauf
local ANIM_DURATION = 0.4
local FLASH_DURATION = 0.8

-- Blizzards Original-Texturen der XP-Leiste (siehe wiki/ui-style.md), für den Classic-Stil.
local CLASSIC_ATLAS = {
    background = "UI-HUD-ExperienceBar-Background",
    fillXP = "UI-HUD-ExperienceBar-Fill-Experience",
    prediction = "UI-HUD-ExperienceBar-Fill-Prediction",
}
local WHITE_COLOR = CreateColor(1, 1, 1)

-- Dunkler Hintergrund und Bronze-Rand wie die Forever-Aktionsleisten.
-- Die Füllfarben kommen aus den Einstellungen (ns.GetColor).
local COLORS = {
    border = CreateColor(0.62, 0.48, 0.27, 1),
    borderLight = CreateColor(0.86, 0.70, 0.44, 1), -- Oberkante: wie geprägtes Metall
    borderDark = CreateColor(0.36, 0.26, 0.14, 1), -- Unterkante
    innerShadow = CreateColor(0, 0, 0, 0.8), -- trennt den Rand von jeder Füllfarbe
    background = CreateColor(0.04, 0.05, 0.09, 1),
    divider = CreateColor(0, 0, 0, 0.55),
    dividerHighlight = CreateColor(1, 1, 1, 0.12),
    restGlow = CreateColor(1.00, 0.82, 0.35),
}

local Bar = {}
ns.Bar = Bar

local function Colorize(text, color)
    return WrapTextInColorCode(text, color:GenerateHexColor())
end

-- Ohne Farbverlauf entspricht die Füllung exakt der gewählten Farbe.
local function SetFillColor(tex, color, alpha)
    local r, g, b = color:GetRGB()
    local shade = XPForeverDB.fillGradient and GRADIENT_SHADE or 1
    tex:SetGradient("VERTICAL", CreateColor(r * shade, g * shade, b * shade, alpha), CreateColor(r, g, b, alpha))
end

local function CreateFill(parent, subLevel)
    local tex = parent:CreateTexture(nil, "ARTWORK", nil, subLevel)
    tex:SetTexture(WHITE)
    tex:Hide()
    return tex
end

-- Moderner Stil: einfarbige Füllung (mit optionalem Farbverlauf).
local function UseColorFill(tex, color, alpha)
    tex.atlas = nil
    tex:SetTexture(WHITE)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetDesaturated(false)
    SetFillColor(tex, color, alpha)
end

-- Classic-Stil: Blizzards Original-Textur. SetSpan schneidet sie später zu, statt sie zu stauchen.
-- Fehlt der Atlas im Client, bleibt es bei der einfarbigen Füllung.
local function UseAtlasFill(tex, atlas, color, alpha, desaturate)
    local info = C_Texture.GetAtlasInfo(atlas)
    if not info then
        UseColorFill(tex, color, alpha)
        return
    end
    tex:SetAtlas(atlas)
    tex.atlas = info
    tex:SetDesaturated(desaturate or false)
    -- Den Farbverlauf des modernen Stils ausdrücklich durch eine einheitliche Farbe ersetzen,
    -- sonst bleibt seine Abdunkelung auf Blizzards Textur liegen.
    local r, g, b = color:GetRGB()
    local flat = CreateColor(r, g, b, alpha)
    tex:SetGradient("VERTICAL", flat, flat)
    tex:SetVertexColor(r, g, b, alpha)
end

-- Spannt eine Textur über den Bereich [from, to] (Anteile 0..1) der Leiste. Atlas-Texturen werden
-- wie bei Blizzards StatusBar passend beschnitten, damit sie bei jedem Füllstand unverzerrt bleiben.
local function SetSpan(tex, from, to)
    local width = Bar.inner:GetWidth()
    from = math.max(0, math.min(from, 1))
    to = math.max(0, math.min(to, 1))
    if to <= from or width <= 0 then
        tex:Hide()
        return
    end
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", Bar.inner, "TOPLEFT", from * width, 0)
    tex:SetPoint("BOTTOMLEFT", Bar.inner, "BOTTOMLEFT", from * width, 0)
    tex:SetWidth(math.max((to - from) * width, 1))
    local atlas = tex.atlas
    if atlas then
        local left, right = atlas.leftTexCoord, atlas.rightTexCoord
        tex:SetTexCoord(left + (right - left) * from, left + (right - left) * to,
            atlas.topTexCoord, atlas.bottomTexCoord)
    end
    tex:Show()
end

local function CreateText(parent, justify, fontObject)
    local text = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlightSmall")
    text:SetJustifyH(justify)
    text:SetShadowOffset(1, -1)
    return text
end

-- Die Blizzard-XP-Leiste unsichtbar machen. Ihr Container bleibt bestehen, damit die
-- Aktionsleisten-Anordnung im Edit Mode nicht verrutscht und die Leiste dort verschiebbar bleibt.
-- Blizzard-Frames dauerhaft unsichtbar halten: Das Spiel setzt ihre Transparenz zur Laufzeit wieder auf 1
-- (per /xpf debug beobachtet, 2026-10-06; im Lua-Code nicht auffindbar). Deshalb jedes erneute Sichtbarmachen
-- sofort zurücknehmen und es zusätzlich bei jedem Neuzeichnen sicherstellen.
local silenced = setmetatable({}, { __mode = "k" })

local function Silence(frame)
    frame:SetAlpha(0)
    frame:EnableMouse(false)
    if not silenced[frame] then
        silenced[frame] = true
        hooksecurefunc(frame, "SetAlpha", function(self, alpha)
            if alpha and alpha > 0 then self:SetAlpha(0) end
        end)
        frame:HookScript("OnShow", function(self) self:SetAlpha(0) end)
    end
end

-- Die Blizzard-XP-Leiste samt Erholungs-Marker unsichtbar machen. Ihr Container bleibt bestehen, damit die
-- Aktionsleisten-Anordnung im Edit Mode nicht verrutscht und die Leiste dort verschiebbar bleibt.
local function HideBlizzardBar()
    if not (StatusTrackingBarManager and StatusTrackingBarInfo) then return end
    local index = StatusTrackingBarInfo.BarsEnum.Experience
    for _, container in ipairs(StatusTrackingBarManager.barContainers or {}) do
        local bar = container.bars and container.bars[index]
        if bar then
            Silence(bar)
            -- Der Marker kennt keine Quest-XP und stünde an der falschen Stelle.
            if bar.ExhaustionTick then Silence(bar.ExhaustionTick) end
        end
    end
end

-- Vier Linien entlang der Innenseite von `frame` (thickness Pixel breit). Für Rahmen, die eine
-- Füllung nicht verdecken dürfen.
local function CreateEdges(parent, frame, thickness, color, layer, subLevel)
    local edges = {
        { "TOPLEFT", "TOPRIGHT", nil, thickness },
        { "BOTTOMLEFT", "BOTTOMRIGHT", nil, thickness },
        { "TOPLEFT", "BOTTOMLEFT", thickness, nil },
        { "TOPRIGHT", "BOTTOMRIGHT", thickness, nil },
    }
    local lines = {}
    for _, edge in ipairs(edges) do
        local line = parent:CreateTexture(nil, layer, nil, subLevel)
        line:SetColorTexture(color:GetRGBA())
        line:SetPoint(edge[1], frame, edge[1])
        line:SetPoint(edge[2], frame, edge[2])
        if edge[3] then line:SetWidth(edge[3]) end
        if edge[4] then line:SetHeight(edge[4]) end
        table.insert(lines, line)
    end
    return lines
end

-- Goldenes Leuchten im Erholungsgebiet, angelehnt an das Leuchten des Spielerrahmens.
-- Animiert wird nur das Alpha des Frames: Alpha-Animationen direkt auf Texturen mit
-- SetGradient färbten diese weiß (siehe Wiki).
local function CreateRestGlow(f)
    -- Position setzt Bar:Anchor: modern um unsere Leiste, classic um Blizzards Rahmen.
    local restGlow = CreateFrame("Frame", nil, f)
    restGlow:SetAllPoints()
    restGlow:Hide()

    -- Modern: goldene Rahmenkanten über dem Bronze-Rand plus weicher Schein oben und unten.
    restGlow.modernPieces = CreateEdges(restGlow, restGlow, BORDER, COLORS.restGlow, "OVERLAY")
    -- Classic: Blizzards Rahmengrafik golden und additiv darübergelegt (exakt dieselbe Form).
    restGlow.classicFrame = restGlow:CreateTexture(nil, "OVERLAY")
    restGlow.classicFrame:SetBlendMode("ADD")

    local r, g, b = COLORS.restGlow:GetRGB()
    local glowTop = restGlow:CreateTexture(nil, "BACKGROUND")
    glowTop:SetTexture(WHITE)
    glowTop:SetPoint("BOTTOMLEFT", restGlow, "TOPLEFT")
    glowTop:SetPoint("BOTTOMRIGHT", restGlow, "TOPRIGHT")
    glowTop:SetHeight(GLOW_SIZE)
    glowTop:SetGradient("VERTICAL", CreateColor(r, g, b, 0.35), CreateColor(r, g, b, 0))

    local glowBottom = restGlow:CreateTexture(nil, "BACKGROUND")
    glowBottom:SetTexture(WHITE)
    glowBottom:SetPoint("TOPLEFT", restGlow, "BOTTOMLEFT")
    glowBottom:SetPoint("TOPRIGHT", restGlow, "BOTTOMRIGHT")
    glowBottom:SetHeight(GLOW_SIZE)
    glowBottom:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.35))
    table.insert(restGlow.modernPieces, glowTop)
    table.insert(restGlow.modernPieces, glowBottom)

    local breathe = restGlow:CreateAnimationGroup()
    breathe:SetLooping("BOUNCE")
    local fade = breathe:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.35)
    fade:SetToAlpha(0.8)
    fade:SetDuration(2)
    fade:SetSmoothing("IN_OUT")

    return restGlow, breathe
end

-- Dieselbe animierte "Zzz"-Grafik wie am Spielerporträt.
local function CreateRestIcon(parent)
    local restIcon = CreateFrame("Frame", nil, parent)
    restIcon:SetSize(20, 20)
    restIcon:SetPoint("RIGHT", -4, 1)
    restIcon:Hide()
    local restTexture = restIcon:CreateTexture(nil, "ARTWORK")
    restTexture:SetAtlas("UI-HUD-UnitFrame-Player-Rest-Flipbook")
    restTexture:SetSize(22, 22)
    restTexture:SetPoint("CENTER")
    local restAnim = restIcon:CreateAnimationGroup()
    restAnim:SetLooping("REPEAT")
    local flipBook = restAnim:CreateAnimation("FlipBook")
    flipBook:SetTarget(restTexture)
    flipBook:SetDuration(1.5)
    flipBook:SetFlipBookRows(7)
    flipBook:SetFlipBookColumns(6)
    flipBook:SetFlipBookFrames(42)
    flipBook:SetFlipBookFrameWidth(0)
    flipBook:SetFlipBookFrameHeight(0)
    return restIcon, restAnim
end

function Bar:Init()
    if self.frame then return end

    local f = CreateFrame("Frame", "XPForeverBar", UIParent)
    f:SetFrameStrata("MEDIUM")
    f:EnableMouse(true)
    self.frame = f

    local border = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    border:SetAllPoints()
    border:SetColorTexture(COLORS.border:GetRGBA())

    -- Metall-Effekt: hellere Oberkante, dunklere Unterkante des Bronze-Rands.
    local borderTop = f:CreateTexture(nil, "BACKGROUND")
    borderTop:SetColorTexture(COLORS.borderLight:GetRGBA())
    borderTop:SetPoint("TOPLEFT")
    borderTop:SetPoint("TOPRIGHT")
    borderTop:SetHeight(1)
    local borderBottom = f:CreateTexture(nil, "BACKGROUND")
    borderBottom:SetColorTexture(COLORS.borderDark:GetRGBA())
    borderBottom:SetPoint("BOTTOMLEFT")
    borderBottom:SetPoint("BOTTOMRIGHT")
    borderBottom:SetHeight(1)
    -- Teile, die nur der moderne Stil zeigt (im Classic-Stil übernimmt Blizzards Rahmen).
    self.modernParts = { border, borderTop, borderBottom }

    local inner = CreateFrame("Frame", nil, f)
    self.inner = inner

    local background = inner:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    self.background = background

    self.xpFill = CreateFill(inner, 2)
    self.questFill = CreateFill(inner, 1)
    self.restedFill = CreateFill(inner, 0)

    self.spark = inner:CreateTexture(nil, "ARTWORK", nil, 3)
    self.spark:SetColorTexture(1, 1, 1, 0.9)
    self.spark:SetBlendMode("ADD")
    self.spark:SetWidth(2)

    self.restGlow, self.restGlowAnim = CreateRestGlow(f)

    -- Aufleuchten bei XP-Gewinn: eigener Frame zwischen Füllungen und Trennern. Animiert wird
    -- das Frame-Alpha, nicht die Textur (siehe Wiki: Alpha-Animation auf Texturen).
    local flashFrame = CreateFrame("Frame", nil, inner)
    flashFrame:SetAllPoints()
    flashFrame:SetFrameLevel(inner:GetFrameLevel() + 1)
    flashFrame:Hide()
    self.flashFrame = flashFrame
    self.flashTexture = flashFrame:CreateTexture(nil, "ARTWORK")
    self.flashTexture:SetBlendMode("ADD")
    local flashAnim = flashFrame:CreateAnimationGroup()
    local flashFade = flashAnim:CreateAnimation("Alpha")
    flashFade:SetFromAlpha(0.6)
    flashFade:SetToAlpha(0)
    flashFade:SetDuration(FLASH_DURATION)
    flashFade:SetSmoothing("OUT")
    flashAnim:SetScript("OnFinished", function() flashFrame:Hide() end)
    self.flashAnim = flashAnim

    -- Treibt die Gleit-Animation; OnUpdate ist nur gesetzt, solange sie läuft.
    self.animator = CreateFrame("Frame", nil, f)

    local overlay = CreateFrame("Frame", nil, inner)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(inner:GetFrameLevel() + 5)

    -- Trenner als "Gravur": dunkle Linie plus helle Kante rechts daneben, damit sie
    -- auf dem leeren Hintergrund dezent bleiben und auf farbigen Füllungen sichtbar sind.
    self.dividers = {}
    for i = 1, NUM_SEGMENTS - 1 do
        local divider = overlay:CreateTexture(nil, "BACKGROUND")
        divider:SetColorTexture(COLORS.divider:GetRGBA())
        divider:SetWidth(1)
        divider.highlight = overlay:CreateTexture(nil, "BACKGROUND")
        divider.highlight:SetColorTexture(COLORS.dividerHighlight:GetRGBA())
        divider.highlight:SetWidth(1)
        divider.highlight:SetPoint("TOPLEFT", divider, "TOPRIGHT")
        divider.highlight:SetPoint("BOTTOMLEFT", divider, "BOTTOMRIGHT")
        self.dividers[i] = divider
    end

    -- Dunkle Innenlinie über den Füllungen: Rand und Füllung bleiben bei jeder Farbe unterscheidbar.
    for _, line in ipairs(CreateEdges(overlay, inner, INNER_SHADOW, COLORS.innerShadow, "BORDER")) do
        table.insert(self.modernParts, line)
    end
    self.overlay = overlay

    -- Eigener Frame für die Hover-Texte, damit sie gemeinsam ein- und ausgeblendet werden können.
    local texts = CreateFrame("Frame", nil, overlay)
    texts:SetAllPoints()
    texts:SetAlpha(0)
    self.texts = texts

    -- Eine Zeile aus den gewählten Textbausteinen; zu lange Zeilen werden mit "…" gekürzt.
    self.hoverText = CreateText(texts, "CENTER")
    self.hoverText:SetPoint("LEFT", 6, 0)
    self.hoverText:SetPoint("RIGHT", -6, 0)
    self.hoverText:SetWordWrap(false)

    -- Prozentzahl: Gold mit feiner Kontur, ohne zusätzlichen Schatten.
    self.percentText = CreateText(overlay, "CENTER", "GameFontNormal")
    self.percentText:SetPoint("CENTER", 0, 0)
    self.percentText:SetShadowOffset(0, 0)
    local font, size = self.percentText:GetFont()
    self.percentText:SetFont(font, size, "OUTLINE")
    self.percentFont = { font, size }

    -- Das Zzz teilt sich den Platz mit dem rechten Text und blendet gegenläufig.
    self.restIcon, self.restIconAnim = CreateRestIcon(overlay)

    -- Auf die Größe von inner reagieren: Nur dann ist dessen Breite garantiert schon berechnet.
    inner:SetScript("OnSizeChanged", function(_, width) self:Layout(width) end)
    f:SetScript("OnEnter", function()
        self.hovered = true
        self:UpdateTextVisibility()
        if XPForeverDB.showTooltip then self:ShowTooltip() end
    end)
    f:SetScript("OnLeave", function()
        self.hovered = false
        self:UpdateTextVisibility()
        GameTooltip_Hide()
    end)
    f:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and IsControlKeyDown() then
            ns.ResetSession()
            if self.hovered and XPForeverDB.showTooltip then self:ShowTooltip() end
        elseif button == "LeftButton" then
            ns.ToggleInfoText()
        elseif button == "RightButton" then
            ns.Options:Open()
        end
    end)

    -- Blizzard verteilt XP-, Ruf- und andere Leisten auf zwei Container und sortiert bei Änderungen
    -- (z. B. "Ruf beobachten") um. Danach jeweils neu verankern.
    if StatusTrackingBarManager then
        for _, container in ipairs(StatusTrackingBarManager.barContainers or {}) do
            container:HookScript("OnSizeChanged", function() self:Anchor() end)
            hooksecurefunc(container, "ApplyPendingBarToShow", function() self:Anchor() end)
        end
    end

    HideBlizzardBar()
end

-- Einstellungen anwenden, die nicht bei jedem XP-Update neu gesetzt werden müssen.
local function IsClassic()
    return XPForeverDB.barStyle == "classic"
end

-- Füllungen je nach Stil: modern einfarbig, classic mit Blizzards Texturen.
function Bar:UpdateFills()
    local db = XPForeverDB
    local questColor, questAlpha = ns.GetColor("colorQuest"), db.questOpacity / 100
    if not IsClassic() then
        self.fillStyle = nil
        UseColorFill(self.xpFill, ns.GetColor("colorXP"), 1)
        UseColorFill(self.questFill, questColor, questAlpha)
        UseColorFill(self.restedFill, ns.GetColor("colorRested"), db.restedOpacity / 100)
        return
    end
    -- Blizzard färbt die XP blau, solange man erholt ist; neben der blauen Erholungs-Vorschau wären XP
    -- und Erholung dann kaum zu unterscheiden. Deshalb bleibt die XP hier immer lila.
    local style = questColor:GenerateHexColor() .. questAlpha
    if self.fillStyle == style then return end
    self.fillStyle = style
    UseAtlasFill(self.xpFill, CLASSIC_ATLAS.fillXP, WHITE_COLOR, 1)
    -- Quest-XP gibt es im Original nicht. Eingefärbte Blizzard-Texturen waren in Forever unsichtbar
    -- (beobachtet 2026-10-06), deshalb wie im modernen Stil als einfarbige Fläche.
    UseColorFill(self.questFill, questColor, questAlpha)
    UseAtlasFill(self.restedFill, CLASSIC_ATLAS.prediction, WHITE_COLOR, 1)
end

function Bar:ApplySettings()
    if not self.frame then return end
    local db = XPForeverDB
    local classic = IsClassic()

    -- Rahmen: modern eigener Bronze-Rand, classic Blizzards Rahmen und Trenner (der Container bleibt sichtbar).
    for _, part in ipairs(self.modernParts) do part:SetShown(not classic) end
    local inset = classic and 0 or BORDER
    self.inner:ClearAllPoints()
    self.inner:SetPoint("TOPLEFT", inset, -inset)
    self.inner:SetPoint("BOTTOMRIGHT", -inset, inset)
    if classic and C_Texture.GetAtlasInfo(CLASSIC_ATLAS.background) then
        self.background:SetAtlas(CLASSIC_ATLAS.background)
    else
        self.background:SetColorTexture(COLORS.background:GetRGBA())
    end

    self.fillStyle = nil
    self:UpdateFills()

    for _, divider in ipairs(self.dividers) do
        divider:SetShown(db.showSegments and not classic)
        divider.highlight:SetShown(db.showSegments and not classic)
    end

    -- Prozentzahl: modern Gold mit Kontur, classic wie Blizzards Leistentext.
    if classic then
        self.percentText:SetFontObject("TextStatusBarText")
        self.percentText:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
        self.percentText:SetShadowOffset(1, -1)
    else
        self.percentText:SetFont(self.percentFont[1], self.percentFont[2], "OUTLINE")
        self.percentText:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
        self.percentText:SetShadowOffset(0, 0)
    end
    self.percentText:SetShown(db.showPercent)
    self.restIcon:SetScale(classic and 0.8 or 1)

    self:Anchor()
    self:UpdateTextVisibility(true)
    self:UpdateResting()
end

-- Der Container, in dem Blizzard gerade die XP-Leiste zeigt (bzw. gleich zeigen wird).
-- Beobachtet man einen Ruf, landet die XP-Leiste im zweiten Container.
local function FindXPContainer()
    if StatusTrackingBarManager and StatusTrackingBarInfo then
        local xpIndex = StatusTrackingBarInfo.BarsEnum.Experience
        for _, container in ipairs(StatusTrackingBarManager.barContainers or {}) do
            if container.shownBarIndex == xpIndex or container.pendingBarToShowIndex == xpIndex then
                return container
            end
        end
    end
    return MainStatusTrackingBarContainer
end

-- Modern: mittig auf den Blizzard-Container der XP-Leiste (eigene Höhe), über dessen Rahmen.
-- Classic: exakt auf Blizzards (unsichtbare) XP-Leiste, unter dessen Rahmen und Trennern.
-- In beiden Fällen verschiebt der Edit Mode unsere Leiste mit.
function Bar:Anchor()
    local f = self.frame
    local container = FindXPContainer()
    local blizzardBar = container and container.bars and StatusTrackingBarInfo
        and container.bars[StatusTrackingBarInfo.BarsEnum.Experience]
    f:ClearAllPoints()
    if IsClassic() and blizzardBar then
        f:SetAllPoints(blizzardBar)
        f:SetFrameStrata("LOW")
        f:SetFrameLevel(blizzardBar:GetFrameLevel() + 1)
    elseif container then
        f:SetPoint("CENTER", container, "CENTER")
        f:SetWidth(container:GetWidth())
        f:SetHeight(XPForeverDB.height)
        f:SetFrameStrata("MEDIUM")
        f:SetFrameLevel(container:GetFrameLevel() + 20)
    else
        f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 90)
        f:SetSize(1192, XPForeverDB.height)
    end
    -- Texte immer über allem, auch über Blizzards Rahmen im Classic-Stil.
    self.overlay:SetFrameStrata("MEDIUM")
    self.overlay:SetFrameLevel((container and container:GetFrameLevel() or f:GetFrameLevel()) + 25)

    -- Erholungs-Leuchten: modern um unsere Leiste, classic um Blizzards Rahmen (über dessen Grafik).
    local glow = self.restGlow
    glow:ClearAllPoints()
    glow:SetFrameStrata("MEDIUM")
    local frameArt = container and container.BarFrameTexture
    local classicGlow = IsClassic() and frameArt and frameArt:GetAtlas()
    if classicGlow then
        glow:SetAllPoints(container)
        glow:SetFrameLevel(container:GetFrameLevel() + 15)
        glow.classicFrame:SetAtlas(classicGlow)
        glow.classicFrame:ClearAllPoints()
        glow.classicFrame:SetAllPoints(frameArt)
        glow.classicFrame:SetVertexColor(COLORS.restGlow:GetRGB())
    else
        glow:SetAllPoints(f)
        glow:SetFrameLevel(f:GetFrameLevel() + 1)
    end
    glow.classicFrame:SetShown(classicGlow and true or false)
    for _, piece in ipairs(glow.modernPieces) do piece:SetShown(not classicGlow) end

    -- Der Info-Text richtet sich nach der obersten Leiste und muss mitwandern.
    if ns.InfoText.frame then ns.InfoText:Anchor() end
end

-- Hover-Texte je nach Einstellung: beim Darüberfahren, immer oder nie. Sanft überblenden.
-- Prozentzahl und Zzz machen der Textzeile Platz und blenden gegenläufig.
function Bar:UpdateTextVisibility(instant)
    local texts = self.texts
    local mode = XPForeverDB.barTextMode
    local visible = mode == "always" or (mode == "hover" and self.hovered)
    local target = (visible and ns.HasTextItems("bar")) and 1 or 0
    local function apply(alpha)
        texts:SetAlpha(alpha)
        self.restIcon:SetAlpha(1 - alpha)
        self.percentText:SetAlpha(1 - alpha)
    end
    if instant then
        apply(target)
        texts:SetScript("OnUpdate", nil)
        return
    end
    texts:SetScript("OnUpdate", function(_, elapsed)
        local step = elapsed / TEXT_FADE_DURATION
        local alpha = texts:GetAlpha()
        alpha = target > alpha and math.min(alpha + step, target) or math.max(alpha - step, target)
        apply(alpha)
        if alpha == target then texts:SetScript("OnUpdate", nil) end
    end)
end

-- Im Erholungsgebiet (Gasthaus, Hauptstadt): Zzz-Icon zeigen und den Rahmen golden leuchten lassen.
function Bar:UpdateResting()
    if not self.frame then return end
    local show = IsResting() and XPForeverDB.showRestIndicator
    self.restIcon:SetShown(show)
    self.restGlow:SetShown(show)
    if show then
        self.restIconAnim:Play()
        self.restGlowAnim:Play()
    else
        self.restIconAnim:Stop()
        self.restGlowAnim:Stop()
    end
end

function Bar:Layout(width)
    local segmentWidth = width / NUM_SEGMENTS
    for i, divider in ipairs(self.dividers) do
        divider:ClearAllPoints()
        divider:SetPoint("TOP", self.inner, "TOPLEFT", segmentWidth * i, 0)
        divider:SetPoint("BOTTOM", self.inner, "BOTTOMLEFT", segmentWidth * i, 0)
    end
    self:Refresh()
end

-- Zielzustand der Leiste als Anteile (0..1): Ende der XP, der Quest-XP und der Erholung.
local function ComputeTarget()
    local db = XPForeverDB
    local max = state.max > 0 and state.max or 1
    local questXP = db.showQuestXP and state.questXP or 0
    local rested = db.showRestedXP and state.rested or 0
    return {
        xp = state.xp / max,
        quest = (state.xp + questXP) / max,
        rested = (state.xp + questXP + rested) / max,
        level = state.level,
    }
end

local function SameTarget(a, b)
    return a.level == b.level and math.abs(a.xp - b.xp) < 1e-6
        and math.abs(a.quest - b.quest) < 1e-6 and math.abs(a.rested - b.rested) < 1e-6
end

local function EaseOut(progress)
    return 1 - (1 - progress) ^ 3
end

function Bar:Draw(display)
    SetSpan(self.xpFill, 0, display.xp)
    SetSpan(self.questFill, display.xp, display.quest)
    SetSpan(self.restedFill, display.quest, display.rested)

    local x = math.min(display.xp, 1) * self.inner:GetWidth()
    self.spark:ClearAllPoints()
    self.spark:SetPoint("TOP", self.inner, "TOPLEFT", x, 0)
    self.spark:SetPoint("BOTTOM", self.inner, "BOTTOMLEFT", x, 0)
    -- Blizzards Leiste hat keine Leuchtkante; im Classic-Stil weglassen.
    self.spark:SetShown(display.xp > 0 and display.xp < 1 and not IsClassic())
end

-- Neu gewonnener Abschnitt leuchtet kurz in einer aufgehellten XP-Farbe auf.
function Bar:Flash(from, to)
    if to <= from then return end
    local r, g, b = ns.GetColor("colorXP"):GetRGB()
    self.flashTexture:SetColorTexture(r + (1 - r) * 0.5, g + (1 - g) * 0.5, b + (1 - b) * 0.5, 1)
    SetSpan(self.flashTexture, from, to)
    self.flashFrame:Show()
    self.flashAnim:Restart()
end

-- Spielt eine Folge von Zielzuständen nacheinander ab. RESET_STEP leert die Leiste (nach einem Level-up).
local RESET_STEP = {}

function Bar:PlaySteps(steps)
    self.steps = steps
    self.goal = steps[#steps]
    self:NextStep()
end

function Bar:NextStep()
    local step = table.remove(self.steps, 1)
    if not step then
        self.animator:SetScript("OnUpdate", nil)
        self.goal = nil
        return
    end
    if step == RESET_STEP then
        self.display = { xp = 0, quest = 0, rested = 0, level = self.goal.level }
        return self:NextStep()
    end

    local from = CopyTable(self.display)
    local elapsed = 0
    self.animator:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        local progress = EaseOut(math.min(elapsed / ANIM_DURATION, 1))
        for _, key in ipairs({ "xp", "quest", "rested" }) do
            self.display[key] = from[key] + (step[key] - from[key]) * progress
        end
        self.display.level = step.level
        self:Draw(self.display)
        if progress >= 1 then self:NextStep() end
    end)
end

function Bar:StopAnimation()
    self.animator:SetScript("OnUpdate", nil)
    self.steps, self.goal = nil, nil
end

function Bar:Refresh()
    local f = self.frame
    if not f then return end
    if not ns.ShouldShow() then
        f:Hide()
        return
    end
    f:Show()
    self:UpdateFills()
    HideBlizzardBar()

    local target = ComputeTarget()
    local display = self.display

    if not display or not XPForeverDB.animate or not f:IsVisible() then
        self:StopAnimation()
        self.display = target
        self:Draw(target)
    elseif target.level > display.level then
        -- Level-up: erst bis zum Ende füllen, dann von vorn auf den neuen Stand.
        self:Flash(display.xp, 1)
        self:PlaySteps({ { xp = 1, quest = 1, rested = 1, level = display.level }, RESET_STEP, target })
    elseif not SameTarget(target, self.goal or display) then
        if target.xp > display.xp then self:Flash(display.xp, target.xp) end
        self:PlaySteps({ target })
    elseif not self.goal then
        -- Keine Änderung, aber z. B. neue Breite: aktuellen Stand neu zeichnen.
        self:Draw(display)
    end

    self:RefreshText()
end

function Bar:RefreshText()
    local f = self.frame
    if not (f and f:IsShown()) then return end

    local percent = state.xp / math.max(state.max, 1) * 100
    self.percentText:SetText(ns.FormatPercent(percent) .. " %")
    self.hoverText:SetText(ns.BuildText("bar"))
end

function Bar:ShowTooltip()
    local tooltip = GameTooltip
    local questColor, restedColor = ns.GetColor("colorQuest"), ns.GetColor("colorRested")
    tooltip:SetOwner(self.frame, "ANCHOR_TOP")
    tooltip:SetText(L.tooltipTitle)
    if ns.IsQuestReady() then
        tooltip:AddLine(Colorize(L.levelUpReady, questColor))
    end
    if IsResting() then
        tooltip:AddLine(Colorize(L.restingNow, restedColor))
    end
    local xpText = string.format("%s / %s", ns.FormatNumber(state.xp), ns.FormatNumber(state.max))
    tooltip:AddDoubleLine(L.tooltipXP, xpText, 1, 1, 1, 1, 1, 1)
    tooltip:AddDoubleLine(L.tooltipRemaining, ns.FormatNumber(state.max - state.xp), 1, 1, 1, 1, 1, 1)
    if state.questXP > 0 then
        tooltip:AddDoubleLine(L.tooltipQuests:format(state.questCount), "+" .. ns.FormatNumber(state.questXP),
            1, 1, 1, questColor:GetRGB())
    end
    if state.rested > 0 then
        tooltip:AddDoubleLine(L.rested, "+" .. ns.FormatNumber(state.rested), 1, 1, 1, restedColor:GetRGB())
    end

    local gained, elapsed = ns.GetSessionStats()
    tooltip:AddLine(" ")
    local sessionText = string.format("+%s  (%s)", ns.FormatNumber(gained), ns.FormatDuration(elapsed))
    tooltip:AddDoubleLine(L.tooltipSession, sessionText, 1, 1, 1, 1, 1, 1)
    local rate = ns.GetRate()
    if rate then
        tooltip:AddDoubleLine(L.perHour, ns.FormatNumber(rate * 3600), 1, 1, 1, 1, 1, 1)
    end
    local kills = ns.GetKillsToLevel()
    if kills then
        tooltip:AddDoubleLine(L.tooltipKills, "~" .. ns.FormatNumber(kills), 1, 1, 1, 1, 1, 1)
    end

    tooltip:AddLine(" ")
    tooltip:AddLine(ns.ClickHint("LeftButton", nil, L.actionToggleInfo, L.hintToggleInfo), GRAY_FONT_COLOR:GetRGB())
    tooltip:AddLine(ns.ClickHint("LeftButton", "CTRL", L.actionResetSession, L.hintResetSession),
        GRAY_FONT_COLOR:GetRGB())
    tooltip:AddLine(ns.ClickHint("RightButton", nil, L.actionOptions, L.hintOptions), GRAY_FONT_COLOR:GetRGB())
    tooltip:AddLine(" ")
    tooltip:AddLine(ns.BrandLine(), GRAY_FONT_COLOR:GetRGB())
    tooltip:Show()
end
