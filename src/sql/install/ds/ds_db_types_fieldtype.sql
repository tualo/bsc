DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_db_types_fieldtype` (
  `dbtype` varchar(32) NOT NULL,
  `fieldtype` varchar(32) NOT NULL,
  PRIMARY KEY (`dbtype`)
);
 
INSERT  IGNORE INTO `ds_db_types_fieldtype` VALUES
('bigint','integer'),
('date','date'),
('datetime','date'),
('decimal','number'),
('double','number'),
('float','number'),
('int','integer'),
('time','date'),
('tinyint','boolean'),
('varchar','string');