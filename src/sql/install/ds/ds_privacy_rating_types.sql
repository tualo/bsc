DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_privacy_rating_types` (
  `id` varchar(36) NOT NULL,
  `name` varchar(255) NOT NULL,
  `score` int(11) DEFAULT 0,
  PRIMARY KEY (`id`)
);

INSERT  IGNORE INTO `ds_privacy_rating_types` VALUES
('undefined','Unbestimmt',0);