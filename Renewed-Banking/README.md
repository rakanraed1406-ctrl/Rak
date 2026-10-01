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
* [qb-menu](https://github.com/qbcore-framework/qb-menu)
* [qb-input](https://github.com/qbcore-framework/qb-input)
* [progressbars](https://github.com/Project-Sloth/progressbar)

# Features
* Personal, Job, Gang, Shared Accounts
* Withdraw, Deposit, Transfer between accounts
* Offline Player Full Support
* QB Target Support
* Optimized Resource (0.00ms Running At All Times)

# Installation

1) Insert the SQL provided

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


# Custom changes in this copy

**New NUI (Dashboard / Accounts / Cards + ATM mode)**
* Completely redesigned interface (`web/public/app.js` + `app.css`) — a dashboard with a live bar chart, searchable transaction lists, a dedicated Accounts tab, and a new Cards tab.
* The NUI is now a plain HTML/CSS/JS app with **no build step** — you don't need Node/pnpm to install or edit it. Just edit `web/public/app.js` / `app.css` directly. (The original Svelte source is still in `web/src` for reference, but it is no longer what ships.)
* A separate, compact **ATM view** vs the full **bank ped view** (deposit/withdraw only + "Request Card" at ATMs; full dashboard + transfers + Cards management at bank peds).

**Bank cards + IBAN**
* Every account now has a generated IBAN (e.g. `B617521932`), shown on the dashboard and on each card.
* A new `bank_card` item is auto-registered into `QBCore.Shared.Items` (no need to edit qb-core's own item list) and is marked `useable` — using it from the inventory opens the bank UI straight to the Cards tab.
* Cards are only obtainable **from an ATM** ("Request a bank card" button), not from bank peds — enforced both client- and server-side.
* Freeze / Unfreeze a card straight from the Cards tab (personal accounts: anyone who owns it; shared/org accounts: only the creator). A frozen account is now also blocked **server-side** from deposits/withdrawals/transfers (previously this was a display-only bug, see below).

**Bug fixes**
* Fixed a real bug where the server sent the frozen flag as `frozen` but the UI always checked `isFrozen` — meaning a frozen account never actually showed as frozen or blocked any action. This is fixed and now enforced server-side too.
* Fixed a typo (`"erorr"` → `"error"`) in the police-lockout notification type.
* Removed some third-party promotional comments that had been injected into the original files.

**Database migration**
If you already had this resource installed, run once (safe to re-run):
```sql
ALTER TABLE `bank_accounts_new` ADD COLUMN IF NOT EXISTS `iban` varchar(20) DEFAULT NULL;
ALTER TABLE `player_transactions` ADD COLUMN IF NOT EXISTS `hasCard` int(11) DEFAULT 0;
ALTER TABLE `player_transactions` ADD COLUMN IF NOT EXISTS `iban` varchar(20) DEFAULT NULL;
```
(Fresh installs: just run the updated `Renewed-Banking.sql`, it already includes these columns.)

**Card artwork**
The `bank_card` item ships with `image = 'bank_card.png'` — drop a `bank_card.png` into your inventory resource's item-images folder (e.g. `qb-inventory/html/images/`) so it has an icon; otherwise it'll just show as a missing image in the inventory grid (it still works fine either way).
