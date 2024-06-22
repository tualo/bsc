DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_listplugins` (
  `table_name` varchar(128) NOT NULL,
  `ptype` varchar(255) NOT NULL,
  `placement` varchar(50) DEFAULT 'view',
  PRIMARY KEY (`table_name`,`ptype`),
  KEY `fk_ds_listplugins_ds` (`table_name`),
  CONSTRAINT `fk_ds_listplugins_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);