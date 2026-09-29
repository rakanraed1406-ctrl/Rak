
-- ============================================================================
-- ls_handbrake - Cache Utility Module
-- Clean, human-written implementation replacing decompiled code
-- ============================================================================

local cacheStore = {}

--- Saves a value into the timed cache store
--- @param key string
--- @param data any
--- @param maxAgeMs number|nil (default 3000ms)
function SaveCache(key, data, maxAgeMs)
    local expiryTime = GetGameTimer() + (maxAgeMs or 3000)
    cacheStore[key] = {
        data = data,
        maxAge = expiryTime
    }
end

--- Retrieves a cached value or executes fallback function if expired
--- @param key string
--- @param fallbackFunc function
--- @param maxAgeMs number|nil
--- @return any
function UseCache(key, fallbackFunc, maxAgeMs)
    local entry = cacheStore[key]
    if entry and GetGameTimer() <= entry.maxAge then
        return table.unpack(entry.data)
    end

    local result = { fallbackFunc() }
    SaveCache(key, result, maxAgeMs)
    return table.unpack(result)
end
