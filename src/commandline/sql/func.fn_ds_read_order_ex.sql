DELIMITER ;;
CREATE FUNCTION IF NOT EXISTS `fn_ds_read_order_ex`(request JSON ) RETURNS longtext 
    DETERMINISTIC
BEGIN 
    DECLARE result longtext default '';
    DECLARE sortfieldname JSON default '[]';
    DECLARE sorts JSON default '[]';


    SET sorts = json_extract(request,'$.sort');
    SET sortfieldname = fn_json_attribute_values( sorts ,'property');

    
    SELECT
       group_concat( concat( table_name ,'.', column_name , ' ' , direction ) order by position separator ', ' )
    INTO 
        result
    FROM
    (
        SELECT
            90000 position,
            ds.table_name,
            ds.sortfield column_name,
            'ASC' direction
        FROM
            ds
            join ds_column 
                on (ds_column.table_name, ds_column.column_name) = (ds.table_name, ds.sortfield)
                and ds.table_name = JSON_VALUE(request,'$.tablename')
                and ds_column.existsreal=1
    UNION
    
        SELECT
            ROW_NUMBER() OVER () position,
            ds_column.table_name,
            ds_column.column_name,

            JSON_VALUE(sorts, concat( REPLACE( JSON_SEARCH(sortfieldname,'one',concat(ds_column.table_name,'__',ds_column.column_name)),'"','') ,'.direction') ) direction
        FROM
            ds_column
            join ds_column_list_label
                on (ds_column.table_name, ds_column.column_name) = (ds_column_list_label.table_name, ds_column_list_label.column_name)
                and ds_column_list_label.active=1
        WHERE
            ds_column.table_name = JSON_VALUE(request,'$.tablename')
            and ds_column.existsreal=1

    
    ) SUB
    ORDER BY position
    ;   
    

    RETURN result;
END ;;