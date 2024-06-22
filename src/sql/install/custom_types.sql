DELIMITER ;

CREATE TABLE IF NOT EXISTS `custom_types` (
  `id` varchar(100) NOT NULL,
  `xtype_long_classic` varchar(100) DEFAULT NULL,
  `xtype_long_modern` varchar(100) DEFAULT NULL,
  `extendsxtype_classic` varchar(100) DEFAULT NULL,
  `extendsxtype_modern` varchar(100) DEFAULT NULL,
  `name` varchar(100) NOT NULL,
  `vendor` varchar(50) NOT NULL,
  `description` varchar(255) DEFAULT '',
  `create_datetime` datetime DEFAULT current_timestamp(),
  `login` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`)
);


INSERT  IGNORE INTO `custom_types` VALUES
('#name','widget.xcheckbox','widget.textarea','Ext.form.field.Checkbox','Ext.field.Text','Ext.tualo.form.field.XCheckbox','Tualo','','2023-08-03 15:34:06',NULL),
('Ext.tualo.form.field.DSFields','widget.tualodsfields','widget.textarea','Ext.form.field.ComboBox','Ext.field.Text','Ext.tualo.form.field.DSFields','Tualo','','2023-08-03 15:24:54',NULL),
('Ext.tualo.form.field.DSTrigger','widget.tualodstrigger','widget.textarea','Ext.form.field.ComboBox','Ext.field.Text','Ext.tualo.form.field.DSTrigger','Tualo','','2023-08-03 16:55:32',NULL),
('Ext.tualo.form.field.ListSelection','widget.tualolistselection','widget.textarea','Ext.form.field.ComboBox','Ext.field.Text','Ext.tualo.form.field.ListSelection','Tualo','','2023-08-03 15:24:54',NULL),
('Tualo.DataSets.combobox.farben.Rgb','widget.combobox_farben_rgb','widget.textarea','Tualo.cmp.cmp_ds.field.ComboBoxDS','Ext.field.Text','Tualo.DataSets.combobox.farben.Rgb','Tualo','','2023-08-03 15:34:06',NULL),
('Tualo.from.fields.DataFieldComboBox','widget.tualo_datafield_combobox','widget.textfield','Ext.form.field.ComboBox','Ext.field.Text','Tualo.from.fields.DataFieldComboBox','Tualo','','2023-08-03 15:34:06',NULL),
('Tualo.grid.column.DatetimeDisplayColumn','widget.tualodatetimedisplaycolumn','widget.tualodatetimedisplaycolumn','Ext.grid.column.Date','Ext.grid.column.Date','Tualo.grid.column.DatetimeDisplayColumn','Tualo','','2023-08-03 15:24:54',NULL),
('Tualo.grid.column.DEDateDisplayColumn','widget.tualodedatedisplaycolumn','widget.tualodedatedisplaycolumn','Ext.grid.column.Date','Ext.grid.column.Date','Tualo.grid.column.DEDateDisplayColumn','Tualo','','2023-08-03 15:24:54',NULL),
('Tualo.grid.column.MoneyColumn2','widget.moneycolumn2','widget.moneycolumn2','Ext.grid.column.Number','Ext.grid.column.Number','Tualo.grid.column.MoneyColumn2','Tualo','','2023-08-03 15:24:54',NULL),
('Tualo.grid.column.MoneyColumn5','widget.moneycolumn5','widget.moneycolumn5','Ext.grid.column.Number','Ext.grid.column.Number','Tualo.grid.column.MoneyColumn5','Tualo','','2023-08-03 15:24:54',NULL),
('Tualo.grid.column.Number0','widget.tualocolumnnumber0','widget.tualocolumnnumber0','Ext.grid.column.Number','Ext.grid.column.Number','Tualo.grid.column.Number0','Tualo','','2023-08-03 15:24:54',NULL),
('Tualo.grid.column.Number2','widget.tualocolumnnumber2','widget.tualocolumnnumber2','Ext.grid.column.Number','Ext.grid.column.Number','Tualo.grid.column.Number2','Tualo','','2023-08-03 15:24:54',NULL),
('Tualo.grid.column.Number5','widget.tualocolumnnumber5','widget.tualocolumnnumber5','Ext.grid.column.Number','Ext.grid.column.Number','Tualo.grid.column.Number5','Tualo','','2023-08-03 15:24:54',NULL);
