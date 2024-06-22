DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_preview_form_label` (
  `table_name` varchar(128) NOT NULL,
  `column_name` varchar(64) NOT NULL,
  `language` varchar(3) NOT NULL DEFAULT 'DE',
  `label` varchar(255) NOT NULL,
  `xtype` varchar(255) DEFAULT NULL,
  `field_path` varchar(255) NOT NULL DEFAULT '',
  `position` int(11) DEFAULT 0,
  `active` tinyint(4) DEFAULT 1,
  `editor` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`table_name`,`column_name`,`language`),
  CONSTRAINT `fk_ds_preview_form_label_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);