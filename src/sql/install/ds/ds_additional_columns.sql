DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_additional_columns` (
  `table_name` varchar(128) NOT NULL,
  `column_name` varchar(64) NOT NULL,
  `sql_command` text DEFAULT NULL,
  `checked` tinyint(4) DEFAULT 0,
  `error_message` varchar(255) DEFAULT '',
  PRIMARY KEY (`table_name`,`column_name`),
  CONSTRAINT `fk_ds_additional_columns_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);