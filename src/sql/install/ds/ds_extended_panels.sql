DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_extended_panels` (
  `table_name` varchar(64) NOT NULL DEFAULT '',
  `name` varchar(100) NOT NULL DEFAULT '',
  `xtype` varchar(100) NOT NULL DEFAULT '',
  `columnsdef` longtext DEFAULT NULL,
  `position` int(11) DEFAULT 0,
  `active` tinyint(4) DEFAULT 1,
  PRIMARY KEY (`table_name`,`name`),
  CONSTRAINT `fk_ds_extended_panels_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);