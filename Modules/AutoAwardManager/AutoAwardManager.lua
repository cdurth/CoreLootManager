local _, CLM = ...

local LOG = CLM.LOG
local MODULES = CLM.MODULES
local CONSTANTS = CLM.CONSTANTS

local ACL = MODULES.ACL
local PointManager = MODULES.PointManager
local RaidManager = MODULES.RaidManager
local EventManager = MODULES.EventManager

local HYDROSS_ENCOUNTER_ID = 623
local HYDROSS_ENCOUNTER_NAME = "Hydross the Unstable"
local HYDROSS_NPC_ID = 21216

local function handleEncounterStart(self, addon, event, id, name, difficulty, groupSize)
    LOG:Info("[%s %s]: <%s, %s, %s, %s, %s>", addon, event, id, name, difficulty, groupSize)
    if self:IsEnabled() and self:IsBossKillBonusAwardingEnabled() and not self:EncounterInProgress() then
        self.encounterInProgress = id
    end
end

local function handleEncounterEnd(self, addon, event, id, name, difficulty, groupSize, success)
    LOG:Info("[%s %s]: <%s, %s, %s, %s, %s>", addon, event, id, name, difficulty, groupSize, success)
    if self:IsEnabled() and self:IsBossKillBonusAwardingEnabled() and self:EncounterInProgress() then
        if self.encounterInProgress == id then
            if RaidManager:IsInActiveRaid() and success == 1 then
                local roster = RaidManager:GetRaid():Roster()
                if roster:GetConfiguration("bossKillBonus") then
                    PointManager:UpdateRaidPoints(RaidManager:GetRaid(), roster:GetBossKillBonusValue(id), CONSTANTS.POINT_CHANGE_REASON.BOSS_KILL_BONUS, CONSTANTS.POINT_MANAGER_ACTION.MODIFY)
                end
            end
            self.encounterInProgress = 0
        end
    end
end

local function handleHydrossWorkaround(self, addon, event)
    if self:IsEnabled() and self:IsBossKillBonusAwardingEnabled() and (self.encounterInProgress == HYDROSS_ENCOUNTER_ID) then
        local _, subevent, _, _, _, _, _, guid, _   = CombatLogGetCurrentEventInfo()
        if subevent == "UNIT_DIED" then
            local _, _, _, _, _, npc_id = strsplit("-", guid)
            if tonumber(npc_id) == HYDROSS_NPC_ID then
                handleEncounterEnd(self, addon, "ENCOUNTER_END", HYDROSS_ENCOUNTER_ID, HYDROSS_ENCOUNTER_NAME, 176, 25, 1)
            end
        end
    end
end

local AutoAwardManager = {}
function AutoAwardManager:Initialize()
    LOG:Trace("AutoAwardManager:Initialize()")
    if not ACL:IsTrusted() then return end
    self.enabled = false
    self:DisableBossKillBonusAwarding()
    EventManager:RegisterWoWEvent({"ENCOUNTER_START"}, (function(...)
        handleEncounterStart(self, ...)
    end))
    EventManager:RegisterWoWEvent({"ENCOUNTER_END"}, (function(...)
        handleEncounterEnd(self, ...)
    end))
    -- Hydross workaround
    EventManager:RegisterWoWEvent({"COMBAT_LOG_EVENT_UNFILTERED"}, (function(...)
        handleHydrossWorkaround(self, ...)
    end))
    MODULES.ConfigManager:RegisterUniversalExecutor("aam", "AutoAwardManager", self)
end

function AutoAwardManager:Enable()
    LOG:Trace("AutoAwardManager:Enable()")
    self.enabled = true
end

function AutoAwardManager:Disable()
    LOG:Trace("AutoAwardManager:Disable()")
    self.enabled = false
end

function AutoAwardManager:IsEnabled()
    LOG:Trace("AutoAwardManager:IsEnabled()")
    return self.enabled
end

function AutoAwardManager:EncounterInProgress()
    LOG:Trace("AutoAwardManager:EncounterInProgress()")
    return (self.encounterInProgress ~= 0)
end

function AutoAwardManager:EnableBossKillBonusAwarding()
    LOG:Trace("AutoAwardManager:EnableBossKillBonusAwarding()")
    self.bossKillBonusAwardingEnabled = true
end

function AutoAwardManager:DisableBossKillBonusAwarding()
    LOG:Trace("AutoAwardManager:DisableBossKillBonusAwarding()")
    self.encounterInProgress = 0
    self.bossKillBonusAwardingEnabled = false
end

function AutoAwardManager:IsBossKillBonusAwardingEnabled()
    LOG:Trace("AutoAwardManager:IsBossKillBonusAwardingEnabled()")
    return self.bossKillBonusAwardingEnabled
end

--@debug@
function AutoAwardManager:FakeEncounterStart()
    handleEncounterStart(self, "CLM", "ENCOUNTER_START", 123456, "Fake Encounter", 0, 25)
end

function AutoAwardManager:FakeEncounterSuccess()
    handleEncounterEnd(self, "CLM", "ENCOUNTER_END", 123456, "Fake Encounter", 0, 25, 1)
end

function AutoAwardManager:FakeEncounterFail()
    handleEncounterEnd(self, "CLM", "ENCOUNTER_END", 123456, "Fake Encounter", 0, 25, 0)
end
--@end-debug@

MODULES.AutoAwardManager = AutoAwardManager