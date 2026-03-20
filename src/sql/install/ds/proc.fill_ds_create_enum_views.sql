DELIMITER //

CREATE OR REPLACE PROCEDURE `fill_ds_create_enum_views`( in use_table_name varchar(128) )
    MODIFIES SQL DATA
    COMMENT '
# fill_ds_create_enum_views

Erzeugt fuer alle `enum`-Spalten einer angegebenen Tabelle automatisch lesbare
Datasets-Views samt zugehoeriger Metadaten fuer das Tualo-DS-System.

## Parameter

- `use_table_name`: Name der Tabelle, deren `enum`-Spalten verarbeitet werden sollen.

## Ablauf

1. Sucht in `ds_column` alle Spalten der angegebenen Tabelle mit `data_type = \'enum\'`.
2. Erstellt pro Treffer eine View im Format `ds_enum_view_<table>_<column>`.
3. Wandelt den `enum(...)`-Definitionstext aus `ds_column.column_type` in ein JSON-Array um.
4. Zerlegt dieses JSON per `json_table(...)` in die Spalten `id` und `name`.
5. Registriert die neue View in den DS-Metadaten-Tabellen, damit sie in Listen,
   Formularen, Dropdowns und Berechtigungen verwendet werden kann.
6. Hinterlegt fuer die urspruengliche Tabellen-Spalte passende List- und Formularfelder,
   die auf die generierte Enum-View zeigen.

## Seiteneffekte

- `create or replace view` fuer jede gefundene Enum-Spalte.
- `insert` bzw. `insert ignore` in Tabellen wie `ds`, `ds_column`,
  `ds_column_list_label`, `ds_column_form_label`, `ds_dropdownfields` und `ds_access`.

## Hinweis

Die Procedure ist nicht rein lesend: sie baut Views neu auf und schreibt mehrfach in
Metadaten-Tabellen. Mehrfaches Ausfuehren ist fuer viele Inserts ueber `insert ignore`
oder `on duplicate key update` abgefedert.    
    '
BEGIN
    select * from ds_column where data_type = 'enum' and table_name=use_table_name;
    for rec in (
        select * from ds_column where data_type = 'enum' and table_name=use_table_name
    ) do

    set @new_view = concat('ds_enum_view_',rec.table_name,'_',rec.column_name);
    SET @sql=concat('
        create or replace view ds_enum_view_',rec.table_name,'_',rec.column_name,' as
        with x as (
            select 
                column_type t 
            from 
                ds_column 
            where data_type = \'enum\' and table_name=',quote(rec.table_name),' and column_name=',quote(rec.column_name),'
        ),
        y as (
            select 
                replace( replace( replace(t,"\'",\'"\'), "enum(", "[") , ")" , "]") y
            from x
        ), 
        z as (
            select y.y z,json_valid(y.y) x from y
        )

        select
            jt.name,
            jt.id
        from z
        join 
        json_table(z.z, \'$[*]\' 
        COLUMNS(
            id for ordinality, 
        name  VARCHAR(255) path \'$\' ) 
        ) AS jt
    ');



    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;


    set @sql=concat("INSERT INTO `ds` (`allowform`,`autosave`,`base_store_class`,`class_name`,`combined`,`default_pagesize`,`displayfield`,`existsreal`,`globalsearch`,`listselectionmodel`,`listviewbaseclass`,`modelbaseclass`,`phpexporter`,`phpexporterfilename`,`searchany`,`searchfield`,`showactionbtn`,`sortdirection`,`sortfield`,`syncable`,`table_name`,`title`,`use_history`,`use_insert_for_update`) VALUES ('1','0','Tualo.DataSets.data.Store','Datenstamm','0','1000','name','1','0','tualomultirowmodel','Tualo.DataSets.ListView','Tualo.DataSets.model.Basic','XlsxWriter','ds_enum_view_todo_item_status {DATE} {TIME}','1','name','1','ASC','name','0','ds_enum_view_todo_item_status','Enums-View: ds_enum_view_todo_item_status','0','0') ON DUPLICATE KEY UPDATE `allowform`=values(`allowform`),`autosave`=values(`autosave`),`base_store_class`=values(`base_store_class`),`class_name`=values(`class_name`),`combined`=values(`combined`),`default_pagesize`=values(`default_pagesize`),`displayfield`=values(`displayfield`),`existsreal`=values(`existsreal`),`globalsearch`=values(`globalsearch`),`listselectionmodel`=values(`listselectionmodel`),`listviewbaseclass`=values(`listviewbaseclass`),`modelbaseclass`=values(`modelbaseclass`),`phpexporter`=values(`phpexporter`),`phpexporterfilename`=values(`phpexporterfilename`),`searchany`=values(`searchany`),`searchfield`=values(`searchfield`),`showactionbtn`=values(`showactionbtn`),`sortdirection`=values(`sortdirection`),`sortfield`=values(`sortfield`),`syncable`=values(`syncable`),`table_name`=values(`table_name`),`title`=values(`title`),`use_history`=values(`use_history`),`use_insert_for_update`=values(`use_insert_for_update`)");
    set @sql=replace(@sql,'ds_enum_view_todo_item_status',@new_view);
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    set @sql=concat("INSERT IGNORE INTO `ds_column` (`character_maximum_length`,`column_key`,`column_name`,`column_type`,`data_type`,`default_max_value`,`default_min_value`,`deferedload`,`existsreal`,`fieldtype`,`is_generated`,`is_nullable`,`is_primary`,`numeric_precision`,`numeric_scale`,`privileges`,`syncable`,`table_name`,`writeable`) VALUES ('0','','id','int(11)','int','0','0','0','1','','NEVER','YES','1','10','0','select,insert,update,references','0','ds_enum_view_todo_item_status','1') ");
    set @sql=replace(@sql,'ds_enum_view_todo_item_status',@new_view);
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    set @sql=concat("INSERT IGNORE INTO `ds_column` (`character_maximum_length`,`character_set_name`,`column_key`,`column_name`,`column_type`,`data_type`,`default_max_value`,`default_min_value`,`deferedload`,`existsreal`,`fieldtype`,`is_generated`,`is_nullable`,`is_primary`,`numeric_precision`,`numeric_scale`,`privileges`,`syncable`,`table_name`,`writeable`) VALUES ('255','utf8mb4','','name','varchar(255)','varchar','0','0','0','1','','NEVER','YES','0','0','0','select,insert,update,references','0','ds_enum_view_todo_item_status','1') ");
    set @sql=replace(@sql,'ds_enum_view_todo_item_status',@new_view);
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    set @sql=concat("INSERT IGNORE INTO `ds_column_list_label` (`active`,`align`,`column_name`,`editor`,`filterstore`,`flex`,`grouped`,`hidden`,`label`,`language`,`listfiltertype`,`position`,`renderer`,`summaryrenderer`,`summarytype`,`table_name`,`xtype`) VALUES ('1','start','id','','','1','0','0','id','DE','','0','','','','ds_enum_view_todo_item_status','gridcolumn') ");
    set @sql=replace(@sql,'ds_enum_view_todo_item_status',@new_view);
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    set @sql=concat("INSERT IGNORE INTO `ds_column_list_label` (`active`,`align`,`column_name`,`editor`,`filterstore`,`flex`,`grouped`,`hidden`,`label`,`language`,`listfiltertype`,`position`,`renderer`,`summaryrenderer`,`summarytype`,`table_name`,`xtype`) VALUES ('1','start','name','','','1','0','0','name','DE','','1','','','','ds_enum_view_todo_item_status','gridcolumn') ");
    set @sql=replace(@sql,'ds_enum_view_todo_item_status',@new_view);
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    set @sql=concat("INSERT IGNORE INTO `ds_column_form_label` (`active`,`allowempty`,`column_name`,`fieldgroup`,`field_path`,`flex`,`hidden`,`label`,`language`,`position`,`table_name`,`xtype`) VALUES ('1','0','id','','Allgemein/Satz','1','0','ID','DE','0','ds_enum_view_todo_item_status','displayfield') ");
    set @sql=replace(@sql,'ds_enum_view_todo_item_status',@new_view);
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    set @sql=concat("INSERT IGNORE INTO `ds_column_form_label` (`active`,`allowempty`,`column_name`,`fieldgroup`,`field_path`,`flex`,`hidden`,`label`,`language`,`position`,`table_name`,`xtype`) VALUES ('1','0','name','','Allgemein/Satz','1','0','Name','DE','1','ds_enum_view_todo_item_status','displayfield') ");
    PREPARE stmt FROM @sql;
    set @sql=replace(@sql,'ds_enum_view_todo_item_status',@new_view);
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    set @sql=concat("INSERT IGNORE INTO `ds_dropdownfields` (`displayfield`,`filterconfig`,`idfield`,`name`,`table_name`) VALUES ('name','','name','name','ds_enum_view_todo_item_status') ");
    set @sql=replace(@sql,'ds_enum_view_todo_item_status',@new_view);
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    set @sql=concat("INSERT IGNORE INTO `ds_access` (`append`,`delete`,`read`,`role`,`table_name`,`write`) VALUES ('0','0','1','_default_','ds_enum_view_todo_item_status','0') ");
    set @sql=replace(@sql,'ds_enum_view_todo_item_status',@new_view);
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    set @sql=concat("INSERT IGNORE INTO `ds_access` (`append`,`delete`,`read`,`role`,`table_name`,`write`) VALUES ('0','0','0','administration','ds_enum_view_todo_item_status','0') ");
    set @sql=replace(@sql,'ds_enum_view_todo_item_status',@new_view);
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;


    set @sql=concat("INSERT IGNORE INTO `ds_column_list_label` (`active`,`align`,`column_name`,`editor`,`filterstore`,`flex`,`grouped`,`hidden`,`label`,`language`,`listfiltertype`,`position`,`renderer`,`summaryrenderer`,`summarytype`,`table_name`,`xtype`) VALUES ('0','start','status','','','1','0','1','status','DE','ds_enum_view_todo_item_status_name_listfilter','999','','','','todo_item','gridcolumn') ");
    set @sql=replace(@sql,'ds_enum_view_todo_item_status',@new_view);
    set @sql=replace(@sql,'todo_item',rec.table_name);
    set @sql=replace(@sql,'status',rec.column_name);
    
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    set @sql=concat("INSERT IGNORE INTO `ds_column_form_label` (`active`,`allowempty`,`column_name`,`fieldgroup`,`field_path`,`flex`,`hidden`,`label`,`language`,`position`,`table_name`,`xtype`) VALUES ('0','0','status','','Allgemein','1','1','status','DE','999','todo_item','combobox_ds_enum_view_todo_item_status_name') ");
    set @sql=replace(@sql,'ds_enum_view_todo_item_status',@new_view);
    set @sql=replace(@sql,'todo_item',rec.table_name);
    set @sql=replace(@sql,'status',rec.column_name);

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
end for;
end //