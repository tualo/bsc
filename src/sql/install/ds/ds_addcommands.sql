DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_addcommands` (
  `table_name` varchar(128) NOT NULL,
  `xtype` varchar(64) NOT NULL,
  `location` varchar(64) DEFAULT 'toolbar',
  `position` int(11) DEFAULT 1,
  `label` varchar(64) DEFAULT '',
  `iconCls` varchar(255) DEFAULT 'x-fa fa-plus',
  PRIMARY KEY (`table_name`,`xtype`),
  KEY `idx_ds_addcommands_table_name` (`table_name`),
  KEY `idx_ds_addcommands_location` (`location`),
  KEY `fk_ds_ds_addcommands_xtypes` (`xtype`),
  CONSTRAINT `fk_ds_addcommand_locations` FOREIGN KEY (`location`) REFERENCES `ds_addcommand_locations` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ds_ds_addcommands` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ds_ds_addcommands_xtypes` FOREIGN KEY (`xtype`) REFERENCES `ds_addcommands_xtypes` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
);

INSERT  IGNORE INTO `ds_addcommands` VALUES
('ds','cmp_setup_export_config_command','toolbar',1,'','x-fa fa-plus'),
('ds','cmp_setup_update_history_tables_command','toolbar',1,'','x-fa fa-plus'),
('ds','compiler_command','toolbar',1,'Kompiler',NULL),
('ds','ds_refresh_information_schema_command','toolbar',1,'DDL-Refresh',NULL),
('ds','ds_rmcache_command','toolbar',1,'','x-fa fa-plus'),
('ds_column_list_export','ds_cloneformlabel_export_command','toolbar',1,'','x-fa fa-plus'),
('ds_column_list_label','ds_cloneformlabel_command','toolbar',1,'','x-fa fa-plus'),
('ds_sync_data','ds_sync_command','toolbar',1,'','x-fa fa-plus');