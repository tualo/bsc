DELIMITER ;;
CREATE FUNCTION IF NOT EXISTS `ds_serial`(request JSON ) RETURNS longtext CHARSET utf8mb4 COLLATE utf8mb4_general_ci
    DETERMINISTIC
BEGIN 
    DECLARE serialsql LONGTEXT;
    DECLARE use_table_name varchar(128);
    DECLARE fields JSON;

    SET use_table_name = JSON_VALUE(request,'$.data.__table_name');
    SET fields = JSON_KEYS(JSON_EXTRACT(request,'$.data'));

    SELECT 
        fn_serial_sql(table_name,column_name)
    INTO serialsql
    FROM 
        ds_column 
    WHERE 
        ds_column.table_name = use_table_name
        and ds_column.writeable=1
        and ( 
            JSON_SEARCH(fields,'one',concat(table_name,'__',column_name)) is not null
            and default_value = '{#serial}'
        )
    ;
    IF serialsql is null THEN 
        SET serialsql='SET @serial=0;';
    END IF;
    RETURN serialsql;

END ;;