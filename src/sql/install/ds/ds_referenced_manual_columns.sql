DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_referenced_manual_columns` (
  `table_name` varchar(128) NOT NULL DEFAULT '',
  `referenced_table_name` varchar(128) NOT NULL DEFAULT '',
  `column_name` varchar(128) NOT NULL,
  `referenced_column_name` varchar(128) DEFAULT NULL,
  PRIMARY KEY (`table_name`,`referenced_table_name`,`column_name`),
  KEY `fk_ds_referenced_manual_columns_ds_column` (`table_name`,`column_name`),
  KEY `fk_ds_referenced_manual_columns_ds_column_ref` (`referenced_table_name`,`referenced_column_name`),
  CONSTRAINT `fk_ds_referenced_manual_columns_ds_column` FOREIGN KEY (`table_name`, `column_name`) REFERENCES `ds_column` (`table_name`, `column_name`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ds_referenced_manual_columns_ds_column_ref` FOREIGN KEY (`referenced_table_name`, `referenced_column_name`) REFERENCES `ds_column` (`table_name`, `column_name`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ds_referenced_manual_columns_ds_referenced_manual` FOREIGN KEY (`table_name`, `referenced_table_name`) REFERENCES `ds_referenced_manual` (`table_name`, `referenced_table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);