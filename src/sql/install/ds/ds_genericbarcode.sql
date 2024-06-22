DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_genericbarcode` (
  `table_name` varchar(100) NOT NULL,
  `column_name` varchar(100) NOT NULL,
  `result_column_name` varchar(100) NOT NULL,
  `barcode_type` varchar(100) DEFAULT 'int25',
  `pxwidth` int(11) DEFAULT 260,
  `pxheight` int(11) DEFAULT 130,
  `outputtype` varchar(5) DEFAULT 'png',
  PRIMARY KEY (`table_name`,`column_name`)
);