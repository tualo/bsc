
DELIMITER ;;

CREATE FUNCTION IF NOT EXISTS `dsx_read_order`(request JSON ) RETURNS longtext
    DETERMINISTIC
BEGIN 
    

    RETURN (
        select 
            group_concat( concat('`',property,'` ',direction) separator ',' ) X
        from 
        (
        SELECT
            ds.sortfield property,
            'asc' direction
        FROM
        ds
        join ds_column 
            on (ds_column.table_name, ds_column.column_name) = (ds.table_name, ds.sortfield)
            and ds.table_name = JSON_VALUE(request,'$.tablename')
            and ds_column.existsreal=1 and false

        union 
        select 
            REGEXP_REPLACE(property,concat('^',JSON_VALUE(request,'$.tablename'),'__'),'') property,
            direction
        from

        JSON_TABLE(json_extract(request,'$.sort'), '$[*]'  COLUMNS (

                property varchar(128) path '$.property',
                direction  varchar(5) path '$.direction'
                
            ) ) as jt

        ) SORT_TABLE

    );
END ;;