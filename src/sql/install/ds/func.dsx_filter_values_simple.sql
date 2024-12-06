DELIMITER //
CREATE OR REPLACE FUNCTION   `dsx_filter_values_simple`(request JSON ) RETURNS longtext 
    DETERMINISTIC
BEGIN 
    DECLARE concat_by varchar(20);
    IF JSON_VALUE(request,'$.concat_by') is null THEN set request=JSON_SET(request,'$.concat_by','and'); END IF;
    SET concat_by = concat(' ',JSON_VALUE(request,'$.concat_by' ),' ');
    RETURN (


        select 
            replace(
                group_concat(
                    concat(
                        `property`,
                        ' ',`operator`,' ',
                        `value` 
                    )
                    separator '##########'
                ),
                '##########',
                concat_by
            )
        FROM
         
        (

            
            select 
                
                concat('`',REGEXP_REPLACE(`property`,concat('^',JSON_VALUE(request,'$.tablename'),'__'),''),'`') `property`,
                dsx_filter_operator(`operator`) `operator`,
                dsx_filter_values_extract(`value`,ds_column.data_type) `value`
            from
            (
                select
                    REGEXP_REPLACE(property,concat('^',JSON_VALUE(request,'$.tablename'),'__'),'') `property`,
                    `operator`,
                    `value`
                from

                    JSON_TABLE(json_extract(request,'$.filter'), '$[*]'  COLUMNS (

                        `property` varchar(128) path '$.property',
                        `operator` varchar(15) path '$.operator',
                        `value`    JSON path '$.value'
                        
                    ) 
                ) as jtx
                where `property` is not null
            ) jt

            join ds_column 
                on (ds_column.column_name=jt.property)
                and ds_column.table_name =json_value(request,'$.tablename')

            union


            select 
                dsx_get_key_sql(ds_column.table_name) `property`,
                dsx_filter_operator(`operator`) `operator`,
                dsx_filter_values_extract(`value`,ds_column.data_type) `value`
            from
            (
                select
                    REGEXP_REPLACE(property,concat('^',JSON_VALUE(request,'$.tablename'),'__'),'') `property`,
                    `operator`,
                    `value`
                from

                    JSON_TABLE(json_extract(request,'$.filter'), '$[*]'  COLUMNS (

                        `property` varchar(128) path '$.property',
                        `operator` varchar(15) path '$.operator',
                        `value`    JSON path '$.value'
                        
                    ) 
                ) as jtx
            ) jt

            join ds_column 
                on 
                
                `property` = '__id'
                and ds_column.table_name = json_value(request,'$.tablename')
                and ds_column.is_primary = 1
                and ds_column.existsreal = 1
        ) FILTER_TABLE

    );
END //