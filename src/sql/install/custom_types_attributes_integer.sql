DELIMITER ;
CREATE TABLE IF NOT EXISTS `custom_types_attributes_integer` (
  `id` varchar(100) NOT NULL,
  `property` varchar(100) NOT NULL,
  `description` varchar(255) DEFAULT '',
  `val` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`,`property`),
  CONSTRAINT `fk_custom_types_attributes_integer_id` FOREIGN KEY (`id`) REFERENCES `custom_types` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
);