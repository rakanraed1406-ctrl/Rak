-- player_helicopters (only needed if you don't have the table yet)
CREATE TABLE IF NOT EXISTS `player_helicopters` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `vehicle` varchar(50) NOT NULL,
    `plate` varchar(15) NOT NULL,
    `stored` tinyint(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    UNIQUE KEY `plate` (`plate`),
    KEY `citizenid` (`citizenid`)
);

-- already have the table? a unique plate stops two helicopters sharing one:
-- ALTER TABLE `player_helicopters` ADD UNIQUE INDEX `plate` (`plate`);
