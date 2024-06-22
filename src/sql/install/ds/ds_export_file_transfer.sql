DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_export_file_transfer` (
  `id` varchar(36) NOT NULL,
  `table_name` varchar(128) NOT NULL,
  `server` varchar(100) NOT NULL,
  `username` varchar(100) NOT NULL,
  `password` varchar(100) NOT NULL,
  `path` varchar(100) DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_ds_export_file_transfer_table_name` (`table_name`),
  CONSTRAINT `fk_ds_export_file_transfer_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);