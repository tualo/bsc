DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_dictionary` (
  `key` varchar(36) NOT NULL,
  `lang` varchar(10) NOT NULL,
  `msg` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`key`,`lang`)
);