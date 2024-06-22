DELIMITER ;
CREATE TABLE IF NOT EXISTS `cron_queries_toexecute` (
  `id` varchar(36) NOT NULL,
  `createtime` datetime DEFAULT NULL,
  `query` longtext DEFAULT NULL,
  PRIMARY KEY (`id`)
);