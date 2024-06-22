DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_sync_remove` (
  `table_name` varchar(64) NOT NULL,
  `filter_sql` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`table_name`),
  CONSTRAINT `fk_ds_sync_remove_ds_tn` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);