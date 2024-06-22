DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_column_tagfields` (
  `table_name` varchar(128) DEFAULT NULL,
  `column_name` varchar(64) NOT NULL,
  `language` varchar(3) NOT NULL DEFAULT 'DE',
  `label` varchar(255) NOT NULL,
  `xtype` varchar(255) DEFAULT NULL,
  `field_path` varchar(255) NOT NULL DEFAULT '',
  `position` int(11) DEFAULT 0,
  `hidden` tinyint(4) DEFAULT 0,
  `active` tinyint(4) DEFAULT 1,
  `referenced_table_name` varchar(128) DEFAULT NULL,
  `constraint_name` varchar(64) NOT NULL,
  `referenced_constraint_name` varchar(64) NOT NULL,
  `intermedia_table_name` varchar(128) DEFAULT NULL,
  `table_name_json` varchar(255) DEFAULT NULL,
  `referenced_table_json` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`constraint_name`,`referenced_constraint_name`),
  UNIQUE KEY `table_name_2` (`table_name`,`column_name`,`language`),
  KEY `table_name` (`table_name`),
  CONSTRAINT `fk_ds_column_tagfields_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);