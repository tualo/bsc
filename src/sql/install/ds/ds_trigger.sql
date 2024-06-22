DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_trigger` (
  `type` varchar(100) NOT NULL DEFAULT '',
  `table_name` varchar(128) NOT NULL,
  `program` varchar(255) NOT NULL,
  PRIMARY KEY (`type`,`table_name`),
  KEY `fk_ds_trigger_ds` (`table_name`),
  CONSTRAINT `fk_ds_trigger_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);