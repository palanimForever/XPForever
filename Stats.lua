local addonName, ns = ...

-- XP-Stand, Quest-XP und Sitzungsstatistik (XP/h, Kills bis Level-up).
-- Sitzungsdaten liegen in XPForeverCharDB, damit sie ein /reload überstehen.

local GAIN_HISTORY_SECONDS = 3600
local KILL_SAMPLES = 10
local MAX_KILL_SHARE = 0.25 -- größere Einzelgewinne (Entdeckung, Sonderbelohnung) zählen nicht als Kill
local CLASSIFY_DELAY = 0.5 -- so lange wird ein XP-Gewinn zurückgehalten, um Quest-Abgaben zuzuordnen
local QUEST_MATCH_WINDOW = 2
local TURNED_IN_MEMORY = 10 -- Sekunden, die eine abgegebene Quest aus der Quest-XP ausgeschlossen bleibt
local MIN_RATE_SECONDS = 60

-- Aktueller XP-Stand, wird von Leiste, Info-Text und Textbausteinen gelesen.
local state = { xp = 0, max = 1, level = 1, rested = 0, questXP = 0, questCount = 0 }
ns.state = state

local Stats = {}
ns.Stats = Stats

local initialized = false
local recentQuestXP = 0
local turnedInQuests = {}

local function CharDB()
    return XPForeverCharDB
end

function Stats.ResetSession()
    local db = CharDB()
    db.session = { start = time(), gained = 0 }
    db.gains = {}
    db.kills = {}
end

function Stats.HasSession()
    local db = CharDB()
    return db.session and db.gains and db.kills
end

-- Kill-Erkennung: Jeder XP-Gewinn wird kurz zurückgehalten. Kommt in der Zeit ein QUEST_TURNED_IN,
-- wird dessen XP abgezogen. Was übrig bleibt, zählt als Kill.
local function ClassifyGain(amount)
    C_Timer.After(CLASSIFY_DELAY, function()
        local questPart = math.min(amount, recentQuestXP)
        recentQuestXP = recentQuestXP - questPart
        local killXP = amount - questPart
        if killXP > 0 and killXP < state.max * MAX_KILL_SHARE then
            local kills = CharDB().kills
            table.insert(kills, killXP)
            while #kills > KILL_SAMPLES do table.remove(kills, 1) end
        end
        ns.Refresh()
    end)
end

local function RecordGain(amount)
    local db = CharDB()
    local now = time()
    db.session.gained = db.session.gained + amount
    table.insert(db.gains, { t = now, xp = amount })
    while db.gains[1] and db.gains[1].t < now - GAIN_HISTORY_SECONDS do
        table.remove(db.gains, 1)
    end
    ClassifyGain(amount)
end

function Stats.UpdateXP()
    local xp, max, level = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")

    if initialized then
        local gained = level > state.level and (state.max - state.xp) + xp or xp - state.xp
        if gained > 0 then RecordGain(gained) end
    end

    state.xp, state.max, state.level = xp, max, level
    state.rested = GetXPExhaustion() or 0
    initialized = true
end

function Stats.UpdateQuestXP()
    local total, count = 0, 0
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID and not turnedInQuests[info.questID]
            and C_QuestLog.IsComplete(info.questID) then
            total = total + (GetQuestLogRewardXP(info.questID) or 0)
            count = count + 1
        end
    end
    state.questXP, state.questCount = total, count
end

-- Gerade abgegebene Quests können noch kurz im Questlog stehen, zählen aber nicht mehr als Quest-XP.
-- Ihre XP wird außerdem für die Kill-Erkennung vorgemerkt.
function Stats.OnQuestTurnedIn(questID, xpReward)
    turnedInQuests[questID] = true
    C_Timer.After(TURNED_IN_MEMORY, function() turnedInQuests[questID] = nil end)
    Stats.UpdateQuestXP()

    xpReward = xpReward or 0
    recentQuestXP = recentQuestXP + xpReward
    -- Nicht verbrauchte Quest-XP nach kurzer Zeit verwerfen, damit spätere Kills nicht verschluckt werden.
    C_Timer.After(QUEST_MATCH_WINDOW, function()
        recentQuestXP = math.max(0, recentQuestXP - xpReward)
    end)
end

function ns.ShouldShow()
    return state.level < GetMaxPlayerLevel() and not IsXPUserDisabled()
end

function ns.IsQuestReady()
    return state.questXP > 0 and state.xp + state.questXP >= state.max
end

-- XP pro Sekunde über den eingestellten Zeitraum, nil solange zu wenig Daten vorliegen.
function ns.GetRate()
    local db = CharDB()
    local now = time()
    local sessionElapsed = now - db.session.start
    if sessionElapsed < MIN_RATE_SECONDS then return nil end

    local window = XPForeverDB.rateWindow
    if window == 0 then
        if db.session.gained <= 0 then return nil end
        return db.session.gained / sessionElapsed
    end

    local sum = 0
    for _, gain in ipairs(db.gains) do
        if gain.t >= now - window then sum = sum + gain.xp end
    end
    if sum <= 0 then return nil end
    return sum / math.min(window, sessionElapsed)
end

function ns.GetTimeToLevel()
    local rate = ns.GetRate()
    return rate and (state.max - state.xp) / rate
end

-- Geschätzte Kills bis Level-up aus dem Durchschnitt der letzten Kills.
function ns.GetKillsToLevel()
    local kills = CharDB().kills
    if #kills == 0 then return nil end
    local sum = 0
    for _, xp in ipairs(kills) do sum = sum + xp end
    return math.ceil((state.max - state.xp) / (sum / #kills))
end

function ns.GetSessionStats()
    local session = CharDB().session
    return session.gained, time() - session.start
end
