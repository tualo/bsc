DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_dropdownfields` (
  `table_name` varchar(128) NOT NULL,
  `name` varchar(100) NOT NULL DEFAULT '',
  `idfield` varchar(255) DEFAULT NULL,
  `displayfield` varchar(255) DEFAULT NULL,
  `filterconfig` text DEFAULT NULL,
  PRIMARY KEY (`table_name`,`name`),
  CONSTRAINT `fk_ds_dropdownfields_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);

ALTER TABLE `ds_dropdownfields`  add  IF NOT EXISTS  additional_fields JSON DEFAULT '[]' ;
