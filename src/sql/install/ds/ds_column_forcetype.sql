DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_column_forcetype` (
  `table_name` varchar(128) NOT NULL,
  `column_name` varchar(100) NOT NULL,
  `fieldtype` varchar(128) NOT NULL,
  PRIMARY KEY (`table_name`,`column_name`),
  CONSTRAINT `fk_ds_column_forcetype_ds_column` FOREIGN KEY (`table_name`, `column_name`) REFERENCES `ds_column` (`table_name`, `column_name`) ON DELETE CASCADE ON UPDATE CASCADE
);
INSERT  IGNORE INTO `ds_column_forcetype` VALUES
('adressen','umsatz_spline','stringarray');