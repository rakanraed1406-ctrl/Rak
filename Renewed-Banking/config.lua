config = {
    -- Internal item name for the physical bank card. Change this one line
    -- (e.g. to 'visa') if you rename/re-register the item under a different
    -- key -- everything else in this resource reads from here.
    cardItem = 'visa',

    -- Extra *personal* bank accounts (beyond your free default one), and
    -- what each one costs. Index 1 = cost of your 2nd account, index 2 =
    -- cost of your 3rd. #personalAccountCosts is also the max you can open.
    personalAccountCosts = { 2500, 5000 },

    -- Shared accounts (created by a player, other citizens can be added as
    -- members). Cost to create one, how many one citizen may create, and
    -- how many members (creator included) one shared account may have.
    sharedAccountCost = 0,
    maxSharedAccounts = 3,
    maxAccountMembers = 10,

    -- Cost to set (or change) the PIN of a card.
    cardPinCost = 5000,

    -- Cost to replace a card you've reported lost or stolen. Also
    -- invalidates the old physical card (wherever it ends up).
    cardReplacementCost = 2500,

    -- How long (seconds) a newly requested card takes before it can be
    -- collected from the bank teller.
    cardPrepSeconds = 60,

    -- Maximum money that can sit on a physical card at once.
    maxCardBalance = 50000,

    -- Wrong PIN attempts allowed before the card is locked, and how long
    -- (seconds) it stays locked.
    pinMaxAttempts = 3,
    pinLockSeconds = 300,

    -- Max distance (server side check) between a player and a bank teller
    -- ped for the bank interface to work. Stops people from triggering
    -- the bank events from anywhere on the map.
    bankDistance = 8.0,

    -- Max distance between two players for a tap-to-pay card payment.
    cardPaymentDistance = 3.0,

    -- Limits applied to every deposit / withdraw / transfer.
    maxTransactionAmount = 10000000,
    maxCommentLength = 80,

    -- How many transactions are kept per account (older ones are dropped).
    maxTransactions = 150,

    -- Job/gang bosses (isboss grades) can always use the society account,
    -- even if their grade doesn't have bankAuth = true in shared/jobs.lua.
    bossAlwaysHasAccess = true,

    -- Optional integration with a "suspended services" script. If the
    -- resource isn't started, the check is skipped instead of blocking the
    -- bank. `metadata` is the player metadata key that blocks withdrawals
    -- and transfers server side.
    servicesCheck = {
        resource = 'qb-stopservices',
        callback = 'qb-stopservices:server:servicescheck',
        metadata = 'services'
    },

    -- Colors available for the physical bank card. Each card is given one of
    -- these at random when it's issued and it stays attached to that card.
    cardColors = {
        'blue',
        'gold',
        'silver',
        'purple',
        'green',
        'red',
        'black'
    },
    atms = {
        `prop_atm_01`,
        `prop_atm_02`,
        `prop_atm_03`,
        `prop_fleeca_atm`
    },
    peds = {
        [1] = {
            model = 'u_m_m_bankman',
            coords = vector4(262.15252685547,226.31996154785,106.28212738037, 161.10270690918)
        },
        [2] = {
            model = 'ig_barry',
            coords = vector4(313.84, -280.58, 54.16, 338.31)
        },
        [3] = {
            model = 'ig_barry',
            coords = vector4(149.46, -1042.09, 29.37, 335.43)
        },
        [4] = {
            model = 'ig_barry',
            coords = vector4(-351.23, -51.28, 49.04, 341.73)
        },
        [5] = {
            model = 'ig_barry',
            coords = vector4(-1211.9, -331.9, 37.78, 20.07)
        },
        [6] = {
            model = 'ig_barry',
            coords = vector4(-2961.14, 483.09, 15.7, 83.84)
        },
        [7] = {
            model = 'ig_barry',
            coords = vector4(1174.8, 2708.2, 38.09, 178.52)
        },
        [8] = {
            model = 'u_m_m_bankman',
            coords = vector4(-110.73394775391,6469.8383789063,31.634107589722, 223.76950073242)
        }
    }
}
