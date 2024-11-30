DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_column` (
  `table_name` varchar(128) NOT NULL,
  `column_name` varchar(100) NOT NULL DEFAULT '',
  `default_value` varchar(255) DEFAULT NULL,
  `default_max_value` bigint(20) DEFAULT 10000000,
  `default_min_value` bigint(20) DEFAULT 0,
  `update_value` varchar(255) DEFAULT NULL,
  `is_primary` tinyint(4) DEFAULT 0,
  `syncable` tinyint(4) DEFAULT 0,
  `referenced_table` varchar(50) DEFAULT NULL,
  `referenced_column_name` varchar(50) DEFAULT NULL,
  `is_nullable` varchar(20) DEFAULT NULL,
  `is_referenced` varchar(20) DEFAULT NULL,
  `writeable` tinyint(4) DEFAULT 1,
  `note` varchar(50) DEFAULT '',
  `data_type` varchar(255) DEFAULT '',
  `column_key` varchar(255) DEFAULT '',
  `column_type` varchar(255) DEFAULT '',
  `character_maximum_length` bigint(20) DEFAULT 0,
  `numeric_precision` int(11) DEFAULT 0,
  `numeric_scale` int(11) DEFAULT 0,
  `character_set_name` varchar(255) DEFAULT '',
  `privileges` varchar(255) DEFAULT '',
  `existsreal` tinyint(4) DEFAULT 0,
  `deferedload` tinyint(4) DEFAULT 0,
  `hint` varchar(255) DEFAULT NULL,
  `fieldtype` varchar(100) DEFAULT '',
  PRIMARY KEY (`table_name`,`column_name`),
  UNIQUE KEY `udix_ds_column_table_name_column_name` (`table_name`,`column_name`),
  CONSTRAINT `fk_ds_column_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);



alter table ds_column add column if not exists fieldtype varchar(50) default '';
alter table ds_column add column if not exists  is_generated varchar(30) default '';


