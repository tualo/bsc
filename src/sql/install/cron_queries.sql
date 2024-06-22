delimiter ;

CREATE TABLE IF NOT EXISTS `cron_queries` (
  `id` int(11) NOT NULL,
  `name` varchar(255) DEFAULT NULL,
  `query` longtext DEFAULT NULL,
  PRIMARY KEY (`id`)
);