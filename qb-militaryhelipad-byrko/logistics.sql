-- (the script creates these by itself on start — this file is only for reference)
CREATE TABLE IF NOT EXISTS `jt_logistics_shops` (
    `shop` VARCHAR(50) NOT NULL,
    `balance` BIGINT NOT NULL DEFAULT 0,
    `last_income` INT NOT NULL DEFAULT 0,
    `stock_reset` INT NOT NULL DEFAULT 0,
    `sold` LONGTEXT NULL,
    PRIMARY KEY (`shop`)
);
CREATE TABLE IF NOT EXISTS `jt_logistics_orders` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `shop` VARCHAR(50) NOT NULL,
    `citizenid` VARCHAR(50) NULL,
    `name` VARCHAR(100) NULL,
    `items` LONGTEXT NOT NULL,
    `total` BIGINT NOT NULL,
    `created` INT NOT NULL,
    `arrive` INT NOT NULL,
    `delivered` TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `shop_delivered` (`shop`, `delivered`)
);
CREATE TABLE IF NOT EXISTS `jt_logistics_depot` (
    `shop` VARCHAR(50) NOT NULL,
    `product` VARCHAR(60) NOT NULL,
    `amount` INT NOT NULL DEFAULT 0,      -- in the garage / ready
    `out_count` INT NOT NULL DEFAULT 0,   -- fleet vehicles taken out (in the world)
    PRIMARY KEY (`shop`, `product`)
);
-- upgrading from 3.0.0 (the script does this by itself too):
-- ALTER TABLE `jt_logistics_depot` ADD COLUMN `out_count` INT NOT NULL DEFAULT 0;
