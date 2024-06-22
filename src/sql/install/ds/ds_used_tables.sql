DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_used_tables` (
  `table_name` varchar(128) NOT NULL,
  `used_table_name` varchar(128) NOT NULL,
  PRIMARY KEY (`table_name`,`used_table_name`),
  CONSTRAINT `fk_ds_used_tables_table_name` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);