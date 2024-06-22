
DELIMITER ;;
CREATE FUNCTION IF NOT EXISTS `fn_json_filter_values`(request JSON, ftype varchar(20) ) RETURNS longtext CHARSET utf8mb4 COLLATE utf8mb4_general_ci
    DETERMINISTIC
BEGIN 
    DECLARE i int;
    DECLARE row_count int;
    DECLARE result LONGTEXT default '';
    DECLARE term LONGTEXT default '';

    DECLARE filterfieldname JSON default '[]';
    DECLARE filters JSON default '[]';
    DECLARE prefix varchar(20) default 'filter_';
    DECLARE sep varchar(20) default '_';

    DECLARE property varchar(255) default '';

    IF (ftype='where') THEN
        SET filters = json_extract(request,'$.filter');
        SET filterfieldname = fn_json_attribute_values( json_extract(request,'$.filter'),'property' );
    ELSEIF (ftype='having') THEN
        SET prefix = 'having_';
        SET filters = json_extract(request,'$.latefilter');
        SET filterfieldname = fn_json_attribute_values( json_extract(request,'$.latefilter'),'property' );
    END IF;


    
    SET row_count = JSON_LENGTH(filters);
    SET i = 0;

    WHILE i < row_count DO
        SET property = JSON_VALUE(filters,CONCAT('$[',i,'].property'));
        SELECT
            concat(


                ds_column.table_name, if(ftype='where','.','__'), ds_column.column_name , ' ' , 
                fn_json_operator(  JSON_VALUE(filters,CONCAT('$[',i,'].operator') ) ), ' ',
                if( 
                    JSON_VALUE(request,'$.replaced')=1, 
                    fn_json_filter_values_extract( JSON_EXTRACT(filters,CONCAT('$[',i,'].value')) ,fn_json_operator(  JSON_VALUE(filters,CONCAT('$[',i,'].operator') ) ),ds_column.data_type  ),

                    concat( '{',prefix , if( JSON_TYPE( JSON_EXTRACT(filters,CONCAT('$[',i,'].value')))='ARRAY','list_','') , i  ,'}')
                )
            )
        INTO term
        FROM
            ds_column
            join ds_column_list_label
                on (ds_column.table_name, ds_column.column_name) = (ds_column_list_label.table_name, ds_column_list_label.column_name)

        WHERE
            ds_column.table_name = JSON_VALUE(request,'$.tablename')
            and 
                ( 
                    concat(ds_column.table_name,'__',ds_column.column_name) =  property

                )
            and ds_column.existsreal=1;

        

        IF term is not null  THEN
            IF result<>'' THEN SET result = concat(result,' and '); END IF;
            SET result = concat(result,term);
        END IF;

        IF property='__id' THEN
            SELECT 
                concat( 



                    getDSKeySQL(ds_column.table_name), ' ',
                    fn_json_operator(  JSON_VALUE(filters,CONCAT('$[',i,'].operator') ) ), ' ',
                    if( 
                        JSON_VALUE(request,'$.replaced')=1, 
                        fn_json_filter_values_extract( JSON_EXTRACT(filters,CONCAT('$[',i,'].value')) ,fn_json_operator(  JSON_VALUE(filters,CONCAT('$[',i,'].operator') ) ),ds_column.data_type  ),

                        concat( '{',prefix , if( JSON_TYPE( JSON_EXTRACT(filters,CONCAT('$[',i,'].value')))='ARRAY','list_','') , i  ,'}')
                    )
                )
            INTO term
            FROM
                ds_column
                join ds_column_list_label
                    on (ds_column.table_name, ds_column.column_name) = (ds_column_list_label.table_name, ds_column_list_label.column_name)
                    and ds_column_list_label.active=1
            WHERE
                ds_column.table_name = JSON_VALUE(request,'$.tablename')
                and property= '__id'
                and ds_column.existsreal = 1
                and ds_column.is_primary = 1
                and ds_column.existsreal=1
            GROUP BY 
                ds_column.table_name
            ;

            IF term is not null  THEN
                IF result<>'' THEN SET result = concat(result,' and '); END IF;
                SET result = concat(result,term);
            END IF;
        END IF;
        
        

        SET i = i + 1;
    END WHILE;
    RETURN result;
END ;;