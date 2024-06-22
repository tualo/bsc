DELIMITER ;;
CREATE FUNCTION IF NOT EXISTS `fn_ds_read`(request JSON ) RETURNS longtext CHARSET utf8mb4 COLLATE utf8mb4_general_ci
    DETERMINISTIC
BEGIN 
    DECLARE result longtext default '';
    DECLARE readtable longtext;
    DECLARE searchfield varchar(255);
    DECLARE fieldlist longtext default '';
    DECLARE searchany tinyint default 0;
    DECLARE sorts LONGTEXT default '';
    
    DECLARE rownumber LONGTEXT default '';
    DECLARE displayfield LONGTEXT default '';
    DECLARE idfield LONGTEXT default '';

    DECLARE wherefilter LONGTEXT default 'true';
    DECLARE havingfilter LONGTEXT default 'true';
    DECLARE comibedfieldname integer default 0;


    IF JSON_VALUE(request,'$.comibedfieldname') IS NOT NULL THEN
        SET comibedfieldname=JSON_VALUE(request,'$.comibedfieldname');
    END IF;


    SELECT concat( getDSKeySQL(ds.table_name) ,' AS __id'), concat('`',ds.displayfield,'` AS __displayfield'), if( ifnull(ds.read_table,'')='',ds.table_name,ds.read_table ),ds.searchany INTO idfield,displayfield,readtable,searchany FROM ds WHERE  ds.table_name = JSON_VALUE(request,'$.tablename');


    IF JSON_VALUE(request,'$.search') IS NOT NULL THEN
        SELECT
            concat(ds.table_name,'__', ds.searchfield)
        INTO searchfield
        FROM 
            ds
        WHERE 
            table_name = JSON_VALUE(request,'$.tablename')
        ;
        SET request = JSON_INSERT( request, '$.latefilter', 
        JSON_ARRAY( 
            JSON_OBJECT('operator','like','value',  concat(if(searchany=1,'%',''),JSON_VALUE(request,'$.search') )  ,'property',searchfield)
        )

        );
    END IF;



    SET sorts = fn_ds_read_order_ex(request);
    SET wherefilter = fn_json_filter_values(request,'where');
    SET havingfilter = fn_json_filter_values(request,'having');

    IF (wherefilter IS NULL) THEN SET wherefilter='true'; END IF;
    IF (havingfilter IS NULL) THEN SET havingfilter='true'; END IF;

    SET rownumber=concat('ROW_NUMBER() OVER ( ',if( sorts is null ,'',concat(' ORDER  BY ',sorts)),') AS __rownumber');


    SELECT
        concat(
            rownumber,', ',
            displayfield,', ',
            idfield,', ',
            quote(ds_column.table_name),' AS __table_name, ',

            
            group_concat( 
                concat(
                    ds_column.table_name,'.',ds_column.column_name,
                    if(comibedfieldname=1,concat(' AS `',ds_column.table_name,'__',ds_column.column_name,'`'),'')
                )  separator ',')
        )
    INTO 
        fieldlist
    FROM
        ds_column
        join ds_column_list_label
            on (ds_column.table_name, ds_column.column_name) = (ds_column_list_label.table_name, ds_column_list_label.column_name)

        join ds_column x on (x.table_name,x.column_name) = (readtable,ds_column.column_name)
    WHERE
        ds_column.table_name = JSON_VALUE(request,'$.tablename')
        and ds_column.existsreal=1
    ;

    if exists(select alias_name from virtual_table where alias_name = readtable ) THEN
        set readtable = (select concat( '(', virtual_table_fn(readtable) ,') ' ) x);
    else
        set readtable = concat('`',readtable,'`');
    end if;
    

    IF (havingfilter<>'true') THEN
    
        SET result = concat(
            'SELECT ',
            ifnull(fieldlist,'null fieldlist_is_null'),' ',
            'FROM ',readtable,' `',JSON_VALUE(request,'$.tablename'),'` ',
            if(wherefilter<>'',concat('WHERE ',wherefilter,' '),''),
            'ORDER BY __rownumber'
        );
        SET result = concat(
            'SELECT ',if(JSON_VALUE(request,'$.calcrows')=1,'SQL_CALC_FOUND_ROWS ',' '),' * FROM (',result,') X ',
            ' ORDER BY __rownumber ',

            if(havingfilter<>'',concat( 'HAVING ',havingfilter,' '),'')
            );
    ELSE
        SET result = concat(
            'SELECT ',if(JSON_VALUE(request,'$.calcrows')=1,'SQL_CALC_FOUND_ROWS ',' '),
            fieldlist,' ',
            'FROM ',readtable,' `',JSON_VALUE(request,'$.tablename'),'` ',
            if(wherefilter<>'',concat('WHERE ',wherefilter,' '),''),
            'ORDER BY __rownumber'
        );
    END IF;

    IF JSON_VALUE(request,'$.start') IS NOT NULL AND JSON_VALUE(request,'$.limit') IS NOT NULL THEN
        SET result = concat('',result,' LIMIT ',JSON_VALUE(request,'$.start'),', ',JSON_VALUE(request,'$.limit'));
    END IF;

    RETURN result;
END ;;