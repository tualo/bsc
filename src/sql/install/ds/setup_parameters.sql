DELIMITER ;

CREATE TABLE IF NOT EXISTS `setup_parameters` (
  `cmp` varchar(64) NOT NULL,
  `id` varchar(64) NOT NULL,
  `name` varchar(255) NOT NULL,
  `description` varchar(4000) NOT NULL DEFAULT '',
  PRIMARY KEY (`cmp`,`id`)
);