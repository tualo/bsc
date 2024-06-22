DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_dialog_card_fields` (
  `dialog_id` varchar(32) NOT NULL,
  `card_id` varchar(32) NOT NULL,
  `table_name` varchar(128) NOT NULL,
  `column_name` varchar(32) NOT NULL,
  `frameset` varchar(255) DEFAULT '',
  `label` varchar(255) DEFAULT '',
  `xtype` varchar(255) DEFAULT '',
  `active` tinyint(4) DEFAULT 0,
  `hidden` tinyint(4) DEFAULT 1,
  `allowempty` tinyint(4) DEFAULT 1,
  `position` int(11) DEFAULT 0,
  PRIMARY KEY (`dialog_id`,`card_id`,`table_name`,`column_name`),
  KEY `fk_ds_dialog_card_fields_ds_column` (`table_name`,`column_name`),
  CONSTRAINT `fk_ds_dialog_card_fields_dialog_id` FOREIGN KEY (`dialog_id`, `card_id`) REFERENCES `ds_dialog_cards` (`dialog_id`, `card_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ds_dialog_card_fields_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ds_dialog_card_fields_ds_column` FOREIGN KEY (`table_name`, `column_name`) REFERENCES `ds_column` (`table_name`, `column_name`) ON DELETE CASCADE ON UPDATE CASCADE
);