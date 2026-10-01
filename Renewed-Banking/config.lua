config = {
    -- Internal item name for the physical bank card. Change this one line
    -- (e.g. to 'visa') if you rename/re-register the item under a different
    -- key -- everything else in this resource reads from here.
    cardItem = 'visa',

    -- Extra *personal* bank accounts (beyond your free default one), and
    -- what each one costs. Index 1 = cost of your 2nd account, index 2 =
    -- cost of your 3rd. #personalAccountCosts is also the max you can open.
    personalAccountCosts = { 2500, 5000 },

    -- Cost to set a PIN on your physical card.
    cardPinCost = 5000,

    -- Cost to replace a card you've reported lost or stolen. Also
    -- invalidates the old physical card (wherever it ends up).
    cardReplacementCost = 2500,

    -- Colors available for the physical bank card. Each card is given one of
    -- these at random when it's issued (see server/main.lua "requestCard")
    -- and it stays permanently attached to that card afterwards.
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

