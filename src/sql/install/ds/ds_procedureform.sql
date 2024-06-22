DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_procedureform` (
  `id` varchar(128) NOT NULL,
  `property` varchar(100) NOT NULL DEFAULT '',
  `language` varchar(3) NOT NULL DEFAULT 'DE',
  `label` varchar(255) NOT NULL,
  `xtype` varchar(255) DEFAULT NULL,
  `position` int(11) DEFAULT 0,
  `hidden` tinyint(4) DEFAULT 0,
  `active` tinyint(4) DEFAULT 1,
  `default_value` varchar(255) DEFAULT '',
  `allowempty` tinyint(4) DEFAULT 1,
  PRIMARY KEY (`id`,`property`,`language`)
);