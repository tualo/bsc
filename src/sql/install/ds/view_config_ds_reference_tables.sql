DELIMITER //
create or replace view view_config_ds_reference_tables as



select
    referential_constraints.table_name,
    referential_constraints.referenced_table_name,
    referential_constraints.constraint_name,
    concat(
        '{',
        group_concat(
            concat(
                '"',
                /*
                lower(key_column_usage.table_name),
                '__',
                */
                lower(key_column_usage.column_name),
                '"',
                ':',
                '"',
                /*
                lower(key_column_usage.referenced_table_name),
                '__',
                */
                lower(key_column_usage.referenced_column_name),
                '"'
            ) separator ','
        ),
        '}'
    ) reference_column_names
from
    (
        select
            *
        from
            information_schema.referential_constraints
        where
            constraint_schema = database()
    ) referential_constraints
    join (
        select
            *
        from
            information_schema.key_column_usage
        where
            information_schema.key_column_usage.constraint_schema = database()
    ) key_column_usage on key_column_usage.table_name = referential_constraints.table_name
    and key_column_usage.constraint_name = referential_constraints.constraint_name
    and key_column_usage.constraint_schema = database()
group by
    referential_constraints.constraint_name,
    referential_constraints.referenced_table_name,
    referential_constraints.table_name
union
select
    ds_referenced_manual.table_name,
    ds_referenced_manual.referenced_table_name,
    concat(
        'manual_',
        md5(
            concat(
                ds_referenced_manual.table_name,
                '_',
                ds_referenced_manual.referenced_table_name
            )
        )
    ) constraint_name,
    concat(
        '{',
        group_concat(
            concat(
                '"',
                /*
                lower(
                    ds_referenced_manual_columns.referenced_table_name
                ),
                '__',
                */
                lower(ds_referenced_manual_columns.column_name),
                
                '"',
                ':',
                '"',
                /*
                lower(ds_referenced_manual_columns.table_name),
                '__',
                */
                lower(
                    ds_referenced_manual_columns.referenced_column_name
                ),
                '"'
            ) separator ','
        ),
        '}'
    ) reference_column_names
from
    ds_referenced_manual
    join ds_referenced_manual_columns on (
        ds_referenced_manual.table_name,
        ds_referenced_manual.referenced_table_name
    ) = (
        ds_referenced_manual_columns.table_name,
        ds_referenced_manual_columns.referenced_table_name
    )
group by
    ds_referenced_manual.referenced_table_name,
    ds_referenced_manual.table_name 

 
 // 
