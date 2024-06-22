DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_searchfields` (
  `table_name` varchar(128) NOT NULL,
  `column_name` varchar(64) NOT NULL,
  `active` tinyint(4) DEFAULT 0,
  PRIMARY KEY (`table_name`,`column_name`),
  KEY `idx_ds_searchfields_table_name` (`table_name`),
  CONSTRAINT `fk_ds_column_ds_searchfields` FOREIGN KEY (`table_name`, `column_name`) REFERENCES `ds_column` (`table_name`, `column_name`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ds_ds_searchfields` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);