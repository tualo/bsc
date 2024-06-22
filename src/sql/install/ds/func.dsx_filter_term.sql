DELIMITER //
CREATE FUNCTION IF NOT EXISTS `dsx_filter_term`(tablename varchar(128), filter_object JSON ) RETURNS longtext  
    DETERMINISTIC
BEGIN 
    RETURN (
       
    select 
        concat('(',
            group_concat(
                concat(
                    `property`,
                    ' ',`operator`,' ',
                    `value` 
                )
                separator ''
            ),
        ')')
    from (

        select 
                    
            `property`, 
            dsx_filter_operator(`operator`) `operator`,
            dsx_filter_values_extract(`value`,data_type) `value`

        from
        (
        select
            REGEXP_REPLACE(property,concat('^',tablename,'__'),'') `property`, -- remove OLD style queries
            `operator`,
            `value`
        from

            JSON_TABLE(
                JSON_MERGE(json_array(),filter_object), '$[*]'  
                COLUMNS (
                    `property` varchar(128) path '$.property',
                    `operator` varchar(15) path '$.operator',
                    `value`    JSON path '$.value'
                ) 
            ) as jtx
            
        ) jt
        join ds_column 
            on (ds_column.column_name = jt.property)
            and ds_column.table_name  = tablename

         
    ) A);
END //