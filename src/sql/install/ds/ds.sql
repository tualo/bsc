DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds` (
  `table_name` varchar(128) NOT NULL,
  `title` varchar(255) DEFAULT NULL,
  `reorderfield` varchar(255) DEFAULT NULL,
  `use_history` tinyint(4) DEFAULT 0,
  `searchfield` varchar(255) DEFAULT NULL,
  `displayfield` varchar(255) DEFAULT NULL,
  `sortfield` varchar(50) DEFAULT NULL,
  `searchany` tinyint(4) DEFAULT 1,
  `hint` longtext DEFAULT NULL,
  `overview_tpl` longtext DEFAULT NULL,
  `sync_table` varchar(255) DEFAULT NULL,
  `writetable` varchar(255) DEFAULT NULL,
  `globalsearch` tinyint(4) DEFAULT 0,
  `listselectionmodel` varchar(100) DEFAULT 'cellmodel',
  `sync_view` varchar(255) DEFAULT NULL,
  `syncable` tinyint(4) DEFAULT 0,
  `cssstyle` varchar(100) DEFAULT NULL,
  `alternativeformxtype` varchar(50) DEFAULT '',
  `read_table` varchar(64) DEFAULT NULL,
  `class_name` varchar(64) DEFAULT 'Unklassifiziert',
  `special_add_panel` varchar(64) DEFAULT NULL,
  `existsreal` tinyint(4) DEFAULT 0,
  `character_set_name` varchar(255) DEFAULT '',
  `read_filter` text DEFAULT NULL,
  `listxtypeprefix` varchar(30) DEFAULT 'listview',
  `phpexporter` varchar(30) DEFAULT 'XlsxWriter',
  `phpexporterfilename` varchar(255) DEFAULT NULL,
  `combined` tinyint(4) DEFAULT 0,
  `default_pagesize` int(11) DEFAULT 100,
  `allowForm` tinyint(4) DEFAULT 1,
  `listviewbaseclass` varchar(255) DEFAULT 'Tualo.DataSets.ListView',
  `showactionbtn` tinyint(4) DEFAULT 1,
  `modelbaseclass` varchar(100) DEFAULT 'Tualo.DataSets.model.Basic',
  PRIMARY KEY (`table_name`),
  KEY `fk_ds_class_name` (`class_name`),
  CONSTRAINT `fk_ds_class_name` FOREIGN KEY (`class_name`) REFERENCES `ds_class` (`class_name`) ON DELETE SET NULL ON UPDATE CASCADE
);

alter table ds change column phpexporterfilename
    phpexporterfilename varchar(255) DEFAULT NULL;

alter table ds add column if not exists autosave tinyint(1) default 0;
alter table ds add column if not exists base_store_class varchar(50) default 'Tualo.DataSets.data.Store';
alter table ds add column if not exists use_insert_for_update tinyint(1) default 0;

update ds set use_insert_for_update = 1 where table_name like 'ds%';

update ds set base_store_class = 'Tualo.DataSets.data.Store' where  base_store_class is null or base_store_class = '';

alter table ds add column if not exists modelbaseclass varchar(100) default 'Tualo.DataSets.model.Basic';



CREATE TABLE IF NOT EXISTS `ds_reference_tables` (
  `table_name` varchar(128) NOT NULL,
  `reference_table_name` varchar(100) NOT NULL DEFAULT '',
  `columnsdef` longtext DEFAULT NULL,
  `constraint_name` varchar(128) NOT NULL primary key,
  `active` tinyint(4) DEFAULT 1,
  `searchable` tinyint(4) DEFAULT 0,
  `autosync` tinyint(4) DEFAULT 1,
  `position` int(11) DEFAULT 99999,
  `path` varchar(100) DEFAULT '',
  `existsreal` int(11) DEFAULT 1,
  `tabtitle` varchar(50) DEFAULT '',
  KEY `fk_ds_reference_tables_r_ds` (`reference_table_name`),
  KEY `idx_ds_reference_tables_table_name_reference_table_name` (`table_name`,`reference_table_name`),
  KEY `idx_ds_reference_tables_table_name` (`table_name`),
  CONSTRAINT `fk_ds_reference_tables_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ds_reference_tables_r_ds` FOREIGN KEY (`reference_table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);