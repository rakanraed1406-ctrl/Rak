Config = {}

-- =========================================================================
-- Robbing parking meters
-- =========================================================================

-- Parking meter props (same models as the original script).
Config.MeterModels = {
    -1940238623,
    2108567945,
}

-- Items that can open a meter, tried in this order. `uses` = how many
-- robberies ONE of these items lasts. Every finished robbery takes one use;
-- when the uses run out that one lockpick is removed (the rest of the stack
-- stays and the next one starts with full uses).
Config.Lockpicks = {
    { item = 'lockpick', uses = 5 },
    { item = 'advancedlockpick', uses = 12 },
}

-- % chance the lockpick snaps during a robbery (that one lockpick is lost).
Config.BreakChance = 5

-- How long the robbery takes (ms).
Config.RobTime = { min = 10000, max = 12500 }

-- A robbed meter is empty for this long (seconds) - for everyone.
Config.MeterCooldown = 16 * 60

-- Minimum time (seconds) between two robberies of the same player.
Config.PlayerCooldown = 45

-- Minimum on-duty police needed to rob a meter (0 = no requirement).
Config.MinPolice = 0
Config.PoliceJobs = { police = true, sheriff = true }

-- % chance the police get alerted when a robbery starts.
Config.AlertChance = 25

-- Called on the robber's client when an alert happens. Change it to your
-- dispatch script if you use one (ps-dispatch, cd_dispatch, ...).
Config.Dispatch = function(coords)
    TriggerServerEvent('police:server:policeAlert', 'Parking meter being broken into')
end

-- What a meter can contain. One row is picked by weight; `coins` gives a
-- random amount between min and max of each listed coin.
Config.Loot = {
    { weight = 30, coins = {} }, -- empty
    { weight = 45, coins = { silver = { 1, 3 } } },
    { weight = 18, coins = { silver = { 2, 4 }, gold = { 1, 1 } } },
    { weight = 7,  coins = { gold = { 1, 2 } } },
}

-- =========================================================================
-- Coins and the daily market
-- =========================================================================

-- Each coin has a price range. Every day the buyer picks ONE price per coin
-- inside its range that is the same for every player that day (e.g. today
-- silver = $100, gold = $750).
Config.Coins = {
    { id = 'silver', item = 'silvercoins', label = 'Silver Coin', min = 100, max = 200 },
    { id = 'gold',   item = 'goldcoins',   label = 'Gold Coin',   min = 500, max = 750 },
}

Config.Market = {
    -- 'random' = a fresh random price each day inside the range.
    -- 'trend'  = realistic: the new price moves from yesterday's price by at
    --            most `dailyChange` of the range (prices trend up/down
    --            instead of jumping around), always staying inside the range.
    mode = 'trend',
    dailyChange = 0.35,

    -- Hour (server time, 0-23) when a new market day starts.
    resetHour = 6,

    -- Optional supply & demand: every coin sold today lowers today's price
    -- by this share (0.002 = 0.2% per coin), never below the range minimum.
    -- 0 keeps one fixed price all day.
    saturation = 0,

    -- How the buyer pays: 'cash' or 'bank'.
    payment = 'cash',

    -- Max coins in one sale.
    maxPerSale = 500,
}

-- =========================================================================
-- Coin buyer ped (set its location here)
-- =========================================================================

Config.Buyer = {
    model = 'a_m_m_hasjew_01',
    coords = vector4(195.17, -933.77, 30.69, 144.0),
    scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
    sellDistance = 4.0, -- server side check
    blip = { enabled = false, sprite = 500, color = 46, scale = 0.7, label = 'Coin Buyer' },
}
