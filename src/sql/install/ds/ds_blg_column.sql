DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_blg_column` (
  `table_name` varchar(128) NOT NULL,
  `column_name` varchar(100) NOT NULL,
  `active` tinyint(4) DEFAULT 0,
  PRIMARY KEY (`table_name`,`column_name`),
  CONSTRAINT `fk_ds_blg_column_ds_column` FOREIGN KEY (`table_name`, `column_name`) REFERENCES `ds_column` (`table_name`, `column_name`) ON DELETE CASCADE ON UPDATE CASCADE
);