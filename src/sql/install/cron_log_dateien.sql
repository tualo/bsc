DELIMITER ;

CREATE TABLE IF NOT EXISTS `cron_log_dateien` (
  `id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `datum` date NOT NULL,
  `zeit` time NOT NULL,
  PRIMARY KEY (`id`)
);