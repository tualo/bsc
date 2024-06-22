DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_sync_data` (
  `id` int(11) NOT NULL,
  `table_name` varchar(128) DEFAULT NULL,
  `foreign_table_name` varchar(64) DEFAULT NULL,
  `url` varchar(100) DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `sync_id` varchar(255) NOT NULL,
  `get_oauth` varchar(255) NOT NULL,
  `set_oauth` varchar(255) NOT NULL,
  `checkssl` tinyint(4) NOT NULL DEFAULT 1,
  `msg_get_oauth` varchar(255) DEFAULT '',
  `msg_set_oauth` varchar(255) DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uidx_ds_sync_data_sync_id` (`sync_id`),
  KEY `fk_ds_sync_data_table_name` (`table_name`),
  CONSTRAINT `fk_ds_sync_data_table_name` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);