DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `fill_ds_reference_table`( in use_table_name varchar(128) )
    MODIFIES SQL DATA
BEGIN




update ds_reference_tables set existsreal = 0 where (use_table_name=''  or table_name = use_table_name);

FOR record IN (select * from view_config_ds_reference_tables where (use_table_name=''  or table_name = use_table_name) ) DO
    if @debug=1 then select record.table_name,record.constraint_name; end if;

    INSERT INTO ds_reference_tables (
        table_name,
        reference_table_name,
        constraint_name,
        columnsdef,

        active,
        searchable,
        autosync,
        position,
        path,
        existsreal

    ) values (
        record.table_name,
        record.referenced_table_name,
        record.constraint_name,
        record.reference_column_names,

        0,
        0,
        0,
        999,
        '',
        1
    )
    on duplicate key 
    update 
        columnsdef=values(columnsdef),
        existsreal=values(existsreal);


END FOR;

END //
