DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_column_types` (
  `table_name` varchar(128) NOT NULL,
  `column_name` varchar(100) NOT NULL DEFAULT '',
  `xtype` varchar(255) NOT NULL,
  `default_value` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`table_name`,`column_name`),
  CONSTRAINT `fk_ds_column_types_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ds_column_types_ds_column` FOREIGN KEY (`table_name`, `column_name`) REFERENCES `ds_column` (`table_name`, `column_name`) ON DELETE CASCADE ON UPDATE CASCADE
);