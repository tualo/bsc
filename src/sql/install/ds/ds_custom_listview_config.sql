DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_custom_listview_config` (
  `login` varchar(100) NOT NULL,
  `table_name` varchar(128) NOT NULL,
  `column_name` varchar(100) NOT NULL,
  `flex` int(11) DEFAULT 1,
  `width` decimal(15,6) DEFAULT -1.000000,
  `hidden` tinyint(4) DEFAULT 0,
  `position` int(11) DEFAULT 999,
  PRIMARY KEY (`login`,`table_name`,`column_name`),
  KEY `fk_ds_custom_listview_config_ds_column` (`table_name`,`column_name`),
  CONSTRAINT `fk_ds_custom_listview_config_ds_column` FOREIGN KEY (`table_name`, `column_name`) REFERENCES `ds_column` (`table_name`, `column_name`) ON DELETE CASCADE ON UPDATE CASCADE
);