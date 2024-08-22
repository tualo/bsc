CREATE FUNCTION IF NOT EXISTS `dsx_get_key_sql`(in_table_name varchar(64)
) RETURNS longtext C 
    DETERMINISTIC
BEGIN 
    RETURN ( 
        select 
            ifnull(concat('concat(',group_concat(concat( FIELDQUOTE(ds_column.column_name),'') order by column_name separator ',\'|\','),')'),'null')
        from 
            ds_column
        where 
            ds_column.table_name = in_table_name
            and ds_column.existsreal = 1
            and ds_column.is_generated <> 'ALWAYS'
            and ds_column.is_primary = 1
            
    );
END ;;