DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_addcommand_locations` (
  `id` varchar(64) NOT NULL,
  PRIMARY KEY (`id`)
);

INSERT  IGNORE INTO `ds_addcommand_locations` VALUES
('formbuttons'),
('toolbar');