DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_contextmenu_params` (
  `table_name` varchar(128) NOT NULL,
  `name` varchar(50) NOT NULL DEFAULT '',
  `param` varchar(50) NOT NULL DEFAULT '',
  PRIMARY KEY (`table_name`,`name`,`param`),
  CONSTRAINT `fk_ds_ctx_pr_ds_ctx` FOREIGN KEY (`table_name`, `name`) REFERENCES `ds_contextmenu` (`table_name`, `name`) ON DELETE CASCADE ON UPDATE CASCADE
);