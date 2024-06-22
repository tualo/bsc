DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_dialog_condition` (
  `id` varchar(36) NOT NULL,
  `logic_operator` varchar(10) NOT NULL,
  `parent_id` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_ds_dialog_condition_values_self` (`parent_id`),
  CONSTRAINT `fk_ds_dialog_condition_values_self` FOREIGN KEY (`parent_id`) REFERENCES `ds_dialog_condition` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
);