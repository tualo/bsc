DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_backup_importance` (
  `table_name` varchar(128) NOT NULL,
  `type` varchar(20) DEFAULT NULL,
  `importance` decimal(4,3) DEFAULT 1.000,
  PRIMARY KEY (`table_name`),
  CONSTRAINT `fk_ds_backup_importance_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);