CREATE TABLE IF NOT EXISTS `bank_accounts_new` (
  `id` varchar(50) NOT NULL,
  `amount` int(11) DEFAULT 0,
  `transactions` longtext DEFAULT '[]',
  `auth` longtext DEFAULT '[]',
  `isFrozen` int(11) DEFAULT 0,
  `creator` varchar(50) DEFAULT NULL,
  `iban` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`id`)
);

INSERT INTO `bank_accounts_new` (`id`, `amount`, `transactions`, `auth`, `isFrozen`, `creator`) VALUES
	('ambulance', 0, '[]', '[]', 0, NULL),
	('cardealer', 0, '[]', '[]', 0, NULL),
	('mechanic', 0, '[]', '[]', 0, NULL),
	('police', 0, '[]', '[]', 0, NULL),
	('realestate', 0, '[]', '[]', 0, NULL),
	('lostmc', 0, '[]', '[]', 0, NULL),
	('ballas', 0, '[]', '[]', 0, NULL),
	('vagos', 0, '[]', '[]', 0, NULL),
	('cartel', 0, '[]', '[]', 0, NULL),
	('families', 0, '[]', '[]', 0, NULL),
	('triads', 0, '[]', '[]', 0, NULL);

CREATE TABLE IF NOT EXISTS `player_transactions` (
  `id` varchar(50) NOT NULL,
  `isFrozen` int(11) DEFAULT 0,
  `hasCard` int(11) DEFAULT 0,
  `iban` varchar(20) DEFAULT NULL,
  `transactions` longtext DEFAULT '[]',
  PRIMARY KEY (`id`)
);

-- ============================================================
-- MIGRATION: if you already had this resource installed before
-- the Cards / IBAN update, run the two lines below ONCE to add
-- the new columns to your existing tables (safe to re-run, they
-- no-op if the columns already exist).
-- ============================================================
ALTER TABLE `bank_accounts_new` ADD COLUMN IF NOT EXISTS `iban` varchar(20) DEFAULT NULL;
ALTER TABLE `player_transactions` ADD COLUMN IF NOT EXISTS `hasCard` int(11) DEFAULT 0;
ALTER TABLE `player_transactions` ADD COLUMN IF NOT EXISTS `iban` varchar(20) DEFAULT NULL;
