DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_renderer_stylesheet_groups_assign` (
  `pug_id` varchar(50) NOT NULL,
  `group_id` int(11) NOT NULL DEFAULT 0,
  `active` tinyint(4) DEFAULT 0,
  PRIMARY KEY (`pug_id`,`group_id`),
  KEY `fk_ds_renderer_stylesheet_groups_assign_group_id` (`group_id`),
  CONSTRAINT `fk_ds_renderer_stylesheet_groups_assign_group_id` FOREIGN KEY (`group_id`) REFERENCES `ds_renderer_stylesheet_groups` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ds_renderer_stylesheet_groups_assign_pug_id` FOREIGN KEY (`pug_id`) REFERENCES `ds_pug_templates` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
);