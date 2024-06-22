DELIMITER ;
CREATE TABLE IF NOT EXISTS `custom_types_attributes_boolean` (
  `id` varchar(100) NOT NULL,
  `property` varchar(100) NOT NULL,
  `description` varchar(255) DEFAULT '',
  `val` tinyint(4) DEFAULT NULL,
  PRIMARY KEY (`id`,`property`),
  CONSTRAINT `fk_custom_types_attributes_boolean_id` FOREIGN KEY (`id`) REFERENCES `custom_types` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
);