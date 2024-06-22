DELIMITER ;

CREATE TABLE IF NOT EXISTS `setup` (
  `id` varchar(64) NOT NULL,
  `rolle` varchar(255) NOT NULL,
  `cmp` varchar(64) NOT NULL,
  `daten` longtext DEFAULT NULL,
  `vererbbar` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`,`rolle`,`cmp`),
  KEY `fk_setup_setup_parameters` (`cmp`,`id`),
  CONSTRAINT `fk_setup_setup_parameters` FOREIGN KEY (`cmp`, `id`) REFERENCES `setup_parameters` (`cmp`, `id`) ON DELETE CASCADE ON UPDATE CASCADE
);