DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_calendar` (
  `table_name` varchar(64) NOT NULL,
  `calendar_table_name` varchar(64) NOT NULL,
  `name` varchar(50) NOT NULL,
  `reference` varchar(255) NOT NULL,
  PRIMARY KEY (`table_name`,`calendar_table_name`),
  KEY `fk_ds_calendar_ds_ctn` (`calendar_table_name`),
  CONSTRAINT `fk_ds_calendar_ds_ctn` FOREIGN KEY (`calendar_table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ds_calendar_ds_tn` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);