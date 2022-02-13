local _, CLM = ...

local LOG = CLM.LOG
local MODULES = CLM.MODULES
local CONSTANTS = CLM.CONSTANTS
local MODELS = CLM.MODELS
local UTILS = CLM.UTILS

local ACL = MODULES.ACL
local Comms = MODULES.Comms
local ProfileManager = MODULES.ProfileManager
local RaidManager = MODULES.RaidManager
local StandbyStagingCommStructure = MODELS.StandbyStagingCommStructure
local StandbyStagingCommSubscribe = MODELS.StandbyStagingCommSubscribe
local StandbyStagingCommRevoke = MODELS.StandbyStagingCommRevoke

local STANDBY_STAGING_COMM_PREFIX = "Standby001"

-- local function IsOwnerOfCreatedRaid()
--     if not IsInRaid() then return false end
--     if not RaidManager:IsInCreatedRaid() then return false end
--     if not RaidManager:IsRaidOwner() then return false end
--     return true
-- end

-- local function Respond(raidUid, success)
--     if IsOwnerOfCreatedRaid() and (RaidManager:GetRaid():UID() == raidUid) then
--         -- Send response
--     end
-- end

local function HandleIncomingMessage(self, message, distribution, sender)
    LOG:Trace("StandbyStagingManager:HandleIncomingMessage()")
    local mtype = message:Type() or 0
    if self.handlers[mtype] then
        self.handlers[mtype](self, message:Data(), sender)
    end
end

local function HandleSubscribe(self, data, sender)
    LOG:Trace("StandbyStagingManager:HandleSubscribe()")
    if not ACL:IsTrusted() then return end
    local raidUid = data:RaidUid()
    if not RaidManager:GetRaidByUid(raidUid) then
        LOG:Warning("Non existent raid: %s", raidUid)
        return
    end
    local profile = ProfileManager:GetProfileByName(sender)
    if profile then
        self:AddToStandby(raidUid, profile:GUID())
    else
        LOG:Warning("Missing profile for player %s", sender)
    end
end

local function HandleRevoke(self, data, sender)
    LOG:Trace("StandbyStagingManager:HandleRevoke()")
    if not ACL:IsTrusted() then return end
    local raidUid = data:RaidUid()
    if not RaidManager:GetRaidByUid(raidUid) then
        LOG:Warning("Non existent raid: %s", raidUid)
        return
    end
    local profile = ProfileManager:GetProfileByName(sender)
    if profile then
        self:RemoveFromStandby(raidUid, profile:GUID())
    else
        LOG:Warning("Missing profile for player %s", sender)
    end
end

-- local function HandleResponse(self, data, sender)
--     LOG:Trace("StandbyStagingManager:HandleResponse()")
-- end

local StandbyStagingManager = {}
function StandbyStagingManager:Initialize()
    LOG:Trace("StandbyStagingManager:Initialize()")
    self:Clear()

    self.handlers = {
        [CONSTANTS.STANDBY_STAGING_COMM.TYPE.SUBSCRIBE] = HandleSubscribe,
        [CONSTANTS.STANDBY_STAGING_COMM.TYPE.REVOKE]    = HandleRevoke,
        -- [CONSTANTS.STANDBY_STAGING_COMM.TYPE.RESPONSE]  = HandleResponse,
    }

    Comms:Register(STANDBY_STAGING_COMM_PREFIX, (function(rawMessage, distribution, sender)
        local message = StandbyStagingCommStructure:New(rawMessage)
        if CONSTANTS.STANDBY_STAGING_COMM.TYPES[message:Type()] == nil then return end
        HandleIncomingMessage(self, message, distribution, sender)
    end), CONSTANTS.ACL.LEVEL.PLEBS, true)

end
-- Local API
function StandbyStagingManager:Clear()
    LOG:Trace("StandbyStagingManager:Clear()")
    self.standby = {}
end

function StandbyStagingManager:AddToStandby(raidUid, GUID)
    LOG:Trace("StandbyStagingManager:AddToStandby()")
    if not self.standby[raidUid] then self.standby[raidUid] = {} end
    self.standby[raidUid][GUID] = true
end

function StandbyStagingManager:RemoveFromStandby(raidUid, GUID)
    LOG:Trace("StandbyStagingManager:RemoveFromStandby()")
    if not self.standby[raidUid] then return end
    self.standby[raidUid][GUID] = nil
end

function StandbyStagingManager:GetStandby(raidUid)
    LOG:Trace("StandbyStagingManager:GetStandby()")
    return self.standby[raidUid] or {}
end
-- Comms API
function StandbyStagingManager:SignupToStandby(raidUid)
    LOG:Trace("StandbyStagingManager:SignupToStandby()")
    local message = StandbyStagingCommStructure:New(
        CONSTANTS.STANDBY_STAGING_COMM.TYPE.SUBSCRIBE,
        StandbyStagingCommSubscribe:New(raidUid))
    Comms:Send(STANDBY_STAGING_COMM_PREFIX, message, CONSTANTS.COMMS.DISTRIBUTION.GUILD)
end

function StandbyStagingManager:RevokeStandby(raidUid)
    LOG:Trace("StandbyStagingManager:RevokeStandby()")
    local message = StandbyStagingCommStructure:New(
        CONSTANTS.STANDBY_STAGING_COMM.TYPE.REVOKE,
        StandbyStagingCommRevoke:New(raidUid))
    Comms:Send(STANDBY_STAGING_COMM_PREFIX, message, CONSTANTS.COMMS.DISTRIBUTION.GUILD)
end

CONSTANTS.STANDBY_STAGING_COMM = {
    TYPE = {
        SUBSCRIBE   = 1,
        REVOKE      = 2,
        -- RESPONSE    = 3
    },
    TYPES = UTILS.Set({ 1, 2, --[[3]] })
}

MODULES.StandbyStagingManager = StandbyStagingManager