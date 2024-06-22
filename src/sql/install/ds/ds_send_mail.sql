DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_send_mail` (
  `table_name` varchar(128) NOT NULL,
  `send_from` varchar(255) DEFAULT '',
  `send_from_name` varchar(255) DEFAULT '',
  `subject_template` varchar(255) DEFAULT '',
  `reply_to` varchar(255) DEFAULT '',
  `reply_to_name` varchar(255) DEFAULT '',
  `body` longtext DEFAULT '',
  PRIMARY KEY (`table_name`),
  CONSTRAINT `fk_ds_send_mail_table_name` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);