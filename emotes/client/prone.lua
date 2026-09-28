local isProne = false
local proneState = "none"

function IsPlayerProne()
    return isProne
end

function IsPlayerCrawling()
    return proneState == "crawling"
end

function CrawlKeyPressed()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsPedSwimming(ped) or IsPedFalling(ped) then return end

    isProne = not isProne
    if isProne then
        proneState = "prone"
        TaskPlayAnim(ped, "move_crawl", "onfront_fwd", 8.0, -8.0, -1, 1, 0, false, false, false)
    else
        proneState = "none"
        ClearPedTasks(ped)
    end
end
