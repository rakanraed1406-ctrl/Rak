-- The resource also creates these tables / missing columns by itself on
-- start, so importing this file is optional. Works on MariaDB and MySQL 8.

CREATE TABLE IF NOT EXISTS `bank_accounts_new` (
  `id` varchar(50) NOT NULL,
  `amount` int(11) DEFAULT 0,
  `transactions` longtext,
  `auth` longtext,
  `isFrozen` int(11) DEFAULT 0,
  `creator` varchar(50) DEFAULT NULL,
  `iban` varchar(20) DEFAULT NULL,
  `hasCard` tinyint(1) NOT NULL DEFAULT 0,
  `cardVersion` int(11) NOT NULL DEFAULT 1,
  `cardPin` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS `player_transactions` (
  `id` varchar(50) NOT NULL,
  `isFrozen` int(11) DEFAULT 0,
  `hasCard` int(11) DEFAULT 0,
  `iban` varchar(20) DEFAULT NULL,
  `transactions` longtext,
  `cardVersion` int(11) NOT NULL DEFAULT 1,
  `cardPin` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`id`)
);

-- Job / gang society accounts. Any job or gang whose grade has
-- bankAuth = true (or isboss) also gets its account created automatically
-- the first time someone with access opens the bank.
INSERT IGNORE INTO `bank_accounts_new` (`id`, `amount`, `transactions`, `auth`, `isFrozen`, `creator`) VALUES
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
