DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_form_properties` (
  `property` varchar(32) NOT NULL,
  `value_xtype` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`property`)
);