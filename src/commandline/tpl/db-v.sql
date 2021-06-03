


-- SOURCE FILE: ./src//000-ddl/000.ddl.sql 
call addfieldifnotexists('ds_column_form_label','fieldgroup','varchar(36) default ""');

create table if not exists `virtual_table_jointypes`(
    id varchar(25) not null primary key
);
insert into `virtual_table_jointypes`(`id`) values ('join'),('left join') on duplicate key update id = values(id);

create table if not exists `virtual_table`(

    `alias_name` varchar(128) not null primary key,
    `table_name` varchar(128) not null,

    constraint `fk_virtual_table_table_name`
    foreign key (`table_name`)
    references `ds`(`table_name`)
    on delete cascade
    on update cascade
);


create table if not exists `virtual_table_join`(

    `alias_name` varchar(128) not null,
    `join_table` varchar(128) not null,

    primary key(`alias_name`,`join_table`),
    `join_type` varchar(25) not null,

    constraint `fk_virtual_table_join_alias_name`
    foreign key (`alias_name`)
    references `virtual_table`(`alias_name`)
    on delete cascade
    on update cascade,

    constraint `fk_virtual_table_join_join_table`
    foreign key (`join_table`)
    references `virtual_table`(`alias_name`)
    on delete cascade
    on update cascade,

    constraint `fk_virtual_table_join_join_type`
    foreign key (`join_type`)
    references `virtual_table_jointypes`(`id`)
    on delete cascade
    on update cascade

);




create table if not exists `virtual_table_fields`(

    `alias_table_name` varchar(128) not null,
    `base_table_name`  varchar(128) not null,
    `column_name` varchar(128) not null,
    `column_alias`  varchar(128) not null,
    key `idx`(`alias_table_name`),

    primary key(`alias_table_name`,`base_table_name`,`column_name`),
    `active` tinyint default 0,

    constraint `fk_virtual_table_fields_alias_table_name`
    foreign key (`alias_table_name`)
    references `virtual_table`(`alias_name`)
    on delete cascade
    on update cascade

);

create or replace view `view_readtable_virtual_table_fields_base` as
select 
	alias_name,
    null join_table,
    null join_type,
    table_name
from  
    `virtual_table` 

union

select 
	virtual_table.alias_name,
    join_table,
    join_type,
    table_name
from  
    `virtual_table_join`
    join `virtual_table` on (`virtual_table_join`.`alias_name` = `virtual_table`.`alias_name`)
;

create or replace view `view_readtable_virtual_table_fields` as 
select
    `view_readtable_virtual_table_fields_base`.`alias_name` as `alias_table_name`,
    `ds_column`.`column_name`,
    `ds_column`.`table_name` as `base_table_name`,
    ifnull(`virtual_table_fields`.`active`,0) `active`,
    ifnull(`virtual_table_fields`.`column_alias`,`ds_column`.`column_name`) `column_alias`
from  
    `view_readtable_virtual_table_fields_base`
    join `ds_column` on (`ds_column`.`table_name`= `view_readtable_virtual_table_fields_base`.`table_name`)
    left join `virtual_table_fields` 
        on (`ds_column`.`column_name`,`ds_column`.`table_name`) = (`virtual_table_fields`.`column_name`,`virtual_table_fields`.`base_table_name`)
;

create table if not exists `virtual_table_vfields`(

    `alias_table_name` varchar(128) not null,
    `column_name` varchar(128) not null,
    `column_alias`  varchar(128) not null,

    primary key(`alias_table_name`,`column_name`),
    `active` tinyint default 0,
    `statement` longtext,

    constraint `fk_virtual_table_vfields_alias_table_name`
    foreign key (`alias_table_name`)
    references `virtual_table`(`alias_name`)
    on delete cascade
    on update cascade

);




create table if not exists `virtual_table_join_on`(

    `alias_name` varchar(128) not null,
    `join_table` varchar(128) not null,
    `alias_column_name`  varchar(128) not null,
    `join_table_column_name`  varchar(128) not null,
    `active` tinyint default 0,
    primary key(`alias_name`,`join_table`,`alias_column_name`,`join_table_column_name`),

    constraint `fk_virtual_table_join_on_alias_name_join_table`
    foreign key (`alias_name`,`join_table`)
    references `virtual_table_join`(`alias_name`,`join_table`)
    on delete cascade
    on update cascade
        
);

create or replace view view_readtable_virtual_table_join_on as 

select 
    ifnull(virtual_table_join_on.`alias_name`,x.`alias_name`) `alias_name`,
    ifnull(virtual_table_join_on.`join_table`,x.`join_table`) `join_table`,
    ifnull(virtual_table_join_on.`alias_column_name`,x.`alias_column_name`) `alias_column_name`,
    ifnull(virtual_table_join_on.`join_table_column_name`,x.`join_table_column_name`) `join_table_column_name`,
    if( ifnull(virtual_table_join_on.active, x.`active`) = 1,true,false) `active`
from 
(
select 
        virtual_table.alias_name alias_name,
        mv_referential_constraints.REFERENCED_COLUMN_NAME alias_column_name ,
        vt.alias_name join_table,
        mv_referential_constraints.COLUMN_NAME join_table_column_name,
        0 active
from 
        virtual_table
        join virtual_table_join on virtual_table.alias_name= virtual_table_join.alias_name
        join virtual_table vt on vt.alias_name = virtual_table_join.join_table
        join mv_referential_constraints 
        	on mv_referential_constraints.constraint_schema = database()
            and mv_referential_constraints.table_name = vt.table_name
            and mv_referential_constraints.referenced_table_name = virtual_table.table_name
) x 

left join  virtual_table_join_on
    on (virtual_table_join_on.`alias_name`,virtual_table_join_on.`join_table`,virtual_table_join_on.`alias_column_name`,virtual_table_join_on.`join_table_column_name`)
    = (x.`alias_name`,x.`join_table`,x.`alias_column_name`,x.`join_table_column_name`)

union

select 
     virtual_table_join_on.`alias_name` `alias_name`,
     virtual_table_join_on.`join_table` `join_table`,
     virtual_table_join_on.`alias_column_name` `alias_column_name`,
     virtual_table_join_on.`join_table_column_name`  `join_table_column_name`,
     if( virtual_table_join_on.active = 1,true,false) `active`
from 


virtual_table_join_on
left join  
(
select 
        virtual_table.alias_name alias_name,
        mv_referential_constraints.REFERENCED_COLUMN_NAME alias_column_name ,
        vt.alias_name join_table,
        mv_referential_constraints.COLUMN_NAME join_table_column_name,
        0 active
from 
        virtual_table
        join virtual_table_join on virtual_table.alias_name= virtual_table_join.alias_name
        join virtual_table vt on vt.alias_name = virtual_table_join.join_table
        join mv_referential_constraints 
        	on mv_referential_constraints.constraint_schema = database()
            and mv_referential_constraints.table_name = vt.table_name
) x 
    on (virtual_table_join_on.`alias_name`,virtual_table_join_on.`join_table`,virtual_table_join_on.`alias_column_name`,virtual_table_join_on.`join_table_column_name`)
    = (x.`alias_name`,x.`join_table`,x.`alias_column_name`,x.`join_table_column_name`)
where 
x.`alias_name` is null
;

-- SOURCE FILE: ./src//000-ddl/001.ddl-ui.sql 
-- BEGIN DS virtual_table
-- NAME: Virtuelle Tabellen

insert into `ds`
                    (`table_name`)
                    values
                    ('virtual_table')
                    on duplicate key update `table_name`=values(`table_name`);
update `ds` set `title`='Virtuelle Tabellen',`reorderfield`='',`use_history`='0',`searchfield`='alias_name',`displayfield`='alias_name',`sortfield`='alias_name',`searchany`='1',`hint`='',`overview_tpl`='',`sync_table`='',`writetable`='',`globalsearch`='0',`listselectionmodel`='tualomultirowmodel',`sync_view`='',`syncable`='0',`cssstyle`='',`alternativeformxtype`='',`read_table`='',`class_name`='VTables',`special_add_panel`='',`existsreal`='1',`character_set_name`='',`read_filter`='',`listxtypeprefix`='listview',`phpexporter`='XlsxWriter',`phpexporterfilename`='',`combined`='0',`default_pagesize`='100',`allowForm`= 1 ,`listviewbaseclass`='Tualo.DataSets.ListView',`showactionbtn`='1' where `table_name`='virtual_table';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('virtual_table','alias_name')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='1',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='PRI',`column_type`='varchar(128)',`character_maximum_length`='128',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='virtual_table' and `column_name`='alias_name';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('virtual_table','table_name')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='MUL',`column_type`='varchar(128)',`character_maximum_length`='128',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='virtual_table' and `column_name`='table_name';
insert into `ds_access`
                    (`role`,`table_name`)
                    values
                    ('administration','virtual_table')
                    on duplicate key update `role`=values(`role`),`table_name`=values(`table_name`);
update `ds_access` set `read`='1',`write`='1',`delete`='1',`append`='1',`existsreal`='0' where `role`='administration' and `table_name`='virtual_table';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('virtual_table','alias_name','DE','Aliasname','Allgemein/Angaben')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='textfield',`position`='0',`hidden`='0',`active`='1',`allowempty`='0',`fieldgroup`='' where `table_name`='virtual_table' and `column_name`='alias_name' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('virtual_table','table_name','DE','Tabelle','Allgemein/Angaben')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='combobox_ds_tabelle',`position`='999',`hidden`='0',`active`='1',`allowempty`='0',`fieldgroup`='' where `table_name`='virtual_table' and `column_name`='table_name' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('virtual_table','alias_name','DE','Aliasname')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='0',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='virtual_table' and `column_name`='alias_name' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('virtual_table','table_name','DE','table_name')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='999',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='',`align`='',`listfiltertype`='',`hint`='NULL' where `table_name`='virtual_table' and `column_name`='table_name' and `language`='DE';
insert into `ds_dropdownfields`
                    (`table_name`,`name`)
                    values
                    ('virtual_table','alias_name')
                    on duplicate key update `table_name`=values(`table_name`),`name`=values(`name`);
update `ds_dropdownfields` set `idfield`='alias_name',`displayfield`='table_name',`filterconfig`='' where `table_name`='virtual_table' and `name`='alias_name';
insert into `ds_nm_tables`
                    (`table_name`,`constraint_name`,`referenced_constraint_name`,`language`,`label`)
                    values
                    ('virtual_table','fk_virtual_table_join_alias_name','fk_virtual_table_join_join_table','DE','')
                    on duplicate key update `table_name`=values(`table_name`),`constraint_name`=values(`constraint_name`),`referenced_constraint_name`=values(`referenced_constraint_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_nm_tables` set `referenced_table_name`='virtual_table',`intermedia_table_name`='virtual_table_join',`position`='99',`hidden`='0',`active`='0',`table_name_json`='{\"virtual_table_join__alias_name\":\"virtual_table__alias_name\"}',`referenced_table_json`='{\"virtual_table_join__join_table\":\"virtual_table__alias_name\"}' where `table_name`='virtual_table' and `constraint_name`='fk_virtual_table_join_alias_name' and `referenced_constraint_name`='fk_virtual_table_join_join_table';
insert into `ds_nm_tables`
                    (`table_name`,`constraint_name`,`referenced_constraint_name`,`language`,`label`)
                    values
                    ('virtual_table','fk_virtual_table_join_alias_name','fk_virtual_table_join_join_type','DE','')
                    on duplicate key update `table_name`=values(`table_name`),`constraint_name`=values(`constraint_name`),`referenced_constraint_name`=values(`referenced_constraint_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_nm_tables` set `referenced_table_name`='virtual_table_jointypes',`intermedia_table_name`='virtual_table_join',`position`='99',`hidden`='0',`active`='0',`table_name_json`='{\"virtual_table_join__alias_name\":\"virtual_table__alias_name\"}',`referenced_table_json`='{\"virtual_table_join__join_type\":\"virtual_table_jointypes__id\"}' where `table_name`='virtual_table' and `constraint_name`='fk_virtual_table_join_alias_name' and `referenced_constraint_name`='fk_virtual_table_join_join_type';
insert into `ds_nm_tables`
                    (`table_name`,`constraint_name`,`referenced_constraint_name`,`language`,`label`)
                    values
                    ('virtual_table','fk_virtual_table_join_join_table','fk_virtual_table_join_alias_name','DE','')
                    on duplicate key update `table_name`=values(`table_name`),`constraint_name`=values(`constraint_name`),`referenced_constraint_name`=values(`referenced_constraint_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_nm_tables` set `referenced_table_name`='virtual_table',`intermedia_table_name`='virtual_table_join',`position`='99',`hidden`='0',`active`='0',`table_name_json`='{\"virtual_table_join__join_table\":\"virtual_table__alias_name\"}',`referenced_table_json`='{\"virtual_table_join__alias_name\":\"virtual_table__alias_name\"}' where `table_name`='virtual_table' and `constraint_name`='fk_virtual_table_join_join_table' and `referenced_constraint_name`='fk_virtual_table_join_alias_name';
insert into `ds_nm_tables`
                    (`table_name`,`constraint_name`,`referenced_constraint_name`,`language`,`label`)
                    values
                    ('virtual_table','fk_virtual_table_join_join_table','fk_virtual_table_join_join_type','DE','')
                    on duplicate key update `table_name`=values(`table_name`),`constraint_name`=values(`constraint_name`),`referenced_constraint_name`=values(`referenced_constraint_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_nm_tables` set `referenced_table_name`='virtual_table_jointypes',`intermedia_table_name`='virtual_table_join',`position`='99',`hidden`='0',`active`='0',`table_name_json`='{\"virtual_table_join__join_table\":\"virtual_table__alias_name\"}',`referenced_table_json`='{\"virtual_table_join__join_type\":\"virtual_table_jointypes__id\"}' where `table_name`='virtual_table' and `constraint_name`='fk_virtual_table_join_join_table' and `referenced_constraint_name`='fk_virtual_table_join_join_type';
insert into `ds_reference_tables`
                    (`table_name`,`reference_table_name`)
                    values
                    ('virtual_table','ds')
                    on duplicate key update `table_name`=values(`table_name`),`reference_table_name`=values(`reference_table_name`);
update `ds_reference_tables` set `columnsdef`='{\"virtual_table__table_name\":\"ds__table_name\"}',`constraint_name`='fk_virtual_table_table_name',`active`='0',`searchable`='0',`autosync`='1',`position`='99999',`path`='' where `table_name`='virtual_table' and `reference_table_name`='ds';
-- END DS virtual_table


-- BEGIN DS virtual_table_fields
-- NAME: Felder

insert into `ds`
                    (`table_name`)
                    values
                    ('virtual_table_fields')
                    on duplicate key update `table_name`=values(`table_name`);
update `ds` set `title`='Felder',`reorderfield`='',`use_history`='0',`searchfield`='column_name',`displayfield`='column_name',`sortfield`='column_name',`searchany`='1',`hint`='',`overview_tpl`='',`sync_table`='',`writetable`='',`globalsearch`='0',`listselectionmodel`='tualomultirowmodel',`sync_view`='',`syncable`='0',`cssstyle`='',`alternativeformxtype`='',`read_table`='',`class_name`='VTables',`special_add_panel`='',`existsreal`='1',`character_set_name`='',`read_filter`='',`listxtypeprefix`='listview',`phpexporter`='XlsxWriter',`phpexporterfilename`='',`combined`='0',`default_pagesize`='100',`allowForm`= 1 ,`listviewbaseclass`='Tualo.DataSets.ListView',`showactionbtn`='1' where `table_name`='virtual_table_fields';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('virtual_table_fields','active')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='YES',`is_referenced`='',`writeable`='1',`note`='',`data_type`='tinyint',`column_key`='',`column_type`='tinyint(4)',`character_maximum_length`='0',`numeric_precision`='3',`numeric_scale`='0',`character_set_name`='',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='virtual_table_fields' and `column_name`='active';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('virtual_table_fields','alias_table_name')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='1',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='PRI',`column_type`='varchar(128)',`character_maximum_length`='128',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='virtual_table_fields' and `column_name`='alias_table_name';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('virtual_table_fields','column_name')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(128)',`character_maximum_length`='128',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='virtual_table_fields' and `column_name`='column_name';
insert into `ds_access`
                    (`role`,`table_name`)
                    values
                    ('administration','virtual_table_fields')
                    on duplicate key update `role`=values(`role`),`table_name`=values(`table_name`);
update `ds_access` set `read`='1',`write`='1',`delete`='1',`append`='1',`existsreal`='0' where `role`='administration' and `table_name`='virtual_table_fields';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('virtual_table_fields','active','DE','aktiv','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='999',`hidden`='0',`active`='1',`allowempty`='0',`fieldgroup`='' where `table_name`='virtual_table_fields' and `column_name`='active' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('virtual_table_fields','alias_table_name','DE','Alias','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='0',`hidden`='0',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='virtual_table_fields' and `column_name`='alias_table_name' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('virtual_table_fields','column_name','DE','Spalte','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='999',`hidden`='0',`active`='1',`allowempty`='0',`fieldgroup`='' where `table_name`='virtual_table_fields' and `column_name`='column_name' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('virtual_table_fields','active','DE','aktiv')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='checkcolumn',`editor`='',`position`='999',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='',`align`='',`listfiltertype`='',`hint`='NULL' where `table_name`='virtual_table_fields' and `column_name`='active' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('virtual_table_fields','alias_table_name','DE','Alias')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='0',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='virtual_table_fields' and `column_name`='alias_table_name' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('virtual_table_fields','column_name','DE','Spalte')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='999',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='virtual_table_fields' and `column_name`='column_name' and `language`='DE';
insert into `ds_reference_tables`
                    (`table_name`,`reference_table_name`)
                    values
                    ('virtual_table_fields','virtual_table')
                    on duplicate key update `table_name`=values(`table_name`),`reference_table_name`=values(`reference_table_name`);
update `ds_reference_tables` set `columnsdef`='{\"virtual_table_fields__alias_table_name\":\"virtual_table__alias_name\"}',`constraint_name`='fk_virtual_table_fields_alias_table_name',`active`='1',`searchable`='0',`autosync`='1',`position`='99999',`path`='\'\'' where `table_name`='virtual_table_fields' and `reference_table_name`='virtual_table';
-- END DS virtual_table_fields


-- BEGIN DS virtual_table_join
-- NAME: Verbundene Tabellen

insert into `ds`
                    (`table_name`)
                    values
                    ('virtual_table_join')
                    on duplicate key update `table_name`=values(`table_name`);
update `ds` set `title`='Verbundene Tabellen',`reorderfield`='',`use_history`='0',`searchfield`='join_table',`displayfield`='join_table',`sortfield`='join_table',`searchany`='1',`hint`='',`overview_tpl`='',`sync_table`='',`writetable`='',`globalsearch`='0',`listselectionmodel`='tualomultirowmodel',`sync_view`='',`syncable`='0',`cssstyle`='',`alternativeformxtype`='',`read_table`='',`class_name`='VTables',`special_add_panel`='',`existsreal`='1',`character_set_name`='',`read_filter`='',`listxtypeprefix`='listview',`phpexporter`='XlsxWriter',`phpexporterfilename`='',`combined`='0',`default_pagesize`='100',`allowForm`= 1 ,`listviewbaseclass`='Tualo.DataSets.ListView',`showactionbtn`='1' where `table_name`='virtual_table_join';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('virtual_table_join','alias_name')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='1',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='PRI',`column_type`='varchar(128)',`character_maximum_length`='128',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='virtual_table_join' and `column_name`='alias_name';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('virtual_table_join','join_table')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='1',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='PRI',`column_type`='varchar(128)',`character_maximum_length`='128',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='virtual_table_join' and `column_name`='join_table';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('virtual_table_join','join_type')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='MUL',`column_type`='varchar(25)',`character_maximum_length`='25',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='virtual_table_join' and `column_name`='join_type';
insert into `ds_access`
                    (`role`,`table_name`)
                    values
                    ('administration','virtual_table_join')
                    on duplicate key update `role`=values(`role`),`table_name`=values(`table_name`);
update `ds_access` set `read`='1',`write`='1',`delete`='1',`append`='1',`existsreal`='0' where `role`='administration' and `table_name`='virtual_table_join';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('virtual_table_join','alias_name','DE','Alias','Allgemein/Angaben')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='0',`hidden`='0',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='virtual_table_join' and `column_name`='alias_name' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('virtual_table_join','join_table','DE','verbundene Tabelle','Allgemein/Angaben')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='combobox_ds_tabelle',`position`='0',`hidden`='0',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='virtual_table_join' and `column_name`='join_table' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('virtual_table_join','join_type','DE','Verbundtyp','Allgemein/Angaben')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='combobox_virtual_table_jointypes_id',`position`='999',`hidden`='0',`active`='1',`allowempty`='0',`fieldgroup`='' where `table_name`='virtual_table_join' and `column_name`='join_type' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('virtual_table_join','alias_name','DE','Alias')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='0',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='virtual_table_join' and `column_name`='alias_name' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('virtual_table_join','join_table','DE','verbundene Tabelle')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='column_ds_tabelle',`editor`='',`position`='0',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='virtual_table_join' and `column_name`='join_table' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('virtual_table_join','join_type','DE','Verbundtyp')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='column_virtual_table_jointypes_id',`editor`='',`position`='999',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='virtual_table_join' and `column_name`='join_type' and `language`='DE';
insert into `ds_reference_tables`
                    (`table_name`,`reference_table_name`)
                    values
                    ('virtual_table_join','virtual_table')
                    on duplicate key update `table_name`=values(`table_name`),`reference_table_name`=values(`reference_table_name`);
update `ds_reference_tables` set `columnsdef`='{\"virtual_table_join__join_table\":\"virtual_table__alias_name\"}',`constraint_name`='fk_virtual_table_join_join_table',`active`='1',`searchable`='0',`autosync`='1',`position`='99999',`path`='\'\'' where `table_name`='virtual_table_join' and `reference_table_name`='virtual_table';
insert into `ds_reference_tables`
                    (`table_name`,`reference_table_name`)
                    values
                    ('virtual_table_join','virtual_table_jointypes')
                    on duplicate key update `table_name`=values(`table_name`),`reference_table_name`=values(`reference_table_name`);
update `ds_reference_tables` set `columnsdef`='{\"virtual_table_join__join_type\":\"virtual_table_jointypes__id\"}',`constraint_name`='fk_virtual_table_join_join_type',`active`='0',`searchable`='0',`autosync`='1',`position`='99999',`path`='' where `table_name`='virtual_table_join' and `reference_table_name`='virtual_table_jointypes';
-- END DS virtual_table_join


-- BEGIN DS virtual_table_jointypes
-- NAME: Join-Typen

insert into `ds`
                    (`table_name`)
                    values
                    ('virtual_table_jointypes')
                    on duplicate key update `table_name`=values(`table_name`);
update `ds` set `title`='Join-Typen',`reorderfield`='',`use_history`='0',`searchfield`='id',`displayfield`='id',`sortfield`='id',`searchany`='1',`hint`='',`overview_tpl`='',`sync_table`='',`writetable`='',`globalsearch`='0',`listselectionmodel`='cellmodel',`sync_view`='',`syncable`='0',`cssstyle`='',`alternativeformxtype`='',`read_table`='',`class_name`='VTables',`special_add_panel`='',`existsreal`='1',`character_set_name`='',`read_filter`='',`listxtypeprefix`='listview',`phpexporter`='XlsxWriter',`phpexporterfilename`='',`combined`='0',`default_pagesize`='100',`allowForm`= 1 ,`listviewbaseclass`='Tualo.DataSets.ListView',`showactionbtn`='1' where `table_name`='virtual_table_jointypes';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('virtual_table_jointypes','id')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='1',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='PRI',`column_type`='varchar(25)',`character_maximum_length`='25',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='virtual_table_jointypes' and `column_name`='id';
insert into `ds_access`
                    (`role`,`table_name`)
                    values
                    ('administration','virtual_table_jointypes')
                    on duplicate key update `role`=values(`role`),`table_name`=values(`table_name`);
update `ds_access` set `read`='1',`write`='1',`delete`='1',`append`='1',`existsreal`='0' where `role`='administration' and `table_name`='virtual_table_jointypes';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('virtual_table_jointypes','id','DE','Typ','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='textfield',`position`='0',`hidden`='0',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='virtual_table_jointypes' and `column_name`='id' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('virtual_table_jointypes','id','DE','Typ')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='0',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='',`align`='',`listfiltertype`='',`hint`='NULL' where `table_name`='virtual_table_jointypes' and `column_name`='id' and `language`='DE';
insert into `ds_dropdownfields`
                    (`table_name`,`name`)
                    values
                    ('virtual_table_jointypes','id')
                    on duplicate key update `table_name`=values(`table_name`),`name`=values(`name`);
update `ds_dropdownfields` set `idfield`='id',`displayfield`='id',`filterconfig`='' where `table_name`='virtual_table_jointypes' and `name`='id';
insert into `ds_nm_tables`
                    (`table_name`,`constraint_name`,`referenced_constraint_name`,`language`,`label`)
                    values
                    ('virtual_table_jointypes','fk_virtual_table_join_join_type','fk_virtual_table_join_alias_name','DE','')
                    on duplicate key update `table_name`=values(`table_name`),`constraint_name`=values(`constraint_name`),`referenced_constraint_name`=values(`referenced_constraint_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_nm_tables` set `referenced_table_name`='virtual_table',`intermedia_table_name`='virtual_table_join',`position`='99',`hidden`='0',`active`='0',`table_name_json`='{\"virtual_table_join__join_type\":\"virtual_table_jointypes__id\"}',`referenced_table_json`='{\"virtual_table_join__alias_name\":\"virtual_table__alias_name\"}' where `table_name`='virtual_table_jointypes' and `constraint_name`='fk_virtual_table_join_join_type' and `referenced_constraint_name`='fk_virtual_table_join_alias_name';
insert into `ds_nm_tables`
                    (`table_name`,`constraint_name`,`referenced_constraint_name`,`language`,`label`)
                    values
                    ('virtual_table_jointypes','fk_virtual_table_join_join_type','fk_virtual_table_join_join_table','DE','')
                    on duplicate key update `table_name`=values(`table_name`),`constraint_name`=values(`constraint_name`),`referenced_constraint_name`=values(`referenced_constraint_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_nm_tables` set `referenced_table_name`='virtual_table',`intermedia_table_name`='virtual_table_join',`position`='99',`hidden`='0',`active`='0',`table_name_json`='{\"virtual_table_join__join_type\":\"virtual_table_jointypes__id\"}',`referenced_table_json`='{\"virtual_table_join__join_table\":\"virtual_table__alias_name\"}' where `table_name`='virtual_table_jointypes' and `constraint_name`='fk_virtual_table_join_join_type' and `referenced_constraint_name`='fk_virtual_table_join_join_table';
-- END DS virtual_table_jointypes


-- BEGIN DS virtual_table_vfields
-- NAME: berechnete Felder

insert into `ds`
                    (`table_name`)
                    values
                    ('virtual_table_vfields')
                    on duplicate key update `table_name`=values(`table_name`);
update `ds` set `title`='berechnete Felder',`reorderfield`='',`use_history`='0',`searchfield`='column_name',`displayfield`='column_name',`sortfield`='column_name',`searchany`='1',`hint`='',`overview_tpl`='',`sync_table`='',`writetable`='',`globalsearch`='0',`listselectionmodel`='cellmodel',`sync_view`='',`syncable`='0',`cssstyle`='',`alternativeformxtype`='',`read_table`='',`class_name`='VTables',`special_add_panel`='',`existsreal`='1',`character_set_name`='',`read_filter`='',`listxtypeprefix`='listview',`phpexporter`='XlsxWriter',`phpexporterfilename`='',`combined`='0',`default_pagesize`='100',`allowForm`= 1 ,`listviewbaseclass`='Tualo.DataSets.ListView',`showactionbtn`='1' where `table_name`='virtual_table_vfields';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('virtual_table_vfields','active')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='YES',`is_referenced`='',`writeable`='1',`note`='',`data_type`='tinyint',`column_key`='',`column_type`='tinyint(4)',`character_maximum_length`='0',`numeric_precision`='3',`numeric_scale`='0',`character_set_name`='',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='virtual_table_vfields' and `column_name`='active';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('virtual_table_vfields','alias_table_name')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='1',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='PRI',`column_type`='varchar(128)',`character_maximum_length`='128',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='virtual_table_vfields' and `column_name`='alias_table_name';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('virtual_table_vfields','column_name')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(128)',`character_maximum_length`='128',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='virtual_table_vfields' and `column_name`='column_name';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('virtual_table_vfields','statement')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='YES',`is_referenced`='',`writeable`='1',`note`='',`data_type`='longtext',`column_key`='',`column_type`='longtext',`character_maximum_length`='4294967295',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='virtual_table_vfields' and `column_name`='statement';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('virtual_table_vfields','active','DE','Aktiv','Allgemein/Angaben')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='checkbox',`position`='1',`hidden`='0',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='virtual_table_vfields' and `column_name`='active' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('virtual_table_vfields','alias_table_name','DE','Alias','Allgemein/Angaben')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='0',`hidden`='0',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='virtual_table_vfields' and `column_name`='alias_table_name' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('virtual_table_vfields','column_name','DE','Spalte','Allgemein/Angaben')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='textfield',`position`='2',`hidden`='0',`active`='1',`allowempty`='0',`fieldgroup`='' where `table_name`='virtual_table_vfields' and `column_name`='column_name' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('virtual_table_vfields','statement','DE','SQL-Statement','Allgemein/Angaben')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='textarea',`position`='3',`hidden`='0',`active`='1',`allowempty`='0',`fieldgroup`='' where `table_name`='virtual_table_vfields' and `column_name`='statement' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('virtual_table_vfields','active','DE','Aktiv')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='1',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='virtual_table_vfields' and `column_name`='active' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('virtual_table_vfields','alias_table_name','DE','Alias')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='0',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='virtual_table_vfields' and `column_name`='alias_table_name' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('virtual_table_vfields','column_name','DE','Spalte')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='2',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='virtual_table_vfields' and `column_name`='column_name' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('virtual_table_vfields','statement','DE','SQL-Statement')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='3',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='virtual_table_vfields' and `column_name`='statement' and `language`='DE';
insert into `ds_reference_tables`
                    (`table_name`,`reference_table_name`)
                    values
                    ('virtual_table_vfields','virtual_table')
                    on duplicate key update `table_name`=values(`table_name`),`reference_table_name`=values(`reference_table_name`);
update `ds_reference_tables` set `columnsdef`='{\"virtual_table_vfields__alias_table_name\":\"virtual_table__alias_name\"}',`constraint_name`='fk_virtual_table_vfields_alias_table_name',`active`='1',`searchable`='0',`autosync`='1',`position`='99999',`path`='\'\'' where `table_name`='virtual_table_vfields' and `reference_table_name`='virtual_table';
-- END DS virtual_table_vfields



-- SOURCE FILE: ./src//000-ddl/005.virtual_table_fn.sql 

DELIMITER //

DROP FUNCTION IF EXISTS `virtual_table_join_on_fn` //
CREATE FUNCTION `virtual_table_join_on_fn`(in_alias_name varchar(128),in_join_table varchar(128))
RETURNS longtext
DETERMINISTIC
COMMENT ''
BEGIN 
    DECLARE result longtext default '';

    select
    group_concat(
    concat(
        '`',virtual_table_join_on.alias_name,'`','.','`',virtual_table_join_on.alias_column_name,'`',
        ' = ', 
        '`',virtual_table_join_on.join_table,'`','.','`',virtual_table_join_on.join_table_column_name,'`',
        char(10)
    )
    separator ' and '
    )
     x
    into 
        result
    from 
        `virtual_table_join_on`
    where  
        `virtual_table_join_on`.`alias_name` = in_alias_name
        and `virtual_table_join_on`.`join_table` = in_join_table
        and `virtual_table_join_on`.`active` = 1;
    RETURN result;
END //


DROP FUNCTION IF EXISTS `virtual_table_fld_fn` //
CREATE FUNCTION `virtual_table_fld_fn`(in_alias_name varchar(128))
RETURNS longtext
DETERMINISTIC
COMMENT ''
BEGIN 
    DECLARE result longtext default '';

    select 
    group_concat(x separator ', ') x
    into 
    result
    from 
    (
    	select 
            concat(char(10),'',`virtual_table_vfields`.`statement`,' as `',virtual_table_vfields.column_alias,'`') x
        

    from
        virtual_table_vfields
        join 
        ( select 

                virtual_table.alias_name,
                virtual_table.table_name
                    
                from 
                    virtual_table
                where 
                    virtual_table.alias_name = in_alias_name

                union 

                select 

                    vt.alias_name,
                    vt.table_name
                    
                from 
                    virtual_table
                    join virtual_table_join on virtual_table.alias_name= virtual_table_join.alias_name
                    join virtual_table vt on vt.alias_name = virtual_table_join.join_table
                    
                where 
                    virtual_table.alias_name = in_alias_name
        ) x on virtual_table_vfields.active=1 and virtual_table_vfields.alias_table_name  = x.alias_name

        left join ds_column on
            ds_column.table_name = x.table_name
            and virtual_table_vfields.column_name = ds_column.column_name
            and ds_column.existsreal=1
         having x is not null

       union
       
       
       select 
            concat(char(10),'',virtual_table_fields.alias_table_name,'.',`virtual_table_fields`.`column_name`,' as `',ifnull( virtual_table_fields.column_alias,virtual_table_fields.column_name),'`') x
        

    from
        virtual_table_fields
        join 
        ( select 

                virtual_table.alias_name,
                virtual_table.table_name
                    
                from 
                    virtual_table
                where 
                    virtual_table.alias_name = in_alias_name

                union 

                select 

                    vt.alias_name,
                    vt.table_name
                    
                from 
                    virtual_table
                    join virtual_table_join on virtual_table.alias_name= virtual_table_join.alias_name
                    join virtual_table vt on vt.alias_name = virtual_table_join.join_table
                    
                where 
                    virtual_table.alias_name = in_alias_name
        ) x on virtual_table_fields.active=1 and virtual_table_fields.alias_table_name  = x.alias_name

         join ds_column on
            ds_column.table_name = virtual_table_fields.base_table_name
            and virtual_table_fields.column_name = ds_column.column_name
            and ds_column.existsreal=1
         having x is not null
    ) y
    ;

    RETURN result;
END //



DROP FUNCTION IF EXISTS `virtual_table_fn` //
CREATE FUNCTION `virtual_table_fn`(in_table_name varchar(128))
RETURNS longtext
DETERMINISTIC
COMMENT ''
BEGIN 
    DECLARE result longtext default '';
    DECLARE columns  longtext default '';
    DECLARE tbls  longtext default '';

    set columns = (select  virtual_table_fld_fn(in_table_name) x );

    select 
    group_concat( x separator '  ')
    into 
    tbls
    from (
        select 

            concat(
                '`',virtual_table.table_name,'`',' as ', '`',virtual_table.alias_name,'`',
            char(10)
        ) x
            
        from 
            virtual_table
        where 
            virtual_table.alias_name = in_table_name

        union 

        select 

            concat(virtual_table_join.join_type,' ','`',vt.table_name,'`',' as ', '`',vt.alias_name,'`',
            char(10),
            ' on ', virtual_table_join_on_fn(in_table_name,vt.alias_name),
            char(10)) x
            
        from 
            virtual_table
            join virtual_table_join on virtual_table.alias_name= virtual_table_join.alias_name
            join virtual_table vt on vt.alias_name = virtual_table_join.join_table
            
        where 
            virtual_table.alias_name = in_table_name

    ) y;

    SET result = concat(
        'select ',
        columns,
        ' from ',
        tbls -- ,
        -- ' group by '
    );


    RETURN result;
END //

select virtual_table_fn('view_blg_list_fa') s //
