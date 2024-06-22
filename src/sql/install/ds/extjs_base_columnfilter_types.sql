DELIMITER ;

CREATE TABLE IF NOT EXISTS `extjs_base_columnfilter_types` (
  `id` varchar(100) NOT NULL,
  `iscolumnfilter` tinyint(4) DEFAULT 0,
  PRIMARY KEY (`id`)
);