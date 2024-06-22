DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_pug_templates` (
  `id` varchar(50) NOT NULL,
  `name` varchar(255) NOT NULL,
  `note` longtext DEFAULT NULL,
  `template` longtext NOT NULL,
  PRIMARY KEY (`id`)
);