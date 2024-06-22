DELIMITER ;

CREATE TABLE IF NOT EXISTS `log_ds_sync` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(10) NOT NULL,
  `table_name` varchar(64) NOT NULL,
  `sync_id` varchar(50) NOT NULL,
  `createtime` datetime NOT NULL,
  `msg` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_log_ds_sync_table_name` (`table_name`)
);