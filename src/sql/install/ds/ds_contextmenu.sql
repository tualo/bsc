DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_contextmenu` (
  `table_name` varchar(128) NOT NULL,
  `name` varchar(100) NOT NULL DEFAULT '',
  `component` varchar(255) NOT NULL,
  `paramfield` varchar(255) NOT NULL,
  `position` int(11) DEFAULT 0,
  PRIMARY KEY (`table_name`,`name`),
  CONSTRAINT `fk_ds_ctx_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);