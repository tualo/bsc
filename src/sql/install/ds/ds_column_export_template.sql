DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_column_export_template` (
  `table_name` varchar(128) NOT NULL,
  `column_name` varchar(100) NOT NULL,
  `template` varchar(1000) DEFAULT '',
  PRIMARY KEY (`table_name`,`column_name`),
  CONSTRAINT `fk_ds_column_export_template_ds_column` FOREIGN KEY (`table_name`, `column_name`) REFERENCES `ds_column` (`table_name`, `column_name`) ON DELETE CASCADE ON UPDATE CASCADE
);