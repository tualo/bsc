DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_dropdownfields` (
  `table_name` varchar(128) NOT NULL,
  `name` varchar(100) NOT NULL DEFAULT '',
  `idfield` varchar(255) DEFAULT NULL,
  `displayfield` varchar(255) DEFAULT NULL,
  `filterconfig` text DEFAULT NULL,
  PRIMARY KEY (`table_name`,`name`),
  CONSTRAINT `fk_ds_dropdownfields_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);


INSERT  IGNORE INTO `ds_dropdownfields` VALUES
('crontab_applications','Anwendung','id','name',''),
('crontab_weekdays','Wochhentag','id','name',''),
('cron_queries','id','id','name',''),
('ds','Tabelle','table_name','title',''),
('ds_addcommands_xtypes','id','id','name',''),
('ds_addcommand_locations','id','id','id',''),
('ds_class','class_name','class_name','class_name',''),
('ds_form_properties','property','property','property',''),
('ds_pug_templates','id','id','name',''),
('ds_renderer_stylesheet_groups','id','id','name',''),
('ds_sync_data','Name','id','name',''),
('farben','rgb','rgb','name',''),
('setup_parameters','id','id','name',''),
('view_ds_listfilters','id','id','name','');