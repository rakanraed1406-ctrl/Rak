# parkingrob

Rob parking meters with a lockpick, then sell the coins to a buyer whose
price changes every day (the same price for everyone).

## Install
1. Put the folder in `resources` and add `ensure parkingrob` after qb-core, qb-target and qb-input.
2. Items `silvercoins` / `goldcoins` are registered automatically if they don't exist.
   Add `silvercoins.png` / `goldcoins.png` to your inventory images.
3. Set the buyer's location in `config.lua` -> `Config.Buyer.coords`.

## How it works
- Target a parking meter -> needs a `lockpick` (or `advancedlockpick`).
- Each finished robbery takes **one use** of the lockpick (`Config.Lockpicks`: 5 / 12 uses).
  When the uses run out, one lockpick is removed; the rest of the stack stays.
- A robbed meter is empty for everyone for `Config.MeterCooldown`.
- The server checks everything (lockpick, distance, robbery time, cooldowns, loot),
  so triggering the events by hand gives nothing.
- Coin buyer ped: "Sell coins" opens qb-input (pick the coin + amount), "Today's prices" shows the price and the change since yesterday.
- Daily price per coin: silver 100-200, gold 500-750 (configurable). In `trend` mode the
  price moves from yesterday's price like a real market. The price is saved, so a restart keeps it.
- Other resources can read the price: `exports.parkingrob:GetCoinPrice('gold')`.
