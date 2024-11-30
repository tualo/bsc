DELIMITER ;

CREATE TABLE IF NOT EXISTS `extjs_base_types` (
  `id` varchar(100) NOT NULL,
  `classname` varchar(255) NOT NULL,
  `baseclass` varchar(255) NOT NULL,
  `xtype_long_classic` varchar(100) DEFAULT NULL,
  `xtype_long_modern` varchar(100) DEFAULT NULL,
  `name` varchar(100) NOT NULL,
  `vendor` varchar(50) NOT NULL,
  `description` varchar(255) DEFAULT '',
  `iscolumn` tinyint(4) DEFAULT 0,
  `isformfield` tinyint(4) DEFAULT 0,
  PRIMARY KEY (`id`)
);


alter table `extjs_base_types` add column if not exists `iscolumn` tinyint(4) DEFAULT 0;
alter table `extjs_base_types` add column if not exists `isformfield` tinyint(4) DEFAULT 0;

