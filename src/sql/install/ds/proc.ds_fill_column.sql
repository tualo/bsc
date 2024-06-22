DELIMITER //
CREATE OR REPLACE PROCEDURE `fill_ds_column`( in use_table_name varchar(128) )
    MODIFIES SQL DATA
BEGIN

update ds_column set existsreal = 0 where (use_table_name=''  or table_name = use_table_name);
update ds_column set writeable = 0 where (use_table_name=''  or table_name = use_table_name);



FOR record IN ( with cte_ds (table_name,read_table,real_table_name) as (select table_name,read_table,table_name real_table_name from ds where ds.read_table<>ds.table_name and ds.read_table<>'' and ds.read_table is not null )
select 
        cte_ds.table_name,
        cte_ds.read_table,
        ds_column.column_name,
        ds_column.default_value,
        ds_column.default_max_value,
        ds_column.default_min_value,
        ds_column.update_value,
        ds_column.is_primary,
        ds_column.syncable,
        ds_column.referenced_table,
        ds_column.referenced_column_name,
        ds_column.is_nullable,
        ds_column.is_referenced,
        0 writeable,
        ds_column.note,
        ds_column.data_type,
        ds_column.column_key,
        ds_column.column_type,
        ds_column.character_maximum_length,
        ds_column.numeric_precision,
        ds_column.numeric_scale,
        ds_column.character_set_name,
        ds_column.privileges,
        1 existsreal,
        ds_column.deferedload,
        ds_column.hint
from 
cte_ds

join ds_column
        on cte_ds.read_table = ds_column.table_name 

and (use_table_name=''  or cte_ds.table_name = use_table_name)
 ) DO

insert into ds_column (
        table_name,
        column_name,
        default_value,
        default_max_value,
        default_min_value,
        update_value,
        is_primary,
        syncable,
        referenced_table,
        referenced_column_name,
        is_nullable,
        is_referenced,
        writeable,
        note,
        data_type,
        column_key,
        column_type,
        character_maximum_length,
        numeric_precision,
        numeric_scale,
        character_set_name,
        privileges,
        existsreal,
        deferedload,
        hint
    )
    values
    (
        record.table_name,
        record.column_name,
        record.default_value,
        record.default_max_value,
        record.default_min_value,
        record.update_value,
        record.is_primary,
        record.syncable,
        record.referenced_table,
        record.referenced_column_name,
        record.is_nullable,
        record.is_referenced,
        record.writeable,
        record.note,
        record.data_type,
        record.column_key,
        record.column_type,
        record.character_maximum_length,
        record.numeric_precision,
        record.numeric_scale,
        record.character_set_name,
        record.privileges,
        record.existsreal,
        record.deferedload,
        record.hint
    )
    on duplicate key 
    update 
        `table_name`=values(`table_name`),
        `column_name`=values(`column_name`),
        `default_max_value`=values(`default_max_value`),
        `default_min_value`=values(`default_min_value`),
        `update_value`=values(`update_value`),
        `syncable`=values(`syncable`),
        `referenced_table`=values(`referenced_table`),
        `referenced_column_name`=values(`referenced_column_name`),
        `is_nullable`=values(`is_nullable`),
        `is_referenced`=values(`is_referenced`),
        `writeable`=values(`writeable`),
        `note`=values(`note`),
        `data_type`=values(`data_type`),
        `column_key`=values(`column_key`),
        `column_type`=values(`column_type`),
        `character_maximum_length`=values(`character_maximum_length`),
        `numeric_precision`=values(`numeric_precision`),
        `numeric_scale`=values(`numeric_scale`),
        `character_set_name`=values(`character_set_name`),
        `privileges`=values(`privileges`),
        `existsreal`=values(`existsreal`),
        `deferedload`=values(`deferedload`),
        `hint`=values(`hint`)
;


 END FOR;
 
FOR record IN (
    select * from view_config_ds_column where (use_table_name=''  or table_name = use_table_name) ) DO
    if @debug=1 then select record.table_name,record.column_name; end if;

    insert into ds_column (
        table_name,
        column_name,
        default_value,
        default_max_value,
        default_min_value,
        update_value,
        is_primary,
        syncable,
        referenced_table,
        referenced_column_name,
        is_nullable,
        is_referenced,
        writeable,
        note,
        data_type,
        column_key,
        column_type,
        character_maximum_length,
        numeric_precision,
        numeric_scale,
        character_set_name,
        privileges,
        existsreal,
        deferedload,
        hint
    )
    values
    (
        record.table_name,
        record.column_name,
        record.default_value,
        record.default_max_value,
        record.default_min_value,
        record.update_value,
        record.is_primary,
        record.syncable,
        record.referenced_table,
        record.referenced_column_name,
        record.is_nullable,
        record.is_referenced,
        record.writeable,
        record.note,
        record.data_type,
        record.column_key,
        record.column_type,
        record.character_maximum_length,
        record.numeric_precision,
        record.numeric_scale,
        record.character_set_name,
        record.privileges,
        record.existsreal,
        record.deferedload,
        record.hint
    )
    on duplicate key 
    update 
        `table_name`=values(`table_name`),
        `column_name`=values(`column_name`),
        `default_max_value`=values(`default_max_value`),
        `default_min_value`=values(`default_min_value`),
        `update_value`=values(`update_value`),
        `is_primary`=values(`is_primary`),
        `syncable`=values(`syncable`),
        `referenced_table`=values(`referenced_table`),
        `referenced_column_name`=values(`referenced_column_name`),
        `is_nullable`=values(`is_nullable`),
        `is_referenced`=values(`is_referenced`),
        `writeable`=values(`writeable`),
        `note`=values(`note`),
        `data_type`=values(`data_type`),
        `column_key`=values(`column_key`),
        `column_type`=values(`column_type`),
        `character_maximum_length`=values(`character_maximum_length`),
        `numeric_precision`=values(`numeric_precision`),
        `numeric_scale`=values(`numeric_scale`),
        `character_set_name`=values(`character_set_name`),
        `privileges`=values(`privileges`),
        `existsreal`=values(`existsreal`),
        `deferedload`=values(`deferedload`),
        `hint`=values(`hint`);

END FOR;


update ds_column_list_label set listfiltertype='' where listfiltertype="''";

END //