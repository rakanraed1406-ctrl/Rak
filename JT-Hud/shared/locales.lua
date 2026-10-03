
-- ══════════════════════════════════════════════
--  Locales loader
-- ══════════════════════════════════════════════
local function loadLocaleFile(locale)
    local resourceName = GetCurrentResourceName()
    local file = LoadResourceFile(resourceName, ("locales/%s.lua"):format(locale))
    if not file then
        file = LoadResourceFile(resourceName, "locales/en.lua")
    end
    return file
end

local function loadLocale(locale)
    local file = loadLocaleFile(locale)
    if not file then return {} end
    local data, err = load(file)
    if err then print(err); return {} end
    return data() or {}
end

locales = loadLocale(Config.Locale or "en")

function _t(key, ...)
    local keys = {}
    for k in string.gmatch(key, "[^.]+") do table.insert(keys, k) end
    local cur = locales
    for _, k in ipairs(keys) do
        cur = cur[k]
        if not cur then return key end
    end
    if type(cur) == "string" then return cur:format(...) end
    return key
end
