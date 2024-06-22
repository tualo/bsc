DELIMITER ;;
CREATE FUNCTION IF NOT EXISTS `ds_update`(request JSON ) RETURNS longtext
    DETERMINISTIC
BEGIN 
    DECLARE res LONGTEXT;

    DECLARE i int;
    DECLARE row_count int;

    DECLARE use_id varchar(255);
    DECLARE use_table_name varchar(128);
    DECLARE fields JSON;
    

    SET use_table_name = JSON_VALUE(request,'$.data.__table_name');
    SET use_id = JSON_VALUE(request,'$.data.__id');
    SET fields = JSON_KEYS(JSON_EXTRACT(request,'$.data'));


    SELECT 
        
        concat(
            'UPDATE `',use_table_name,'`',
            ' SET ',
            group_concat( concat('`',column_name,'` = ', val ,'') separator ','),
            ' WHERE ',
            getDSKeySQL(use_table_name),' = ',quote( use_id )
        ) x
    INTO
        res
    FROM 
    (

        SELECT 

            ds_column.column_name,
            IF(
                JSON_SEARCH(fields,'one',concat(table_name,'__',column_name)) is not null,
                quote( JSON_VALUE( JSON_EXTRACT(request,'$.data'), concat('$.',table_name,'__',column_name,'')) ),
                IF(
                    default_value<>'',
                    fn_ds_defaults(default_value,JSON_EXTRACT(request,'$.data')),
                    quote('')
                )
            ) val
        FROM 
            ds_column 
        WHERE 
            ds_column.table_name = use_table_name
            and ds_column.writeable=1
            and ( 
                JSON_SEARCH(fields,'one',concat(table_name,'__',column_name)) is not null


            )
    ) X
    ;
    RETURN res;
END ;;