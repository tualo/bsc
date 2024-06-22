DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_combined_tables` (
  `table_alias` varchar(64) NOT NULL,
  `table_name` varchar(128) NOT NULL,
  PRIMARY KEY (`table_alias`,`table_name`),
  KEY `fk_ds_combined_tables_ds_tn` (`table_name`),
  CONSTRAINT `fk_ds_combined_tables_ds_tn` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);