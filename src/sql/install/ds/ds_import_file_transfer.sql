DELIMITER //

CREATE TABLE IF NOT EXISTS `ds_import_file_transfer` (
  `id` varchar(36) NOT NULL,
  `table_name` varchar(128) NOT NULL,
  `server` varchar(100) NOT NULL,
  `username` varchar(100) NOT NULL,
  `password` varchar(100) NOT NULL,
  `path` varchar(100) DEFAULT '',
  `filematch` varchar(50) DEFAULT '*',
  `encode_utf8` tinyint(4) DEFAULT 0,
  `use_load_file` tinyint(4) DEFAULT 0,
  `deleteafterimport` tinyint(4) DEFAULT 0,
  `addmd5id` tinyint(4) DEFAULT 0,
  `enclose` varchar(50) DEFAULT '"',
  `line_delimiter` varchar(50) DEFAULT '',
  `delimiter` varchar(50) DEFAULT ';',
  PRIMARY KEY (`id`),
  KEY `idx_ds_import_file_transfer_table_name` (`table_name`),
  CONSTRAINT `fk_ds_import_file_transfer_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
) //