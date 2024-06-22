DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_column_form_properties` (
  `table_name` varchar(128) NOT NULL DEFAULT '',
  `column_name` varchar(100) NOT NULL DEFAULT '',
  `property` varchar(32) NOT NULL,
  `value` varchar(255) NOT NULL,
  PRIMARY KEY (`table_name`,`column_name`,`property`),
  KEY `fk_ds_column_form_properties_property` (`property`),
  CONSTRAINT `fk_ds_column_form_properties_form` FOREIGN KEY (`table_name`, `column_name`) REFERENCES `ds_column_form_label` (`table_name`, `column_name`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ds_column_form_properties_property` FOREIGN KEY (`property`) REFERENCES `ds_form_properties` (`property`) ON DELETE CASCADE ON UPDATE CASCADE
);