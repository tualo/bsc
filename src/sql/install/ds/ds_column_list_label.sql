DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_column_list_label` (
  `table_name` varchar(128) NOT NULL,
  `column_name` varchar(100) NOT NULL DEFAULT '',
  `language` varchar(3) NOT NULL DEFAULT 'DE',
  `label` varchar(255) NOT NULL,
  `xtype` varchar(255) DEFAULT 'gridcolumn',
  `editor` varchar(255) DEFAULT NULL,
  `position` int(11) DEFAULT 0,
  `summaryrenderer` varchar(255) DEFAULT '',
  `renderer` varchar(255) DEFAULT '',
  `summarytype` varchar(255) DEFAULT '',
  `hidden` tinyint(4) DEFAULT 0,
  `active` tinyint(4) DEFAULT 1,
  `filterstore` varchar(255) DEFAULT '',
  `grouped` tinyint(4) DEFAULT 0,
  `flex` decimal(5,2) DEFAULT 1.00,
  `direction` varchar(5) DEFAULT 'ASC',
  `align` varchar(8) DEFAULT 'left',
  `listfiltertype` varchar(255) DEFAULT '',
  `hint` varchar(255) DEFAULT NULL,
  `width` int(11) DEFAULT 0,
  PRIMARY KEY (`table_name`,`column_name`,`language`),
  CONSTRAINT `fk_ds_column_list_label_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);

alter table ds_column_list_label add column if not exists `flex` decimal(5,2) DEFAULT 1.00;
alter table ds_column_list_label add column if not exists `direction` varchar(5) DEFAULT 'ASC';
alter table ds_column_list_label add column if not exists `align` varchar(8) DEFAULT 'left';
alter table ds_column_list_label add column if not exists `listfiltertype` varchar(255) DEFAULT '';
alter table ds_column_list_label add column if not exists `hint` varchar(255) DEFAULT NULL;
alter table ds_column_list_label add column if not exists `width` int(11) DEFAULT 0;


delimiter // 

CREATE OR REPLACE PROCEDURE `ds_listcolumn_formatter`() 
BEGIN 


  if not exists (
      select
          *
      from
          information_schema.columns
      where
          table_schema = database()
          and table_name = 'ds_column_list_label'
          and column_name = 'formatter'
  ) then


  alter table  ds_column_list_label add formatter varchar(255);

  update
      ds_column_list_label
  set
      formatter = renderer;

  update
      ds_column_list_label
  set
      renderer = null;

end if;

END // 


call ds_listcolumn_formatter() // 