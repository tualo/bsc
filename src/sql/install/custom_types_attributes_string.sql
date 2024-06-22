DELIMITER ;
CREATE TABLE IF NOT EXISTS `custom_types_attributes_string` (
  `id` varchar(100) NOT NULL,
  `property` varchar(100) NOT NULL,
  `description` varchar(255) DEFAULT '',
  `val` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`,`property`),
  CONSTRAINT `fk_custom_types_attributes_string_id` FOREIGN KEY (`id`) REFERENCES `custom_types` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
);

INSERT  IGNORE INTO `custom_types_attributes_string` VALUES
('Tualo.grid.column.DatetimeDisplayColumn','align','','center'),
('Tualo.grid.column.DatetimeDisplayColumn','defaultFilterType','','date'),
('Tualo.grid.column.DatetimeDisplayColumn','format','','d.m.Y H:i'),
('Tualo.grid.column.DEDateDisplayColumn','align','','center'),
('Tualo.grid.column.DEDateDisplayColumn','defaultFilterType','','date'),
('Tualo.grid.column.DEDateDisplayColumn','format','','d.m.Y'),
('Tualo.grid.column.MoneyColumn2','align','','right'),
('Tualo.grid.column.MoneyColumn2','defaultFilterType','','number'),
('Tualo.grid.column.MoneyColumn2','format','','0.000,00'),
('Tualo.grid.column.MoneyColumn5','align','','right'),
('Tualo.grid.column.MoneyColumn5','defaultFilterType','','number'),
('Tualo.grid.column.MoneyColumn5','format','','0.000,00/i'),
('Tualo.grid.column.Number0','align','','right'),
('Tualo.grid.column.Number0','defaultFilterType','','number'),
('Tualo.grid.column.Number0','format','','0.000/i'),
('Tualo.grid.column.Number2','align','','right'),
('Tualo.grid.column.Number2','defaultFilterType','','number'),
('Tualo.grid.column.Number2','format','','0.000,00'),
('Tualo.grid.column.Number5','align','','right'),
('Tualo.grid.column.Number5','defaultFilterType','','number'),
('Tualo.grid.column.Number5','format','','0.000,00000');