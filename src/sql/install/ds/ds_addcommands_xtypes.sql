DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_addcommands_xtypes` (
  `id` varchar(128) NOT NULL,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
);

INSERT  IGNORE INTO `ds_addcommands_xtypes` VALUES
('cmp_setup_export_config_command','DS Export-Config'),
('cmp_setup_update_history_tables_command','DS Refresh-History-DDL'),
('compiler_command','Kompiler'),
('ds_batch_command','Batchupdate'),
('ds_cloneformlabel_command','DS Clone-Form-Label-List'),
('ds_cloneformlabel_export_command','DS Clone-Form-Label-Export'),
('ds_refresh_information_schema_command','DS Refresh-DDL-Information'),
('ds_rmcache_command','DS Clear-Cache'),
('ds_sync_command','DS Sync'),
('tbfill','Fill'),
('tbspacer','Spacer');