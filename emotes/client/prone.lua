-- Crouch + crawl (enable them in config.lua: Config.Crouch / Config.Crawl)
local isProne = false
local proneState = "none"
isCrouched = false
local lastCrouch = 0

local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function loadSet(set)
    if HasAnimSetLoaded(set) then return true end
    RequestAnimSet(set)
    local t = GetGameTimer() + 3000
    while not HasAnimSetLoaded(set) and GetGameTimer() < t do Wait(10) end
    return HasAnimSetLoaded(set)
end

function IsPlayerProne() return isProne end
function IsPlayerCrawling() return proneState == "crawling" end
function IsPlayerCrouched() return isCrouched end

local function restoreWalk(ped)
    ResetPedMovementClipset(ped, 0.3)
    local style = GetResourceKvpString("walkstyle")
    if style and style ~= "" and loadSet(style) then SetPedMovementClipset(ped, style, 0.3) end
end

function AttemptCrouch(ped)
    ped = ped or PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsPedSwimming(ped) or IsPedFalling(ped) or IsPedRagdoll(ped) then return end
    local cd = (Config.Crouch and Config.Crouch.cooldown) or 1000
    if GetGameTimer() - lastCrouch < cd then return end
    lastCrouch = GetGameTimer()

    isCrouched = not isCrouched
    if isCrouched then
        if not loadSet("move_ped_crouched") then isCrouched = false return end
        SetPedMovementClipset(ped, "move_ped_crouched", 0.3)
        SetPedStrafeClipset(ped, "move_ped_crouched_strafing")
        CreateThread(function()
            while isCrouched do
                local p = PlayerPedId()
                if IsPedInAnyVehicle(p, false) or IsEntityDead(p) then break end
                if not (Config.Crouch and Config.Crouch.crouchOverride) then DisableControlAction(0, 36, true) end -- no stealth mode
                Wait(0)
            end
            isCrouched = false
            ResetPedStrafeClipset(PlayerPedId())
            restoreWalk(PlayerPedId())
        end)
    end
end

function CrouchKeyPressed()
    AttemptCrouch(PlayerPedId())
end

function CrawlKeyPressed()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsPedSwimming(ped) or IsPedFalling(ped) then return end

    isProne = not isProne
    if isProne then
        if not loadDict("move_crawl") then isProne = false return end
        proneState = "prone"
        TaskPlayAnim(ped, "move_crawl", "onfront_fwd", 8.0, -8.0, -1, 1, 0, false, false, false)
    else
        proneState = "none"
        ClearPedTasks(ped)
    end
end
