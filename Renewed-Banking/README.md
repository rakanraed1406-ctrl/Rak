# Renewed-Banking
<a href='https://ko-fi.com/ushifty' target='_blank'><img height='35' style='border:0px;height:46px;' src='https://az743702.vo.msecnd.net/cdn/kofi3.png?v=0' border='0' alt='Buy Me a Coffee at ko-fi.com' />
 
 [Renewed Discord](https://discord.gg/P3RMrbwA8n)

# Project Description
This resource was created by myself and was not a fork of any of the other banking resources. So lets not say "Isnt this x banking 🤓" because its not. The user interface was heavily inspired by No Pixels Banking Interface.
This resource is a replacement for Renewed-Banking, qb-atm, qb-managment

# Dependencies
* [oxmysql](https://github.com/overextended/oxmysql)
* [QBCore](https://github.com/qbcore-framework/qb-core)
* [QB-Target](https://github.com/qbcore-framework/qb-target)
* [progressbars](https://github.com/Project-Sloth/progressbar)

(qb-menu and qb-input are no longer needed - every prompt is inside the NUI.)

# Features
* Personal, Job, Gang, Shared Accounts
* Withdraw, Deposit, Transfer between accounts
* Offline Player Full Support
* QB Target Support
* Optimized Resource (0.00ms Running At All Times)

# Installation

1) Insert the SQL provided (optional - the resource creates/migrates its tables on start)

2) Edit your QBCore/Shared/jobs.lua and add `bankAuth = true` to the job grades which have access to society funds

## Transaction Integrations

```lua
exports['Renewed-Banking']:handleTransaction(account, title, amount, message, issuer, receiver, type, transID)
 ---@param account<string> - job name or citizenid
 ---@param title<string> - Title of transaction example `Personal Account / ${Player.PlayerData.citizenid}`
 ---@param amount<number> - Amount of money being transacted
 ---@param message<string> - Description of transaction
 ---@param issuer<string> - Name of Business or Character issuing the bill
 ---@param receiver<string> - Name of Business or Character receiving the bill
 ---@param type<string> - deposit | withdraw
 ---@param transID<string> - (optional) Force a specific transaction ID instead of generating one.

---@return transaction<table> {
  ---@param trans_id<string> - Transaction ID for the created transaction
  ---@param amount<number> - Amount of money being transacted
  ---@param trans_type<string> - deposit | withdraw
  ---@param receiver<string> - Name of Business or Character receiving the bill
  ---@param message<string> - Description of transaction
  ---@param issuer<string> - Name of Business or Character issuing the bill
  ---@param time<number> - Epoch timestamp of transaction
---}


exports['Renewed-Banking']:getAccountMoney(account)
 ---@param account<string> - Job Name | Custom Account Name

---@return amount<number> - Amount of money account has or false

exports['Renewed-Banking']:addAccountMoney(account, amount)
 ---@param account<string> - Job Name | Custom Account Name
  ---@param amount<number> - Amount of money being transacted

---@return complete<boolean> - true | false

exports['Renewed-Banking']:removeAccountMoney(account, amount)
 ---@param account<string> - Job Name | Custom Account Name
  ---@param amount<number> - Amount of money being transacted

---@return complete<boolean> - true | false
```

## qb-managment conversion
```lua
exports['qb-management']:GetAccount => exports['Renewed-Banking']:getAccountMoney
exports['qb-management']:AddMoney => exports['Renewed-Banking']:addAccountMoney
exports['qb-management']:RemoveMoney => exports['Renewed-Banking']:removeAccountMoney
exports['qb-management']:GetGangAccount=> exports['Renewed-Banking']:getAccountMoney
exports['qb-management']:AddGangMoney=> exports['Renewed-Banking']:addAccountMoney
exports['qb-management']:RemoveGangMoney=> exports['Renewed-Banking']:removeAccountMoney
```

 ## Change Logs
 V1.0.1
 ```
 Added Banking Blips
 ```


# Custom changes in this copy (v2.0.0)

## Interface
* Plain HTML/CSS/JS in `web/public` - no build step. Edit `app.js` / `app.css` directly.
* Four tabs at the bank: **Dashboard**, **Accounts**, **Cards**, **Statistics**.
* **Statistics tab**: account + period picker (7 days / 30 days / all), totals (deposited, withdrawn, net, count, average, largest deposit/withdrawal), a daily money-flow chart and a balance-trend chart (both with hover tooltips), a daily breakdown table (deposits, withdrawals, net, closing balance + totals) and the largest transactions. Export to CSV (copied to clipboard).
* Each transaction now stores the account balance after it, which feeds the balance trend.
* **No more native browser popups.** Setting a PIN, amounts, confirmations, names and member IDs all use in-NUI dialogs. The PIN is entered on a keypad (mouse or keyboard) and has to be typed twice.
* **ATM**: choose the card and enter its PIN inside the NUI (no qb-menu / qb-input), with quick-withdraw buttons and recent activity. Wrong PINs show the remaining attempts.
* Shared account management (create, members, rename, freeze, close) moved from qb-menu into the Accounts tab.
* Transfers accept an IBAN, account name, citizen ID or player server ID, and work for offline citizens.
* UI scales with the screen resolution.

## Security fixes
* All server actions now check that the player may use the account. Before, any player could withdraw from or transfer out of **any** job/gang/shared account, or **another player's** bank account, just by sending its id.
* An explicit balance check before taking bank money. Stock qb-core lets the bank balance go negative, so before this you could withdraw money you didn't have.
* Amounts are whole, positive numbers with a maximum. Negative, fractional, NaN and huge amounts are rejected.
* Bank actions only work while the bank is open next to a teller (checked on the server). ATM sessions only work while you still have the inserted card. Settings (PIN, cards, accounts) only work at the bank.
* PINs are no longer stored as plain text on the item, where anyone holding a stolen card could read them. Only a salted hash is kept on the server. Old cards are migrated the first time they're used.
* Wrong PIN limit (`config.pinMaxAttempts`), then the card locks for `config.pinLockSeconds`.
* Shared account names are validated: they can't take a job/gang name, an existing account or a citizen ID. Before, renaming an account to `police` replaced the police account.
* Account members can only be viewed or changed by the account's creator.
* Card payments (`payWithCard`, `chargeCard`) check the card version, whether the account is frozen and the distance between the players.
* Comments are cleaned and length-limited. All text in the UI is escaped.
* One action per player at a time (no double-click races).

## Bug fixes
* Locale strings now actually reach the UI. Before, the UI looked up `ui.x` inside the `ui` table, so it always fell back to English.
* The transfer comment used an undefined `name`.
* The bank no longer stops opening when `qb-stopservices` isn't installed. The check is skipped if that resource isn't running.
* Fixed a crash when a shared account in the cache was missing, when a job grade wasn't defined, and when a player wasn't cached yet.
* Shared account membership was found with `auth LIKE %cid%`, which could match other citizen IDs. Membership is now read from the cached list.
* `addAccountMoney` / `removeAccountMoney` now save to the database. Before, money added through these exports was lost on restart.
* The transaction history per account is capped (`config.maxTransactions`) so it no longer grows forever.
* Card metadata is updated in place. Before, the item was removed and added again, which could lose the card if adding it back failed.
* The schema check uses `INFORMATION_SCHEMA` instead of `ADD COLUMN IF NOT EXISTS`, which is MariaDB-only, so MySQL 8 works too.
* Job/gang society accounts are created automatically the first time someone with access opens the bank.
* A ped model that can't load no longer freezes the client. Peds and blips are cleaned up properly.

## New config options
`sharedAccountCost`, `maxSharedAccounts`, `maxAccountMembers`, `cardPrepSeconds`, `maxCardBalance`, `pinMaxAttempts`, `pinLockSeconds`, `bankDistance`, `cardPaymentDistance`, `maxTransactionAmount`, `maxCommentLength`, `maxTransactions`, `bossAlwaysHasAccess`, `servicesCheck`.

## Preview in a browser
Open `web/public/index.html` directly to see the UI with demo data (`?atm` shows the ATM flow, `?card` shows the card preview).
