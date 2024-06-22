DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_sync_lock` (
  `id` varchar(100) NOT NULL,
  `createtime` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
);