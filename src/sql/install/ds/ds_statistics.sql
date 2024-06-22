DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_statistics` (
  `table_name` varchar(128) NOT NULL,
  `meassured` datetime NOT NULL,
  `data_length` bigint(20) DEFAULT 0,
  `index_length` bigint(20) DEFAULT 0,
  PRIMARY KEY (`table_name`,`meassured`),
  KEY `idx_ds_statistics_table_name` (`table_name`),
  KEY `idx_ds_statistics_meassured` (`meassured`),
  CONSTRAINT `fk_ds_statistics_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);