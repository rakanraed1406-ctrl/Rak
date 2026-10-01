Config = {}

-- ════════════════════════════════════════════════════════════
--  General
-- ════════════════════════════════════════════════════════════
Config.Locale      = 'en'            -- 'en' | 'ar'  (texts live in locales.lua)
Config.ServerName  = 'Jinxed Town'   -- shown in the footer and as a fallback when the logo fails to load
Config.Logo        = 'logo.png'      -- file inside nui/ or a full https:// link
Config.LogoHeight  = 8               -- logo height in rem (8 = 128px on 1080p, scales with resolution)
Config.AccentColor = '#1688FF'       -- main colour of the whole menu (hex)

Config.BackgroundBlur = true         -- blur the game behind the menu (game effect, costs nothing in the UI)
Config.BlurFadeTime   = 250          -- ms
Config.HideHud        = true         -- hide the GTA radar/HUD while the menu is open
Config.RefreshInterval = 15000       -- ms, refresh player/police counts while the menu stays open

-- Clock shown in the top-right corner
Config.Clock = {
    timeZone = 'Asia/Riyadh',        -- any IANA zone name
    label    = 'KSA (GMT+3)',
    hour12   = false,
}

-- ════════════════════════════════════════════════════════════
--  Server status
-- ════════════════════════════════════════════════════════════
Config.ShowServiceCounts = false     -- false = only "active / inactive" (exact counts are never sent to clients)
Config.CountOffDuty      = false     -- count police/EMS that are off duty
Config.StatusCacheTime   = 3000      -- ms, the server re-counts at most once per this time

Config.PoliceJobs     = { ['police'] = true, ['sheriff'] = true, ['state'] = true, ['lspd'] = true }
Config.PoliceJobTypes = { ['leo'] = true }
Config.EMSJobs        = { ['ambulance'] = true, ['doctor'] = true }
Config.EMSJobTypes    = { ['ems'] = true }

-- Robbery list (add / remove freely). icon: store, house, bank, truck, atm, gem, gun, car, boat, box
-- label / description can be a plain string or { en = '...', ar = '...' }
Config.ShowRequirement = true        -- show "Requires X officers" under each robbery
Config.Robberies = {
    { id = 'store', icon = 'store', minPolice = 3,
      label = { en = 'Store Robbery', ar = 'سرقة متجر' },
      description = { en = 'Convenience stores across Los Santos', ar = 'المتاجر في أنحاء لوس سانتوس' } },
    { id = 'house', icon = 'house', minPolice = 3,
      label = { en = 'House Robbery', ar = 'سرقة منازل' },
      description = { en = 'Residential break-ins and burglaries', ar = 'اقتحام وسرقة المنازل' } },
    { id = 'bank', icon = 'bank', minPolice = 4,
      label = { en = 'Bank Robbery', ar = 'سرقة بنك' },
      description = { en = 'Banks and secured financial branches', ar = 'البنوك والفروع المالية المؤمّنة' } },
    { id = 'truck', icon = 'truck', minPolice = 4,
      label = { en = 'Bank Truck', ar = 'شاحنة البنك' },
      description = { en = 'Armored cash transport operations', ar = 'عمليات نقل الأموال المصفّحة' } },
    { id = 'atm', icon = 'atm', minPolice = 2,
      label = { en = 'ATM Robbery', ar = 'سرقة صراف' },
      description = { en = 'ATM attacks and cash extraction', ar = 'اقتحام أجهزة الصراف وسحب النقد' } },
}

-- ════════════════════════════════════════════════════════════
--  Character card
-- ════════════════════════════════════════════════════════════
Config.PlayerCard = {
    enabled = true,
    job     = true,
    gang    = true,
    cash    = true,
    bank    = true,
}

-- ════════════════════════════════════════════════════════════
--  Native GTA menus opened by "World Map" / "Settings"
-- ════════════════════════════════════════════════════════════
Config.NativeMenus = {
    map      = { menu = 'FE_MENU_VERSION_MP_PAUSE',     tab = -1, goDeeper = true },
    settings = { menu = 'FE_MENU_VERSION_LANDING_MENU', tab = -1, goDeeper = false },
}

-- ════════════════════════════════════════════════════════════
--  Audio panel defaults (shown until the player changes them;
--  nothing is applied to the game until the player touches a toggle)
-- ════════════════════════════════════════════════════════════
Config.AudioDefaults = {
    radio       = true,   -- vehicle radio
    scanner     = true,   -- police scanner voice
    sirens      = true,   -- distant police sirens
    flightMusic = true,   -- music while flying
    wantedMusic = true,   -- music while wanted
}

-- Menu sound effects (generated inside the UI, no files)
Config.Sounds = {
    enabled = true,
    volume  = 0.35,       -- 0.0 - 1.0
}

-- Footer buttons (opens the link in the player's browser). Example:
-- Config.Links = { { label = 'Discord', url = 'https://discord.gg/yourserver', icon = 'discord' } }
Config.Links = {}

-- ════════════════════════════════════════════════════════════
--  Updates / changelog
-- ════════════════════════════════════════════════════════════
Config.UpdateCommand    = 'update'   -- opens the publish window (admins only)
Config.AdminPermissions = { ['admin'] = true, ['god'] = true }
Config.AdminAce         = false      -- optional ACE, e.g. 'jtpause.admin'
Config.MaxUpdates       = 30         -- oldest entries are removed past this number

-- ════════════════════════════════════════════════════════════
--  Misc
-- ════════════════════════════════════════════════════════════
Config.QuitMessage = 'Disconnected from the server via the pause menu.'

-- Other pause-menu resources that would open together with this one.
-- They are stopped on start so two menus never open at once. Set to {} to disable.
Config.ConflictingResources = { 'Mor-pause', 'mor-pause', 'sk1-pause' }
