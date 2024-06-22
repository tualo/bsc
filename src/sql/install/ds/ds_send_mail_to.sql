DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_send_mail_to` (
  `table_name` varchar(128) NOT NULL,
  `send_to` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`table_name`,`send_to`),
  CONSTRAINT `fk_ds_send_mail_to_table_name` FOREIGN KEY (`table_name`) REFERENCES `ds_send_mail` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);