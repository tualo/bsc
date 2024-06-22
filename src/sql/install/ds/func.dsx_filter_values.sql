DELIMITER //
CREATE FUNCTION IF NOT EXISTS `dsx_filter_values`(request JSON , ftype varchar(20)) RETURNS longtext  
    DETERMINISTIC
BEGIN 
    DECLARE concat_by varchar(20);
    DECLARE filterObject JSON;

    SET request = JSON_QUERY(request,'$');
    IF JSON_VALUE(request,'$.concat_by') is null THEN set request=JSON_SET(request,'$.concat_by','and'); END IF;
    SET concat_by = concat(' ',JSON_VALUE(request,'$.concat_by' ),' ');


    SET filterObject = JSON_EXTRACT(request,concat('$.',ftype));
    IF JSON_TYPE(filterObject)<>'ARRAY' THEN
      SET filterObject = JSON_VALUE(request,concat('$.',ftype));
    END IF;

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

                    JSON_TABLE(filterObject, '$[*]'  COLUMNS (

                        `property` varchar(128) path '$.property',
                        `operator` varchar(15) path '$.operator',
                        `value`    JSON path '$.value'
                        
                    ) 
                ) as jtx
                where 
                    `property` is not null
                    and `value` is not null
            ) jt

            join ds_column 
                on (ds_column.column_name=jt.property)
                and ds_column.table_name =json_value(request,'$.tablename')
                and `property` <> '__id'

            union


            select 
                dsx_get_key_sql( JSON_VALUE(request,'$.tablename') ) `property`,
                dsx_filter_operator(`operator`) `operator`,
                dsx_filter_values_extract(`value`,'varchar') `value`
            from
            (
                select
                    REGEXP_REPLACE(property,concat('^',JSON_VALUE(request,'$.tablename'),'__'),'') `property`,
                    `operator`,
                    `value`
                from

                    JSON_TABLE(filterObject, '$[*]'  COLUMNS (

                        `property` varchar(128) path '$.property',
                        `operator` varchar(15) path '$.operator',
                        `value`    JSON path '$.value'
                        
                    ) 
                ) as jtx
                where 
                    `property` is not null
                                    and `value` is not null
            ) jt

            where    `property` = '__id'




            
            union


            select
                    '' `property`,
                    '' `operator`,
                    concat( 
                        '(',
                        dsx_filter_values_simple( 
                            JSON_OBJECT(
                                "tablename",json_extract(request,'$.tablename'),
                                "concat_by", ifnull(jtx.concat_by,'and'),
                                "filter", JSON_MERGE(JSON_ARRAY(),`filter`)
                            ) 
                        ),
                        ')'
                    ) `value`
                from
                    JSON_TABLE(filterObject, '$[*]'  COLUMNS (
                        `concat_by` longtext path '$.concat_by',
                        `filter`    JSON path '$.filter'
                    ) 
                ) as jtx
            where jtx.filter!='NULL' -- keep in mind, JSON TYPE NULL


        union


        select
            if(`property` <> '__id',`property`,dsx_get_key_sql( JSON_VALUE(request,'$.tablename') )) `property`,
            `operator`,
            concat('(',group_concat(quote(`value`) separator ','),')') `value`
        from (
            select
                REGEXP_REPLACE(property,concat('^',JSON_VALUE(request,'$.tablename'),'__'),'') `property`,
                `operator`,
                `value`
            from

                JSON_TABLE( filterObject , '$[*]'  COLUMNS (

                        `property` varchar(128) path '$.property',
                        `operator` varchar(15) path '$.operator',
                                
                        nested path '$.value[*]' columns (
                            `value` longtext path '$'
                        )
                        
                    ) 
                ) as jtx
            where 
            `value` is not null
            
            and `property` is not null
            and `operator` in ('in','not in')
        ) c group by        
            `property`,
            `operator`    

        ) FILTER_TABLE

    );
END //