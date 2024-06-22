DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_renderer` (
  `table_name` varchar(128) NOT NULL,
  `pug_template` varchar(50) NOT NULL,
  `label` varchar(100) NOT NULL,
  `orientation` varchar(20) DEFAULT 'portrait',
  `useremote` tinyint(4) DEFAULT 0,
  PRIMARY KEY (`table_name`,`pug_template`),
  KEY `fk_ds_renderer_pug_template` (`pug_template`),
  CONSTRAINT `fk_ds_renderer_pug_template` FOREIGN KEY (`pug_template`) REFERENCES `ds_pug_templates` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ds_renderer_table_name` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);