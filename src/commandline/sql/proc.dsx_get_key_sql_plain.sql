DELIMITER ;;

CREATE FUNCTION IF NOT EXISTS `dsx_get_key_sql_plain`(in_prefix varchar(255),in_table_name varchar(64)
) RETURNS longtext  
    DETERMINISTIC
BEGIN 
    RETURN ( 
        select 
            ifnull(concat('',group_concat(concat(in_prefix,'.', FIELDQUOTE(ds_column.column_name),'') order by column_name separator ','),''),'null')
        from 
            ds_column
        where 
            ds_column.table_name = in_table_name
            and ds_column.existsreal = 1
            and ds_column.is_primary = 1
            
    );
END ;;