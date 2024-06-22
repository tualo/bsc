DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_dialog_condition_values` (
  `id` varchar(36) NOT NULL,
  `condition_id` varchar(36) NOT NULL,
  `field_name` varchar(64) NOT NULL,
  `value_operator` varchar(10) NOT NULL DEFAULT 'in',
  `val` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_ds_dialog_condition_values_condition_id_field` (`condition_id`,`field_name`),
  KEY `idx_ds_dialog_condition_values_condition_id` (`condition_id`),
  CONSTRAINT `fk_ds_dialog_condition_values_condition_id` FOREIGN KEY (`condition_id`) REFERENCES `ds_dialog_condition` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
);