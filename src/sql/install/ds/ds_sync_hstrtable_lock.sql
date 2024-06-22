DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_sync_hstrtable_lock` (
  `table_name` varchar(64) NOT NULL,
  `locktime` datetime NOT NULL,
  PRIMARY KEY (`table_name`)
);