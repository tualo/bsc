DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_column_dialog_label` (
  `table_name` varchar(128) NOT NULL DEFAULT '',
  `column_name` varchar(100) NOT NULL DEFAULT '',
  `language` varchar(3) NOT NULL DEFAULT 'DE',
  `label` varchar(255) NOT NULL,
  `text` longtext DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `field_path` varchar(255) NOT NULL,
  PRIMARY KEY (`table_name`,`column_name`,`language`),
  CONSTRAINT `fk_ds_column_dialog_label_ds_column` FOREIGN KEY (`table_name`, `column_name`) REFERENCES `ds_column` (`table_name`, `column_name`) ON DELETE CASCADE ON UPDATE CASCADE
);