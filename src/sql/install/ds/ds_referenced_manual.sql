DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_referenced_manual` (
  `table_name` varchar(128) NOT NULL DEFAULT '',
  `referenced_table_name` varchar(128) NOT NULL DEFAULT '',
  PRIMARY KEY (`table_name`,`referenced_table_name`),
  KEY `fk_ds_referenced_manual_referenced_table_name` (`referenced_table_name`),
  CONSTRAINT `fk_ds_referenced_manual_referenced_table_name` FOREIGN KEY (`referenced_table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ds_referenced_manual_table_name` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);