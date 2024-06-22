DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_renderer_stylesheet_groups` (
  `id` int(11) NOT NULL DEFAULT 0,
  `name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uidx_ds_renderer_stylesheet_groups_name` (`name`)
) ;