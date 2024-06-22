DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_renderer_stylesheet_attributes` (
  `classname` varchar(150) NOT NULL,
  `attribute` varchar(50) NOT NULL,
  `values` text NOT NULL,
  `enclose` varchar(50) DEFAULT '''',
  PRIMARY KEY (`classname`,`attribute`),
  KEY `idx_ds_renderer_stylesheet_attributes_classname` (`classname`),
  KEY `idx_ds_renderer_stylesheet_attributes_attribute` (`attribute`),
  CONSTRAINT `fk_ds_renderer_stylesheet_attributes_classname` FOREIGN KEY (`classname`) REFERENCES `ds_renderer_stylesheet` (`classname`) ON DELETE CASCADE ON UPDATE CASCADE
);