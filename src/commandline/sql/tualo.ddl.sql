


-- SOURCE FILE: ./src//000-basic/000.fieldquote.sql 
DELIMITER //
DROP FUNCTION IF EXISTS `FIELDQUOTE` //
CREATE FUNCTION `FIELDQUOTE`(in_str varchar(255))
RETURNS varchar(100)
DETERMINISTIC NO SQL
BEGIN
	RETURN concat('`',in_str,'`');
END //


DROP FUNCTION IF EXISTS `suppressRequires` //
CREATE FUNCTION `suppressRequires`()
RETURNS BOOLEAN
DETERMINISTIC NO SQL
BEGIN
	RETURN @suppressRequires=1;
END //



-- SOURCE FILE: ./src//000-basic/000.standardize_version.sql 

DROP FUNCTION IF EXISTS `standardize_version` //
CREATE FUNCTION standardize_version(version VARCHAR(255)) RETURNS varchar(255) CHARSET latin1 DETERMINISTIC NO SQL
BEGIN
  DECLARE tail VARCHAR(255);
  DECLARE head, ret VARCHAR(255) DEFAULT NULL;

  SET tail = SUBSTRING_INDEX (version,'-',1);

  WHILE tail IS NOT NULL DO 
    SET head = SUBSTRING_INDEX(tail, '.', 1);
    SET tail = NULLIF(SUBSTRING(tail, LOCATE('.', tail) + 1), tail);
    SET ret = CONCAT_WS('.', ret, CONCAT(REPEAT('0', 3 - LENGTH(CAST(head AS UNSIGNED))), head));
  END WHILE;

  RETURN ret;
END //
-- SOURCE FILE: ./src//000-basic/001.getdskeysql.sql 
DELIMITER //
DROP FUNCTION IF EXISTS getDSKeySQL //
CREATE FUNCTION getDSKeySQL(
    in_table_name varchar(64)
) 
RETURNS longtext
DETERMINISTIC
BEGIN 
    DECLARE result_sql longtext;
    select 
        ifnull(concat('concat(',group_concat(concat(/*'`',ds_column.table_name,'`','.',*/ FIELDQUOTE(ds_column.column_name),'') order by column_name separator ',\'|\','),')'),'null')
    into 
        result_sql
    from 
        ds_column
    where 
        ds_column.table_name = in_table_name
        and ds_column.existsreal = 1
        and ds_column.is_primary = 1
        -- and ds_column.column_key like '%PRI%'
    ;

    return result_sql;
END //


-- SOURCE FILE: ./src//000-basic/002.fn_ds_defaults.sql 
DELIMITER //

DROP FUNCTION IF EXISTS `fn_serial_sql` //
CREATE FUNCTION fn_serial_sql(in_table_name varchar(128),in_column_name varchar(128))
RETURNS LONGTEXT
DETERMINISTIC
BEGIN 
    DECLARE res LONGTEXT;
    select 
        concat( 'set @serial = (select ifnull(max(',column_name,'),',default_min_value-1,')+1 i from ',table_name,' where ',column_name,' between ',default_min_value,'-1 and ',default_max_value , ' having i <= ',default_max_value,');') x
    INTO res
    from ds_column where table_name=in_table_name and column_name=in_column_name;
    RETURN res;
END //

DROP FUNCTION IF EXISTS `fn_ds_defaults` //
CREATE FUNCTION `fn_ds_defaults`( str_fieldvalue varchar(255) , record JSON)
RETURNS LONGTEXT
DETERMINISTIC
BEGIN 
    IF str_fieldvalue = '{#serial}' THEN RETURN '@serial';
    ELSEIF str_fieldvalue = '{DATETIME}' THEN RETURN 'now()';
    ELSEIF str_fieldvalue = '{DATE}' THEN RETURN 'CURRENT_DATE';
    ELSEIF str_fieldvalue = '{TIME}' THEN RETURN 'CURRENT_TIME';
    ELSEIF str_fieldvalue = '{GUID}' THEN RETURN 'CURRENT_TIME';
    ELSEIF str_fieldvalue is not null THEN
        IF SUBSTRING(str_fieldvalue,1,2)='{:' and SUBSTRING(str_fieldvalue,length(str_fieldvalue),1)='}' THEN
            RETURN SUBSTRING(str_fieldvalue,3,length(str_fieldvalue)-3) ;
        ELSE
            RETURN quote(str_fieldvalue);
        END IF;
    END IF;
    RETURN str_fieldvalue;
END //

-- SOURCE FILE: ./src//000-basic/ds_privacy_rating.sql 
DELIMITER //
create table if not exists  ds_privacy_rating_types (
  id varchar(36) primary key,
  name varchar(255) not null,
  `score` integer default 0
) //

insert IGNORE into ds_privacy_rating_types (id,name,score) 
values ('undefined','Unbestimmt',0) //

create table if not exists ds_privacy_rating (
  table_name varchar(128) ,
  type_id varchar(36) not null,
  active tinyint default 0,
  primary key (table_name,type_id),
  
  constraint `fk_ds_privacy_rating_type_id`
  foreign key (type_id)
  references ds_privacy_rating_types (id)
  on delete cascade
  on update cascade,
  
  constraint `fk_ds_privacy_rating_table_name`
  foreign key (table_name)
  references ds (table_name)
  on delete cascade
  on update cascade
) //

create or replace view view_readtable_ds_privacy_rating as 
select
ds.table_name,
ds_privacy_rating_types.id type_id,
ifnull(ds_privacy_rating.active,0) active
from
ds
join ds_privacy_rating_types
left join ds_privacy_rating 
	on ds.table_name = ds_privacy_rating.table_name and ds_privacy_rating_types.id = ds_privacy_rating.type_id //
-- SOURCE FILE: ./src//100-insert/001.ds_insert.sql 
DELIMITER //

DROP FUNCTION IF EXISTS `ds_serial` //
CREATE FUNCTION `ds_serial`( request JSON )
RETURNS LONGTEXT
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

END //

CREATE OR REPLACE FUNCTION `ds_insert`( request JSON )
RETURNS LONGTEXT
DETERMINISTIC
BEGIN 
    DECLARE res LONGTEXT;

    DECLARE i int;
    DECLARE row_count int;

    DECLARE use_id varchar(255);
    DECLARE use_table_name varchar(128);
    DECLARE fields JSON;
    

    SET use_table_name = JSON_VALUE(request,'$.data.__table_name');
    SET fields = JSON_KEYS(JSON_EXTRACT(request,'$.data'));



    SELECT 
        
        concat(
            'INSERT ',if(@ds_insert_ignore is not null and @ds_insert_ignore=true,'IGNORE',''),' INTO `',use_table_name,'`',
            ' (',
            group_concat( concat('`',column_name,'`') separator ','),
            ')  values (  ',
            group_concat(   val  separator ','),
            ')    ',
            if(@ds_insert_update_on_duplicate_key is not null and @ds_insert_update_on_duplicate_key=true,
            concat( 'on duplicate key update ',group_concat( concat('`',column_name,'`','=values(`',column_name,'`)') separator ','))
            ,'')
        ) x
    INTO
        res
    FROM 
    (

        SELECT 
            -- concat(table_name,'__',column_name) attribute,
            ds_column.column_name,
            IF(
                ( 
                    JSON_SEARCH(fields,'one',concat(table_name,'__',column_name)) is not null 
                    and JSON_VALUE( JSON_EXTRACT(request,'$.data'), concat('$.',table_name,'__',column_name,'')) <>'null'
					and JSON_VALUE( JSON_EXTRACT(request,'$.data'), concat('$.',table_name,'__',column_name,'')) <> default_value

                ),
                quote( JSON_VALUE( JSON_EXTRACT(request,'$.data'), concat('$.',table_name,'__',column_name,'')) ),
                IF(
                    default_value<>'',
                    fn_ds_defaults(default_value,JSON_EXTRACT(request,'$.data')),
                    if( JSON_VALUE( JSON_EXTRACT(request,'$.data'), concat('$.',table_name,'__',column_name,'')) <>'null',
                    
                    if(
                         JSON_VALUE( JSON_EXTRACT(request,'$.data'), concat('$.',table_name,'__',column_name,'')) <>'null',
                         quote(JSON_VALUE( JSON_EXTRACT(request,'$.data'), concat('$.',table_name,'__',column_name,'')))
                         ,'null'
                    )
                    
                    , quote(''))
                )
            ) val
        FROM 
            ds_column 
        WHERE 
            ds_column.table_name = use_table_name
            and ds_column.existsreal=1
            and ds_column.writeable=1
            and ( 
                JSON_SEARCH(fields,'one',concat(table_name,'__',column_name)) is not null
                -- OR is_nullable<>'YES'
                -- OR default_value <> ''
            )
    ) X
    ;
    RETURN res;
END //

-- SOURCE FILE: ./src//100-insert/ds_rest_api.sql 

-- SOURCE FILE: ./src//100-read/001.fn_ds_read_order_ex.sql 
DELIMITER //

DROP FUNCTION IF EXISTS `fn_ds_read_order_ex` //
CREATE FUNCTION `fn_ds_read_order_ex`( request JSON )
RETURNS longtext
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
           -- JSON_VALUE(sorts, concat( JSON_SEARCH(sortfieldname,'one',concat(ds_column.table_name,'__',ds_column.column_name)),'.direction') ) direction
            JSON_VALUE(sorts, concat( REPLACE( JSON_SEARCH(sortfieldname,'one',concat(ds_column.table_name,'__',ds_column.column_name)),'"','') ,'.direction') ) direction
        FROM
            ds_column
            join ds_column_list_label
                on (ds_column.table_name, ds_column.column_name) = (ds_column_list_label.table_name, ds_column_list_label.column_name)
                and ds_column_list_label.active=1
        WHERE
            ds_column.table_name = JSON_VALUE(request,'$.tablename')
            and ds_column.existsreal=1
            -- and JSON_SEARCH(sortfieldname,'one',concat(ds_column.table_name,'__',ds_column.column_name)) is not null
    
    ) SUB
    ORDER BY position
    ;   
    

    RETURN result;
END //
-- SOURCE FILE: ./src//100-read/001.fn_json_attribute_values.sql 
DELIMITER //

DROP FUNCTION IF EXISTS `fn_json_attribute_values` //
CREATE FUNCTION `fn_json_attribute_values`( request JSON , attribute varchar(128))
RETURNS JSON
DETERMINISTIC
BEGIN 
    DECLARE i int;
    DECLARE row_count int;
    DECLARE result JSON default '[]';
    SET row_count = JSON_LENGTH(request);
    SET i = 0;
    WHILE i < row_count DO
        SET result = JSON_ARRAY_APPEND(result, '$', JSON_VALUE(request,CONCAT('$[',i,'].',attribute)) );
        SET i = i + 1;
    END WHILE;
    RETURN result;
END //



-- SOURCE FILE: ./src//100-read/001.fn_json_filter_values.sql 
DELIMITER //



CREATE OR REPLACE FUNCTION `fn_json_filter_values`( request JSON, ftype varchar(20) )
RETURNS LONGTEXT
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
    -- SET result = concat('-- ',row_count,' ----');
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
                -- and ds_column_list_label.active=1
        WHERE
            ds_column.table_name = JSON_VALUE(request,'$.tablename')
            and 
                ( 
                    concat(ds_column.table_name,'__',ds_column.column_name) =  property
                    -- or JSON_VALUE(filters,CONCAT('$[',i,'].property')) = '__id'
                )
            and ds_column.existsreal=1;

        

        IF term is not null  THEN
            IF result<>'' THEN SET result = concat(result,' and '); END IF;
            SET result = concat(result,term);
        END IF;


        -- id field
        IF property='__id' THEN
            SELECT 
                concat( 
                    
                    -- ifnull(JSON_TYPE(val),''),'* ', 
                    -- JSON_EXTRACT(filters,CONCAT('$[',i,'].value')),

                    -- ds_column.table_name, if(ftype='where','.','__'), ds_column.column_name , ' ' , 
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
END //



-- SOURCE FILE: ./src//100-read/001.fn_json_filter_values_extract.sql 
DELIMITER //


DROP FUNCTION IF EXISTS `fn_json_filter_values_extract` //
CREATE FUNCTION `fn_json_filter_values_extract`( request JSON, operator varchar(20), dtype varchar(36) )
RETURNS LONGTEXT
DETERMINISTIC
BEGIN 
    DECLARE _type varchar(36);
    DECLARE i int;
    DECLARE row_count int;
    DECLARE result LONGTEXT default '';
    DECLARE term LONGTEXT default '';

    
    SET _type = JSON_TYPE(request);

    IF (_type IS NULL ) THEN RETURN 'NULL'; END IF;
    

    IF (_type='STRING') THEN RETURN  JSON_QUOTE(JSON_UNQUOTE(request)); END IF;
    IF (_type='BLOB') THEN RETURN JSON_QUOTE(JSON_UNQUOTE(request)); END IF;

    IF (_type='BOOLEAN') THEN 
        IF (JSON_VALUE(request,'$')=TRUE) THEN 
            RETURN 1;
        ELSE
            RETURN 0;
        END IF;
    END IF;

    IF (_type='DECIMAL') THEN RETURN JSON_VALUE(request,'$'); END IF;
    IF (_type='DOUBLE') THEN RETURN JSON_VALUE(request,'$'); END IF;
    IF (_type='INTEGER') THEN RETURN JSON_VALUE(request,'$'); END IF;
    IF (_type='NULL') THEN RETURN 'NULL'; END IF;
    IF (_type='DECIMAL') THEN RETURN JSON_VALUE(request,'$'); END IF;
    
    IF (_type='OBJECT') OR (_type='OPAQUE') THEN 
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=30001, MESSAGE_TEXT='Object Type is not allowed as value';
    END IF;

    IF (_type='DATE') THEN RETURN JSON_QUOTE(JSON_VALUE(request,'$')); END IF;
    IF (_type='DATETIME') THEN RETURN  JSON_QUOTE(JSON_VALUE(request,'$')); END IF;
    IF (_type='TIME') THEN RETURN JSON_QUOTE(JSON_VALUE(request,'$')); END IF;
    IF (_type='BIT') THEN RETURN JSON_QUOTE(JSON_VALUE(request,'$')); END IF;

    IF (_type='ARRAY') THEN 
        SET row_count = JSON_LENGTH(request);
        SET i = 0;
        
        WHILE i < row_count DO

            SET term= JSON_QUOTE(JSON_VALUE(request,CONCAT('$[',i,']')));
            IF term is not null  THEN
                IF result<>'' THEN SET result = concat(result,', '); END IF;
                SET result = concat(result,term);
            END IF;
            SET i = i + 1;
        END WHILE;
        SET result = concat('(',result,')');
    END IF;
    return result;

END //
-- SOURCE FILE: ./src//100-read/001.fn_json_operator.sql 
DELIMITER //

DROP FUNCTION IF EXISTS `fn_json_operator` //
CREATE FUNCTION `fn_json_operator`(operator varchar(128))
RETURNS JSON
DETERMINISTIC
BEGIN 
    DECLARE result varchar(128) default '=';
    
    IF operator='==' or operator='eq' THEN SET result='='; END IF;
    IF operator='!=' or operator='not' THEN SET result='<>'; END IF;
    IF operator='>=' or operator='gt' THEN SET result='>='; END IF;
    IF operator='<=' or operator='lt' THEN SET result='<='; END IF;
    IF operator='not like' THEN SET result='not like'; END IF;
    IF operator='like' THEN SET result='like'; END IF;
    IF operator='in' THEN SET result='in'; END IF;
    IF operator='not in' THEN SET result='not åin'; END IF;

    RETURN result;
END //
-- SOURCE FILE: ./src//100-read/010.fn_ds_read.sql 
DELIMITER //
CREATE OR REPLACE FUNCTION `german_to_decimal`( str varchar(100) )
RETURNS decimal(10,2)
DETERMINISTIC
BEGIN 
    return cast( replace(replace(str,'.',''),',','.') as decimal(10,2));
END //


DROP FUNCTION IF EXISTS `fn_ds_read` //
CREATE FUNCTION `fn_ds_read`( request JSON )
RETURNS longtext
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
        -- concat('[{"operator":"like","value":',QUOTE(),',"property":"',searchfield,'"}]') 
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
            -- and ds_column_list_label.active=1
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
END //

-- SOURCE FILE: ./src//100-read/999.test.sql 

DELIMITER //

/*

SET @r='{
    "tablename": "geschaeftsstatus",
    "page": 1,
    "start": 0,
    "limit": 100,
    "sort": [{"property":"geschaeftsstatus__name","direction":"DESC"}],
    "filter": [{"operator":"like","value":"%","property":"geschaeftsstatus__geschaeftsstatus"}],
    "search": "l",
    "replaced": 1,
    "comibedfieldname": 1
}' //
-- SET @r='{"tablename":"adressen","replaced":1,"filter":[],"sort":[],"page":1,"start":0,"limit":10000,"search":"","comibedfieldname": 1}';
-- SET @r='{"tablename":"adressen","replaced":0,"comibedfieldname":1,"filter":[{"operator":"like","value":"07545","property":"adressen__plz"}],"sort":[{"property":"adressen__name","sorterFn":null,"root":"data","direction":"ASC","id":"adressen__name"}],"page":1,"start":0,"limit":10000,"search":"ann"}';


-- SET @r='{"tablename":"adressen","replaced":1,"calcrows":1,"comibedfieldname":1,"filter":[{"operator":"like","value":"07545","property":"adressen__plz"}],"sort":[{"property":"adressen__name","sorterFn":null,"root":"data","direction":"ASC","id":"adressen__name"}],"page":1,"start":0,"limit":10000,"search":"dielas"}';
SET @r='{"tablename":"adressen","replaced":1,"comibedfieldname":1,"calcrows":1,"filter":[{"operator":"==","value":true,"property":"adressen__sap_aktiviert"}],"sort":[{"property":"adressen__strasse","direction":"DESC"}],"page":1,"start":0,"limit":100,"search":""}';
-- queryparams: "{"tablename":"view_blg_list_fr","replaced":1,"comibedfieldname":1,"calcrows":1,"filter":[{"operator":"gt","value":"2020-06-01","property":"view_blg_list_fr__datum"},{"operator":"lt","value":"2020-11-01","property":"view_blg_list_fr__datum"}],"sort":[],"page":1,"start":0,"limit":100,"search":""}"

SET @r='{"tablename":"view_blg_list_fr","replaced":1,"comibedfieldname":1,"calcrows":1,"filter":[{"operator":"in","value":[1,3],"property":"view_blg_list_fr__beleg_zahlart"},{"operator":"gt","value":"1000.00","property":"view_blg_list_fr__brutto"},{"operator":"gt","value":"2020-10-01 00:00:00","property":"view_blg_list_fr__datum"}],"sort":[],"page":1,"start":0,"limit":100,"search":""}';

-- select json_extract(@r,'$.sort') x;
-- select fn_ds_read_order_ex(@r) //
-- SELECT fn_ds_read(@r) s //
SELECT fn_json_filter_values(@r,'where');
*/
-- SOURCE FILE: ./src//100-read/ds_rest_api.sql 
DELIMITER //


SET @r='{
    "tablename": "geschaeftsstatus",
    "page": 1,
    "start": 0,
    "limit": 100,
    "sort": [{"property":"geschaeftsstatus__name","direction":"DESC"}],
    "filter": [{"operator":"like","value":"%","property":"geschaeftsstatus__geschaeftsstatus"}],
    "search": "l",
    "replaced": 1,
    "comibedfieldname": 1
}' //

SET @r='{"tablename":"adressen","replaced":1,"comibedfieldname":1,"filter":[{"operator":"like","value":"07545","property":"adressen__plz"}],"sort":[{"property":"adressen__name","sorterFn":null,"root":"data","direction":"ASC","id":"adressen__name"}],"page":1,"start":0,"limit":10000,"search":"ann"}';

CREATE OR REPLACE PROCEDURE `ds_rest_api_get`( IN request JSON , OUT result JSON)
BEGIN 

    DECLARE fieldlist LONGTEXT default '';
    DECLARE fieldobjectlist LONGTEXT default '';
    DECLARE idfield LONGTEXT default '';
    DECLARE displayfield LONGTEXT default '';
    DECLARE readtable LONGTEXT default '';
    DECLARE searchany LONGTEXT default '';
    DECLARE searchfield LONGTEXT default '';
    DECLARE rownumber LONGTEXT default '';
    DECLARE sorts LONGTEXT default '';
    DECLARE wherefilter LONGTEXT default '';
    DECLARE havingfilter LONGTEXT default '';
    DECLARE basequery LONGTEXT default '';
    DECLARE query LONGTEXT default '';
    DECLARE comibedfieldname integer default 0;
    DECLARE counts integer default 0;
    DECLARE sql_command longtext;

    IF JSON_VALUE(request,'$.comibedfieldname') IS NOT NULL THEN
        SET comibedfieldname=JSON_VALUE(request,'$.comibedfieldname');
    END IF;

    SET sorts = fn_ds_read_order_ex(request);
    SET wherefilter = fn_json_filter_values(request,'where');
    SET havingfilter = fn_json_filter_values(request,'having');

    IF (wherefilter IS NULL) THEN SET wherefilter='true'; END IF;
    IF (havingfilter IS NULL) THEN SET havingfilter='true'; END IF;


    SELECT concat( getDSKeySQL(ds.table_name) ,' AS `__id`'), concat('`',ds.displayfield,'` AS `__displayfield`'), if( ifnull(ds.read_table,'')='',ds.table_name,ds.read_table ),ds.searchany INTO idfield,displayfield,readtable,searchany FROM ds WHERE  ds.table_name = JSON_VALUE(request,'$.tablename');

    SET rownumber=concat('ROW_NUMBER() OVER ( ',if( sorts is null ,'',concat(' ORDER  BY ',sorts)),') AS `__rownumber`');


    IF JSON_VALUE(request,'$.search') IS NOT NULL THEN
        SELECT
            concat(ds.table_name,'__', ds.searchfield)
        INTO 
            searchfield
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

    SELECT
        concat(
            rownumber,', ',
            displayfield,', ',
            idfield,', ',
            quote(ds_column.table_name),' AS `__table_name`, ',
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
            -- and ds_column_list_label.active=1
        join ds_column x on (x.table_name,x.column_name) = (readtable,ds_column.column_name)
    WHERE
        ds_column.table_name = JSON_VALUE(request,'$.tablename')
        and ds_column.existsreal=1;


    if exists(select alias_name from virtual_table where alias_name = readtable ) THEN
        set readtable = (select concat( '(', virtual_table_fn(readtable) ,') ' ) x);
    else
        set readtable = concat('`',readtable,'`');
    end if;

    SET basequery = concat(
        'SELECT ',
        fieldlist,' ',
        'FROM ',readtable,' `',JSON_VALUE(request,'$.tablename'),'` ',
        if(wherefilter<>'',concat('WHERE ',wherefilter,' '),''),
        'ORDER BY __rownumber'
    );

    set query = basequery;

    IF JSON_VALUE(request,'$.start') IS NOT NULL AND JSON_VALUE(request,'$.limit') IS NOT NULL THEN
        SET query = concat('',basequery,' LIMIT ',JSON_VALUE(request,'$.start'),', ',JSON_VALUE(request,'$.limit'));
    END IF;

    -- SELECT JSON_ARRAYAGG(JSON_OBJECT('name', name, 'phone', phone))
    SET sql_command=concat('select count(0) into @counts from (',basequery,') x');
    PREPARE stmt FROM sql_command;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    
    set result=JSON_OBJECT(
        'total',@counts
    );
    
END //

delimiter ;

set @sessionuser='thomas.hoffmann@tualo.de';
call ds_rest_api_get(@r,@o);
select @o;
-- SOURCE FILE: ./src//100-update/001.ds_update.sql 
DELIMITER //

DROP FUNCTION IF EXISTS `ds_update` //
CREATE FUNCTION `ds_update`( request JSON )
RETURNS LONGTEXT
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
            -- concat(table_name,'__',column_name) attribute,
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
                -- OR is_nullable<>'YES'
                -- OR default_value <> ''
            )
    ) X
    ;
    RETURN res;
END //

-- SOURCE FILE: ./src//500-ui/000-types/000.custom_xtypes.sql 
delimiter ;

-- drop table custom_types_attributes_boolean;
-- drop table custom_types_attributes_string;
-- drop table custom_types_attributes_integer;
-- drop table custom_types;

create table if not exists `custom_types` (
    id varchar(100) primary key,
    xtype_long_classic varchar(100) default null,
    xtype_long_modern varchar(100) default null,
    extendsxtype_classic varchar(100) default null,
    extendsxtype_modern varchar(100) default null,
    name varchar(100) not null,
    vendor varchar(50) not null,
    description varchar(255) default '',
    create_datetime datetime default CURRENT_TIMESTAMP,
    login varchar(100) default null
);




create or replace view view_readtable_custom_types as
select 
    `id`,
    `xtype_long_modern`,
    `xtype_long_classic`,

    SUBSTRING_INDEX(`xtype_long_modern`, '.', 1) `modern_typeclass`,
    SUBSTRING_INDEX(`xtype_long_modern`, '.', -1) `modern_type`,

    SUBSTRING_INDEX(`xtype_long_classic`, '.', 1) `classic_typeclass`,
    SUBSTRING_INDEX(`xtype_long_classic`, '.', -1) `classic_type`,

    `name`,
    `vendor`,
    `description`

from `custom_types` 
;

create table if not exists `custom_types_attributes_integer` (
    id varchar(100) not null,
    property varchar(100) not null,
    primary key(id,property),
    description varchar(255) default '',

    val integer default null,
    
    constraint `fk_custom_types_attributes_integer_id`
    foreign key (id)
    references custom_types(id)
    on delete cascade
    on update cascade
);

create table if not exists `custom_types_attributes_string` (
    id varchar(100) not null,
    property varchar(100) not null,
    primary key(id,property),
    description varchar(255) default '',

    val varchar(255) default null,
    
    constraint `fk_custom_types_attributes_string_id`
    foreign key (id)
    references custom_types(id)
    on delete cascade
    on update cascade
);


create table if not exists `custom_types_attributes_boolean` (
    id varchar(100) not null,
    property varchar(100) not null,
    primary key(id,property),
    description varchar(255) default '',

    val tinyint default null,

    constraint `fk_custom_types_attributes_boolean_id`
    foreign key (id)
    references custom_types(id)
    on delete cascade
    on update cascade
);

insert into custom_types 
(id,xtype_long_classic,xtype_long_modern,extendsxtype_classic,extendsxtype_modern,name,vendor) values 
('Tualo.grid.column.Number5','widget.tualocolumnnumber5','widget.tualocolumnnumber5','Ext.grid.column.Number','Ext.grid.column.Number',
'Tualo.grid.column.Number5','Tualo') on duplicate key update 
    id=values(id),
    extendsxtype_modern=values(extendsxtype_modern),
    name=values(name),
    vendor=values(vendor)
;

insert into custom_types_attributes_string (id,property,val) values 
('Tualo.grid.column.Number5','format','0.000,00000'),
('Tualo.grid.column.Number5','defaultFilterType','number'),
('Tualo.grid.column.Number5','align','right')
on duplicate key update id=values(id),val=values(val);

insert into custom_types 
(id,xtype_long_classic,xtype_long_modern,extendsxtype_classic,extendsxtype_modern,name,vendor) values 
('Tualo.grid.column.Number0','widget.tualocolumnnumber0','widget.tualocolumnnumber0','Ext.grid.column.Number','Ext.grid.column.Number',
'Tualo.grid.column.Number0','Tualo') on duplicate key update 
    id=values(id),
    extendsxtype_modern=values(extendsxtype_modern),
    name=values(name),
    vendor=values(vendor)
;
insert into custom_types_attributes_string (id,property,val) values 
('Tualo.grid.column.Number0','format','0.000/i'),
('Tualo.grid.column.Number0','defaultFilterType','number'),
('Tualo.grid.column.Number0','align','right')
on duplicate key update id=values(id),val=values(val);


insert into custom_types 
(id,xtype_long_classic,xtype_long_modern,extendsxtype_classic,extendsxtype_modern,name,vendor) values 
('Tualo.grid.column.Number2','widget.tualocolumnnumber2','widget.tualocolumnnumber2','Ext.grid.column.Number','Ext.grid.column.Number',
'Tualo.grid.column.Number2','Tualo') on duplicate key update 
    id=values(id),
    extendsxtype_modern=values(extendsxtype_modern),
    name=values(name),
    vendor=values(vendor)
;
insert into custom_types_attributes_string (id,property,val) values 
('Tualo.grid.column.Number2','format','0.000,00'),
('Tualo.grid.column.Number2','defaultFilterType','number'),
('Tualo.grid.column.Number2','align','right')
on duplicate key update id=values(id),val=values(val);


insert into custom_types 
(id,xtype_long_classic,xtype_long_modern,extendsxtype_classic,extendsxtype_modern,name,vendor) values 
('Tualo.grid.column.MoneyColumn2','widget.moneycolumn2','widget.moneycolumn2','Ext.grid.column.Number','Ext.grid.column.Number',
'Tualo.grid.column.MoneyColumn2','Tualo') on duplicate key update 
    id=values(id),
    extendsxtype_modern=values(extendsxtype_modern),
    name=values(name),
    vendor=values(vendor)
;
insert into custom_types_attributes_string (id,property,val) values 
('Tualo.grid.column.MoneyColumn2','format','0.000,00'),
('Tualo.grid.column.MoneyColumn2','defaultFilterType','number'),
('Tualo.grid.column.MoneyColumn2','align','right')
on duplicate key update id=values(id),val=values(val);

insert into custom_types 
(id,xtype_long_classic,xtype_long_modern,extendsxtype_classic,extendsxtype_modern,name,vendor) values 
('Tualo.grid.column.MoneyColumn5','widget.moneycolumn5','widget.moneycolumn5','Ext.grid.column.Number','Ext.grid.column.Number',
'Tualo.grid.column.MoneyColumn5','Tualo') on duplicate key update 
    id=values(id),
    extendsxtype_modern=values(extendsxtype_modern),
    name=values(name),
    vendor=values(vendor)
;
insert into custom_types_attributes_string (id,property,val) values 
('Tualo.grid.column.MoneyColumn5','format','0.000,00/i'),
('Tualo.grid.column.MoneyColumn5','defaultFilterType','number'),
('Tualo.grid.column.MoneyColumn5','align','right')
on duplicate key update id=values(id),val=values(val);




insert into custom_types 
(id,xtype_long_classic,xtype_long_modern,extendsxtype_classic,extendsxtype_modern,name,vendor) values 
('Tualo.grid.column.DEDateDisplayColumn','widget.tualodedatedisplaycolumn','widget.tualodedatedisplaycolumn','Ext.grid.column.Date','Ext.grid.column.Date',
'Tualo.grid.column.DEDateDisplayColumn','Tualo') on duplicate key update 
    id=values(id),
    extendsxtype_modern=values(extendsxtype_modern),
    name=values(name),
    vendor=values(vendor)
;
insert into custom_types_attributes_string (id,property,val) values 
('Tualo.grid.column.DEDateDisplayColumn','format','d.m.Y'),
('Tualo.grid.column.DEDateDisplayColumn','defaultFilterType','date'),
('Tualo.grid.column.DEDateDisplayColumn','align','center')
on duplicate key update id=values(id),val=values(val);


insert into custom_types 
(id,xtype_long_classic,xtype_long_modern,extendsxtype_classic,extendsxtype_modern,name,vendor) values 
('Tualo.grid.column.DatetimeDisplayColumn','widget.tualodatetimedisplaycolumn','widget.tualodatetimedisplaycolumn','Ext.grid.column.Date','Ext.grid.column.Date',
'Tualo.grid.column.DatetimeDisplayColumn','Tualo') on duplicate key update 
    id=values(id),
    extendsxtype_modern=values(extendsxtype_modern),
    name=values(name),
    vendor=values(vendor)
;
insert into custom_types_attributes_string (id,property,val) values 
('Tualo.grid.column.DatetimeDisplayColumn','format','d.m.Y H:i'),
('Tualo.grid.column.DatetimeDisplayColumn','defaultFilterType','date'),
('Tualo.grid.column.DatetimeDisplayColumn','align','center')
on duplicate key update id=values(id),val=values(val);


-- SOURCE FILE: ./src//500-ui/000-types/000.xtypes.sql 
delimiter ;

-- drop table extjs_base_types;
create table if not exists `extjs_base_types` (
    id varchar(100) primary key,
    classname varchar(255) not null,
    baseclass varchar(255) not null,
    xtype_long_classic varchar(100) default null,
    xtype_long_modern varchar(100) default null,
    name varchar(100) not null,
    vendor varchar(50) not null,
    description varchar(255) default '',
    iscolumn tinyint default 0,
    isformfield tinyint default 0
);



create or replace view view_readtable_extjs_base_types as
select 
    `id`,
    `xtype_long_modern`,
    `xtype_long_classic`,

    SUBSTRING_INDEX(`xtype_long_modern`, '.', 1) `modern_typeclass`,
    SUBSTRING_INDEX(`xtype_long_modern`, '.', -1) `modern_type`,

    SUBSTRING_INDEX(`xtype_long_classic`, '.', 1) `classic_typeclass`,
    SUBSTRING_INDEX(`xtype_long_classic`, '.', -1) `classic_type`,

    `name`,
    `vendor`,
    `description`

from `extjs_base_types` 
;




-- Modern
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.request.Ajax (request.ajax)','Ext.data.request.Ajax','Ext.data.request.Base','request.ajax','Ext.data.request.Ajax','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.request.Form (request.form)','Ext.data.request.Form','Ext.data.request.Base','request.form','Ext.data.request.Form','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Widget (widget.widget)','Ext.Widget','Ext.Evented','widget.widget','Ext.Widget','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.fx.easing.Linear (easing.linear)','Ext.fx.easing.Linear','Ext.fx.easing.Abstract','easing.linear','Ext.fx.easing.Linear','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.util.translatable.Dom (translatable.dom)','Ext.util.translatable.Dom','Ext.util.translatable.Abstract','translatable.dom','Ext.util.translatable.Dom','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.util.translatable.CssPosition (translatable.cssposition)','Ext.util.translatable.CssPosition','Ext.util.translatable.Dom','translatable.cssposition','Ext.util.translatable.CssPosition','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.util.translatable.CssTransform (translatable.csstransform)','Ext.util.translatable.CssTransform','Ext.util.translatable.Dom','translatable.csstransform','Ext.util.translatable.CssTransform','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.scroll.Scroller (scroller.scroller)','Ext.scroll.Scroller','Ext.Evented','scroller.scroller','Ext.scroll.Scroller','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Component (widget.component)','Ext.Component','Ext.Widget','widget.component','Ext.Component','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Progress (widget.progress)','Ext.Progress','Ext.Component','widget.progress','Ext.Progress','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Progress (widget.progressbarwidget)','Ext.Progress','Ext.Component','widget.progressbarwidget','Ext.Progress','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.fx.animation.Slide (animation.slide)','Ext.fx.animation.Slide','Ext.fx.animation.Abstract','animation.slide','Ext.fx.animation.Slide','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.fx.animation.Slide (animation.slideIn)','Ext.fx.animation.Slide','Ext.fx.animation.Abstract','animation.slideIn','Ext.fx.animation.Slide','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.fx.animation.SlideOut (animation.slideOut)','Ext.fx.animation.SlideOut','Ext.fx.animation.Slide','animation.slideOut','Ext.fx.animation.SlideOut','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.fx.animation.Fade (animation.fade)','Ext.fx.animation.Fade','Ext.fx.animation.Abstract','animation.fade','Ext.fx.animation.Fade','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.fx.animation.Fade (animation.fadeIn)','Ext.fx.animation.Fade','Ext.fx.animation.Abstract','animation.fadeIn','Ext.fx.animation.Fade','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.fx.animation.FadeOut (animation.fadeOut)','Ext.fx.animation.FadeOut','Ext.fx.animation.Fade','animation.fadeOut','Ext.fx.animation.FadeOut','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.fx.animation.Flip (animation.flip)','Ext.fx.animation.Flip','Ext.fx.animation.Abstract','animation.flip','Ext.fx.animation.Flip','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.fx.animation.Pop (animation.pop)','Ext.fx.animation.Pop','Ext.fx.animation.Abstract','animation.pop','Ext.fx.animation.Pop','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.fx.animation.Pop (animation.popIn)','Ext.fx.animation.Pop','Ext.fx.animation.Abstract','animation.popIn','Ext.fx.animation.Pop','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.fx.animation.PopOut (animation.popOut)','Ext.fx.animation.PopOut','Ext.fx.animation.Pop','animation.popOut','Ext.fx.animation.PopOut','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.schema.Namer (namer.default)','Ext.data.schema.Namer','Ext.Base','namer.default','Ext.data.schema.Namer','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.schema.Schema (schema.default)','Ext.data.schema.Schema','Ext.Base','schema.default','Ext.data.schema.Schema','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.operation.Create (data.operation.create)','Ext.data.operation.Create','Ext.data.operation.Operation','data.operation.create','Ext.data.operation.Create','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.operation.Destroy (data.operation.destroy)','Ext.data.operation.Destroy','Ext.data.operation.Operation','data.operation.destroy','Ext.data.operation.Destroy','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.operation.Read (data.operation.read)','Ext.data.operation.Read','Ext.data.operation.Operation','data.operation.read','Ext.data.operation.Read','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.operation.Update (data.operation.update)','Ext.data.operation.Update','Ext.data.operation.Operation','data.operation.update','Ext.data.operation.Update','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.Validator (data.validator.base)','Ext.data.validator.Validator','Ext.Base','data.validator.base','Ext.data.validator.Validator','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.field.Field (data.field.auto)','Ext.data.field.Field','Ext.Base','data.field.auto','Ext.data.field.Field','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.field.Array (data.field.array)','Ext.data.field.Array','Ext.data.field.Field','data.field.array','Ext.data.field.Array','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.field.Boolean (data.field.bool)','Ext.data.field.Boolean','Ext.data.field.Field','data.field.bool','Ext.data.field.Boolean','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.field.Boolean (data.field.boolean)','Ext.data.field.Boolean','Ext.data.field.Field','data.field.boolean','Ext.data.field.Boolean','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.field.Date (data.field.date)','Ext.data.field.Date','Ext.data.field.Field','data.field.date','Ext.data.field.Date','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.field.Integer (data.field.int)','Ext.data.field.Integer','Ext.data.field.Field','data.field.int','Ext.data.field.Integer','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.field.Integer (data.field.integer)','Ext.data.field.Integer','Ext.data.field.Field','data.field.integer','Ext.data.field.Integer','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.field.Number (data.field.float)','Ext.data.field.Number','Ext.data.field.Integer','data.field.float','Ext.data.field.Number','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.field.Number (data.field.number)','Ext.data.field.Number','Ext.data.field.Integer','data.field.number','Ext.data.field.Number','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.field.String (data.field.string)','Ext.data.field.String','Ext.data.field.Field','data.field.string','Ext.data.field.String','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.identifier.Generator (data.identifier.default)','Ext.data.identifier.Generator','Ext.Base','data.identifier.default','Ext.data.identifier.Generator','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.identifier.Sequential (data.identifier.sequential)','Ext.data.identifier.Sequential','Ext.data.identifier.Generator','data.identifier.sequential','Ext.data.identifier.Sequential','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.reader.Reader (reader.base)','Ext.data.reader.Reader','Ext.Base','reader.base','Ext.data.reader.Reader','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.writer.Writer (writer.base)','Ext.data.writer.Writer','Ext.Base','writer.base','Ext.data.writer.Writer','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.proxy.Proxy (proxy.proxy)','Ext.data.proxy.Proxy','Ext.Base','proxy.proxy','Ext.data.proxy.Proxy','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.proxy.Memory (proxy.memory)','Ext.data.proxy.Memory','Ext.data.proxy.Client','proxy.memory','Ext.data.proxy.Memory','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.proxy.Server (proxy.server)','Ext.data.proxy.Server','Ext.data.proxy.Proxy','proxy.server','Ext.data.proxy.Server','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.proxy.Ajax (proxy.ajax)','Ext.data.proxy.Ajax','Ext.data.proxy.Server','proxy.ajax','Ext.data.proxy.Ajax','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.reader.Json (reader.json)','Ext.data.reader.Json','Ext.data.reader.Reader','reader.json','Ext.data.reader.Json','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.writer.Json (writer.json)','Ext.data.writer.Json','Ext.data.writer.Writer','writer.json','Ext.data.writer.Json','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.Store (store.store)','Ext.data.Store','Ext.data.ProxyStore','store.store','Ext.data.Store','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.reader.Array (reader.array)','Ext.data.reader.Array','Ext.data.reader.Json','reader.array','Ext.data.reader.Array','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.ArrayStore (store.array)','Ext.data.ArrayStore','Ext.data.Store','store.array','Ext.data.ArrayStore','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Container (widget.container)','Ext.Container','Ext.Component','widget.container','Ext.Container','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.Auto (layout.default)','Ext.layout.Auto','Ext.Base','layout.default','Ext.layout.Auto','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.Auto (layout.auto)','Ext.layout.Auto','Ext.Base','layout.auto','Ext.layout.Auto','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Indicator (widget.indicator)','Ext.Indicator','Ext.Component','widget.indicator','Ext.Indicator','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.card.fx.Abstract (layout.card.fx.abstract)','Ext.layout.card.fx.Abstract','Ext.Evented','layout.card.fx.abstract','Ext.layout.card.fx.Abstract','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.card.fx.Cover (layout.card.fx.cover)','Ext.layout.card.fx.Cover','Ext.layout.card.fx.Style','layout.card.fx.cover','Ext.layout.card.fx.Cover','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.card.fx.Cube (layout.card.fx.cube)','Ext.layout.card.fx.Cube','Ext.layout.card.fx.Style','layout.card.fx.cube','Ext.layout.card.fx.Cube','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.card.fx.Fade (layout.card.fx.fade)','Ext.layout.card.fx.Fade','Ext.layout.card.fx.Serial','layout.card.fx.fade','Ext.layout.card.fx.Fade','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.card.fx.Flip (layout.card.fx.flip)','Ext.layout.card.fx.Flip','Ext.layout.card.fx.Serial','layout.card.fx.flip','Ext.layout.card.fx.Flip','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.card.fx.Pop (layout.card.fx.pop)','Ext.layout.card.fx.Pop','Ext.layout.card.fx.Serial','layout.card.fx.pop','Ext.layout.card.fx.Pop','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.card.fx.Reveal (layout.card.fx.reveal)','Ext.layout.card.fx.Reveal','Ext.layout.card.fx.Style','layout.card.fx.reveal','Ext.layout.card.fx.Reveal','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.card.fx.Scroll (layout.card.fx.scroll)','Ext.layout.card.fx.Scroll','Ext.layout.card.fx.Abstract','layout.card.fx.scroll','Ext.layout.card.fx.Scroll','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.card.fx.ScrollCover (layout.card.fx.scrollcover)','Ext.layout.card.fx.ScrollCover','Ext.layout.card.fx.Scroll','layout.card.fx.scrollcover','Ext.layout.card.fx.ScrollCover','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.card.fx.ScrollReveal (layout.card.fx.scrollreveal)','Ext.layout.card.fx.ScrollReveal','Ext.layout.card.fx.Scroll','layout.card.fx.scrollreveal','Ext.layout.card.fx.ScrollReveal','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.card.fx.Slide (layout.card.fx.slide)','Ext.layout.card.fx.Slide','Ext.layout.card.fx.Style','layout.card.fx.slide','Ext.layout.card.fx.Slide','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.Card (layout.card)','Ext.layout.Card','Ext.layout.Auto','layout.card','Ext.layout.Card','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.viewport.Default (widget.viewport)','Ext.viewport.Default','Ext.Container','widget.viewport','Ext.viewport.Default','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.app.ViewController (controller.controller)','Ext.app.ViewController','Ext.app.BaseController','controller.controller','Ext.app.ViewController','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.ChainedStore (store.chained)','Ext.data.ChainedStore','Ext.data.AbstractStore','store.chained','Ext.data.ChainedStore','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.app.ViewModel (viewmodel.default)','Ext.app.ViewModel','Ext.Base','viewmodel.default','Ext.app.ViewModel','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.direct.Provider (direct.provider)','Ext.direct.Provider','Ext.Base','direct.provider','Ext.direct.Provider','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.BufferedStore (store.buffered)','Ext.data.BufferedStore','Ext.data.ProxyStore','store.buffered','Ext.data.BufferedStore','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.ClientStore (store.clientstorage)','Ext.data.ClientStore','Ext.data.Store','store.clientstorage','Ext.data.ClientStore','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.proxy.Direct (proxy.direct)','Ext.data.proxy.Direct','Ext.data.proxy.Server','proxy.direct','Ext.data.proxy.Direct','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.DirectStore (store.direct)','Ext.data.DirectStore','Ext.data.Store','store.direct','Ext.data.DirectStore','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.proxy.JsonP (proxy.jsonp)','Ext.data.proxy.JsonP','Ext.data.proxy.Server','proxy.jsonp','Ext.data.proxy.JsonP','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.proxy.JsonP (proxy.scripttag)','Ext.data.proxy.JsonP','Ext.data.proxy.Server','proxy.scripttag','Ext.data.proxy.JsonP','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.JsonPStore (store.jsonp)','Ext.data.JsonPStore','Ext.data.Store','store.jsonp','Ext.data.JsonPStore','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.JsonStore (store.json)','Ext.data.JsonStore','Ext.data.Store','store.json','Ext.data.JsonStore','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.NodeStore (store.node)','Ext.data.NodeStore','Ext.data.Store','store.node','Ext.data.NodeStore','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.Query (query.default)','Ext.data.Query','Ext.util.BasicFilter','query.default','Ext.data.Query','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.TreeStore (store.tree)','Ext.data.TreeStore','Ext.data.Store','store.tree','Ext.data.TreeStore','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.reader.Xml (reader.xml)','Ext.data.reader.Xml','Ext.data.reader.Reader','reader.xml','Ext.data.reader.Xml','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.writer.Xml (writer.xml)','Ext.data.writer.Xml','Ext.data.writer.Writer','writer.xml','Ext.data.writer.Xml','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.XmlStore (store.xml)','Ext.data.XmlStore','Ext.data.Store','store.xml','Ext.data.XmlStore','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.identifier.Negative (data.identifier.negative)','Ext.data.identifier.Negative','Ext.data.identifier.Sequential','data.identifier.negative','Ext.data.identifier.Negative','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.identifier.Uuid (data.identifier.uuid)','Ext.data.identifier.Uuid','Ext.data.identifier.Generator','data.identifier.uuid','Ext.data.identifier.Uuid','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.proxy.LocalStorage (proxy.localstorage)','Ext.data.proxy.LocalStorage','Ext.data.proxy.WebStorage','proxy.localstorage','Ext.data.proxy.LocalStorage','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.proxy.Rest (proxy.rest)','Ext.data.proxy.Rest','Ext.data.proxy.Ajax','proxy.rest','Ext.data.proxy.Rest','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.proxy.SessionStorage (proxy.sessionstorage)','Ext.data.proxy.SessionStorage','Ext.data.proxy.WebStorage','proxy.sessionstorage','Ext.data.proxy.SessionStorage','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.summary.Base (data.summary.base)','Ext.data.summary.Base','Ext.Base','data.summary.base','Ext.data.summary.Base','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.summary.Sum (data.summary.sum)','Ext.data.summary.Sum','Ext.data.summary.Base','data.summary.sum','Ext.data.summary.Sum','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.summary.Average (data.summary.average)','Ext.data.summary.Average','Ext.data.summary.Sum','data.summary.average','Ext.data.summary.Average','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.summary.Count (data.summary.count)','Ext.data.summary.Count','Ext.data.summary.Base','data.summary.count','Ext.data.summary.Count','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.summary.Max (data.summary.max)','Ext.data.summary.Max','Ext.data.summary.Base','data.summary.max','Ext.data.summary.Max','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.summary.Min (data.summary.min)','Ext.data.summary.Min','Ext.data.summary.Base','data.summary.min','Ext.data.summary.Min','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.summary.None (data.summary.none)','Ext.data.summary.None','Ext.data.summary.Base','data.summary.none','Ext.data.summary.None','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.Bound (data.validator.bound)','Ext.data.validator.Bound','Ext.data.validator.Validator','data.validator.bound','Ext.data.validator.Bound','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.Format (data.validator.format)','Ext.data.validator.Format','Ext.data.validator.Validator','data.validator.format','Ext.data.validator.Format','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.CIDRv4 (data.validator.cidrv4)','Ext.data.validator.CIDRv4','Ext.data.validator.Format','data.validator.cidrv4','Ext.data.validator.CIDRv4','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.CIDRv6 (data.validator.cidrv6)','Ext.data.validator.CIDRv6','Ext.data.validator.Format','data.validator.cidrv6','Ext.data.validator.CIDRv6','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.Number (data.validator.number)','Ext.data.validator.Number','Ext.data.validator.Validator','data.validator.number','Ext.data.validator.Number','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.Currency (data.validator.currency)','Ext.data.validator.Currency','Ext.data.validator.Number','data.validator.currency','Ext.data.validator.Currency','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.CurrencyUS (data.validator.currency-us)','Ext.data.validator.CurrencyUS','Ext.data.validator.Currency','data.validator.currency-us','Ext.data.validator.CurrencyUS','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.Date (data.validator.date)','Ext.data.validator.Date','Ext.data.validator.AbstractDate','data.validator.date','Ext.data.validator.Date','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.DateTime (data.validator.datetime)','Ext.data.validator.DateTime','Ext.data.validator.AbstractDate','data.validator.datetime','Ext.data.validator.DateTime','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.Email (data.validator.email)','Ext.data.validator.Email','Ext.data.validator.Format','data.validator.email','Ext.data.validator.Email','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.List (data.validator.list)','Ext.data.validator.List','Ext.data.validator.Validator','data.validator.list','Ext.data.validator.List','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.Exclusion (data.validator.exclusion)','Ext.data.validator.Exclusion','Ext.data.validator.List','data.validator.exclusion','Ext.data.validator.Exclusion','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.IPAddress (data.validator.ipaddress)','Ext.data.validator.IPAddress','Ext.data.validator.Format','data.validator.ipaddress','Ext.data.validator.IPAddress','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.Inclusion (data.validator.inclusion)','Ext.data.validator.Inclusion','Ext.data.validator.List','data.validator.inclusion','Ext.data.validator.Inclusion','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.Length (data.validator.length)','Ext.data.validator.Length','Ext.data.validator.Bound','data.validator.length','Ext.data.validator.Length','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.Presence (data.validator.presence)','Ext.data.validator.Presence','Ext.data.validator.Validator','data.validator.presence','Ext.data.validator.Presence','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.NotNull (data.validator.notnull)','Ext.data.validator.NotNull','Ext.data.validator.Presence','data.validator.notnull','Ext.data.validator.NotNull','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.Phone (data.validator.phone)','Ext.data.validator.Phone','Ext.data.validator.Format','data.validator.phone','Ext.data.validator.Phone','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.Range (data.validator.range)','Ext.data.validator.Range','Ext.data.validator.Bound','data.validator.range','Ext.data.validator.Range','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.Time (data.validator.time)','Ext.data.validator.Time','Ext.data.validator.AbstractDate','data.validator.time','Ext.data.validator.Time','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.validator.Url (data.validator.url)','Ext.data.validator.Url','Ext.data.validator.Format','data.validator.url','Ext.data.validator.Url','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.data.virtual.Store (store.virtual)','Ext.data.virtual.Store','Ext.data.ProxyStore','store.virtual','Ext.data.virtual.Store','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.direct.Event (direct.event)','Ext.direct.Event','Ext.Base','direct.event','Ext.direct.Event','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.direct.RemotingEvent (direct.rpc)','Ext.direct.RemotingEvent','Ext.direct.Event','direct.rpc','Ext.direct.RemotingEvent','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.direct.ExceptionEvent (direct.exception)','Ext.direct.ExceptionEvent','Ext.direct.RemotingEvent','direct.exception','Ext.direct.ExceptionEvent','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.direct.JsonProvider (direct.jsonprovider)','Ext.direct.JsonProvider','Ext.direct.Provider','direct.jsonprovider','Ext.direct.JsonProvider','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.direct.PollingProvider (direct.pollingprovider)','Ext.direct.PollingProvider','Ext.direct.JsonProvider','direct.pollingprovider','Ext.direct.PollingProvider','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.direct.Transaction (direct.transaction)','Ext.direct.Transaction','Ext.Base','direct.transaction','Ext.direct.Transaction','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.direct.RemotingProvider (direct.remotingprovider)','Ext.direct.RemotingProvider','Ext.direct.JsonProvider','direct.remotingprovider','Ext.direct.RemotingProvider','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.drag.Constraint (drag.constraint.base)','Ext.drag.Constraint','Ext.Base','drag.constraint.base','Ext.drag.Constraint','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.drag.proxy.None (drag.proxy.none)','Ext.drag.proxy.None','Ext.Base','drag.proxy.none','Ext.drag.proxy.None','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.drag.proxy.Original (drag.proxy.original)','Ext.drag.proxy.Original','Ext.drag.proxy.None','drag.proxy.original','Ext.drag.proxy.Original','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.drag.proxy.Placeholder (drag.proxy.placeholder)','Ext.drag.proxy.Placeholder','Ext.drag.proxy.None','drag.proxy.placeholder','Ext.drag.proxy.Placeholder','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.fx.animation.Cube (animation.cube)','Ext.fx.animation.Cube','Ext.fx.animation.Abstract','animation.cube','Ext.fx.animation.Cube','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.fx.easing.EaseIn (easing.ease-in)','Ext.fx.easing.EaseIn','Ext.fx.easing.Linear','easing.ease-in','Ext.fx.easing.EaseIn','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.fx.easing.EaseOut (easing.ease-out)','Ext.fx.easing.EaseOut','Ext.fx.easing.Linear','easing.ease-out','Ext.fx.easing.EaseOut','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.list.TreeItem (widget.treelistitem)','Ext.list.TreeItem','Ext.list.AbstractTreeItem','widget.treelistitem','Ext.list.TreeItem','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.list.Tree (widget.treelist)','Ext.list.Tree','Ext.Component','widget.treelist','Ext.list.Tree','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.plugin.MouseEnter (plugin.mouseenter)','Ext.plugin.MouseEnter','Ext.plugin.Abstract','plugin.mouseenter','Ext.plugin.MouseEnter','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.sparkline.Base (widget.sparkline)','Ext.sparkline.Base','Ext.Component','widget.sparkline','Ext.sparkline.Base','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.sparkline.Bar (widget.sparklinebar)','Ext.sparkline.Bar','Ext.sparkline.BarBase','widget.sparklinebar','Ext.sparkline.Bar','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.sparkline.Box (widget.sparklinebox)','Ext.sparkline.Box','Ext.sparkline.Base','widget.sparklinebox','Ext.sparkline.Box','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.sparkline.Bullet (widget.sparklinebullet)','Ext.sparkline.Bullet','Ext.sparkline.Base','widget.sparklinebullet','Ext.sparkline.Bullet','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.sparkline.Discrete (widget.sparklinediscrete)','Ext.sparkline.Discrete','Ext.sparkline.BarBase','widget.sparklinediscrete','Ext.sparkline.Discrete','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.sparkline.Line (widget.sparklineline)','Ext.sparkline.Line','Ext.sparkline.Base','widget.sparklineline','Ext.sparkline.Line','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.sparkline.Pie (widget.sparklinepie)','Ext.sparkline.Pie','Ext.sparkline.Base','widget.sparklinepie','Ext.sparkline.Pie','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.sparkline.TriState (widget.sparklinetristate)','Ext.sparkline.TriState','Ext.sparkline.BarBase','widget.sparklinetristate','Ext.sparkline.TriState','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.util.translatable.ScrollParent (translatable.scrollparent)','Ext.util.translatable.ScrollParent','Ext.util.translatable.Dom','translatable.scrollparent','Ext.util.translatable.ScrollParent','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.util.translatable.ScrollPosition (translatable.scrollposition)','Ext.util.translatable.ScrollPosition','Ext.util.translatable.Dom','translatable.scrollposition','Ext.util.translatable.ScrollPosition','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Button (widget.button)','Ext.Button','Ext.Component','widget.button','Ext.Button','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Title (widget.title)','Ext.Title','Ext.Component','widget.title','Ext.Title','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Spacer (widget.spacer)','Ext.Spacer','Ext.Component','widget.spacer','Ext.Spacer','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.Box (layout.box)','Ext.layout.Box','Ext.layout.Auto','layout.box','Ext.layout.Box','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Toolbar (widget.toolbar)','Ext.Toolbar','Ext.Container','widget.toolbar','Ext.Toolbar','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Tool (widget.tool)','Ext.Tool','Ext.Component','widget.tool','Ext.Tool','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Tool (widget.paneltool)','Ext.Tool','Ext.Component','widget.paneltool','Ext.Tool','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Panel (widget.panel)','Ext.Panel','Ext.Container','widget.panel','Ext.Panel','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Mask (widget.mask)','Ext.Mask','Ext.Component','widget.mask','Ext.Mask','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Sheet (widget.sheet)','Ext.Sheet','Ext.Panel','widget.sheet','Ext.Sheet','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.ActionSheet (widget.actionsheet)','Ext.ActionSheet','Ext.Sheet','widget.actionsheet','Ext.ActionSheet','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Media (widget.media)','Ext.Media','Ext.Component','widget.media','Ext.Media','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Audio (widget.audio)','Ext.Audio','Ext.Media','widget.audio','Ext.Audio','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.menu.Item (widget.menuitem)','Ext.menu.Item','Ext.Component','widget.menuitem','Ext.menu.Item','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.VBox (layout.vbox)','Ext.layout.VBox','Ext.layout.Box','layout.vbox','Ext.layout.VBox','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.menu.Menu (widget.menu)','Ext.menu.Menu','Ext.Panel','widget.menu','Ext.menu.Menu','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.SplitButton (widget.splitbutton)','Ext.SplitButton','Ext.Button','widget.splitbutton','Ext.SplitButton','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.overflow.Scroller (layout.overflow.scroller)','Ext.layout.overflow.Scroller','Ext.Base','layout.overflow.scroller','Ext.layout.overflow.Scroller','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.BreadcrumbBar (widget.breadcrumbbar)','Ext.BreadcrumbBar','Ext.Toolbar','widget.breadcrumbbar','Ext.BreadcrumbBar','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Chip (widget.chip)','Ext.Chip','Ext.Component','widget.chip','Ext.Chip','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Dialog (widget.dialog)','Ext.Dialog','Ext.Panel','widget.dialog','Ext.Dialog','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Dialog (widget.window)','Ext.Dialog','Ext.Panel','widget.window','Ext.Dialog','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Field (widget.field)','Ext.field.Field','Ext.Component','widget.field','Ext.field.Field','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Input (widget.inputfield)','Ext.field.Input','Ext.field.Field','widget.inputfield','Ext.field.Input','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.Base (trigger.base)','Ext.field.trigger.Base','Ext.Widget','trigger.base','Ext.field.trigger.Base','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.Trigger (trigger.trigger)','Ext.field.trigger.Trigger','Ext.field.trigger.Base','trigger.trigger','Ext.field.trigger.Trigger','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.Trigger (widget.trigger)','Ext.field.trigger.Trigger','Ext.field.trigger.Base','widget.trigger','Ext.field.trigger.Trigger','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.Clear (trigger.clear)','Ext.field.trigger.Clear','Ext.field.trigger.Trigger','trigger.clear','Ext.field.trigger.Clear','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.Clear (widget.cleartrigger)','Ext.field.trigger.Clear','Ext.field.trigger.Trigger','widget.cleartrigger','Ext.field.trigger.Clear','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Text (widget.textfield)','Ext.field.Text','Ext.field.Input','widget.textfield','Ext.field.Text','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Editor (widget.editor)','Ext.Editor','Ext.Container','widget.editor','Ext.Editor','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Img (widget.image)','Ext.Img','Ext.Component','widget.image','Ext.Img','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Img (widget.img)','Ext.Img','Ext.Component','widget.img','Ext.Img','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Label (widget.label)','Ext.Label','Ext.Component','widget.label','Ext.Label','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.LoadMask (widget.loadmask)','Ext.LoadMask','Ext.Mask','widget.loadmask','Ext.LoadMask','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.TextArea (widget.textareafield)','Ext.field.TextArea','Ext.field.Text','widget.textareafield','Ext.field.TextArea','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.MessageBox (widget.messagebox)','Ext.MessageBox','Ext.Dialog','widget.messagebox','Ext.MessageBox','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.SegmentedButton (widget.segmentedbutton)','Ext.SegmentedButton','Ext.Container','widget.segmentedbutton','Ext.SegmentedButton','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.TitleBar (widget.titlebar)','Ext.TitleBar','Ext.Container','widget.titlebar','Ext.TitleBar','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.Video (widget.video)','Ext.Video','Ext.Media','widget.video','Ext.Video','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.carousel.Carousel (widget.carousel)','Ext.carousel.Carousel','Ext.Container','widget.carousel','Ext.carousel.Carousel','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.NavigationModel (navmodel.dataview)','Ext.dataview.NavigationModel','Ext.Evented','navmodel.dataview','Ext.dataview.NavigationModel','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.selection.Rows (selection.rows)','Ext.dataview.selection.Rows','Ext.dataview.selection.Selection','selection.rows','Ext.dataview.selection.Rows','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.selection.Records (selection.records)','Ext.dataview.selection.Records','Ext.dataview.selection.Rows','selection.records','Ext.dataview.selection.Records','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.selection.Model (selmodel.dataview)','Ext.dataview.selection.Model','Ext.Evented','selmodel.dataview','Ext.dataview.selection.Model','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.EmptyText (widget.emptytext)','Ext.dataview.EmptyText','Ext.Component','widget.emptytext','Ext.dataview.EmptyText','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.DataItem (widget.dataitem)','Ext.dataview.DataItem','Ext.Container','widget.dataitem','Ext.dataview.DataItem','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.Component (widget.componentdataview)','Ext.dataview.Component','Ext.dataview.Abstract','widget.componentdataview','Ext.dataview.Component','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.ItemHeader (widget.itemheader)','Ext.dataview.ItemHeader','Ext.Component','widget.itemheader','Ext.dataview.ItemHeader','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.SimpleListItem (widget.simplelistitem)','Ext.dataview.SimpleListItem','Ext.Component','widget.simplelistitem','Ext.dataview.SimpleListItem','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.ListItemPlaceholder (widget.listitemplaceholder)','Ext.dataview.ListItemPlaceholder','Ext.dataview.SimpleListItem','widget.listitemplaceholder','Ext.dataview.ListItemPlaceholder','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.List (widget.list)','Ext.dataview.List','Ext.dataview.Component','widget.list','Ext.dataview.List','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.BoundListNavigationModel (navmodel.boundlist)','Ext.dataview.BoundListNavigationModel','Ext.dataview.NavigationModel','navmodel.boundlist','Ext.dataview.BoundListNavigationModel','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.BoundList (widget.boundlist)','Ext.dataview.BoundList','Ext.dataview.List','widget.boundlist','Ext.dataview.BoundList','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.DataView (widget.dataview)','Ext.dataview.DataView','Ext.dataview.Abstract','widget.dataview','Ext.dataview.DataView','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.ChipView (widget.chipview)','Ext.dataview.ChipView','Ext.dataview.DataView','widget.chipview','Ext.dataview.ChipView','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.IndexBar (widget.indexbar)','Ext.dataview.IndexBar','Ext.Component','widget.indexbar','Ext.dataview.IndexBar','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.ListItem (widget.listitem)','Ext.dataview.ListItem','Ext.dataview.DataItem','widget.listitem','Ext.dataview.ListItem','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.HBox (layout.hbox)','Ext.layout.HBox','Ext.layout.Box','layout.hbox','Ext.layout.HBox','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.NestedList (widget.nestedlist)','Ext.dataview.NestedList','Ext.Container','widget.nestedlist','Ext.dataview.NestedList','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.listswiper.Item (widget.listswiperitem)','Ext.dataview.listswiper.Item','Ext.Container','widget.listswiperitem','Ext.dataview.listswiper.Item','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.listswiper.Accordion (widget.listswiperaccordion)','Ext.dataview.listswiper.Accordion','Ext.dataview.listswiper.Item','widget.listswiperaccordion','Ext.dataview.listswiper.Accordion','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.listswiper.ListSwiper (plugin.listswiper)','Ext.dataview.listswiper.ListSwiper','Ext.plugin.Abstract','plugin.listswiper','Ext.dataview.listswiper.ListSwiper','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.listswiper.Stepper (widget.listswiperstepper)','Ext.dataview.listswiper.Stepper','Ext.dataview.listswiper.Item','widget.listswiperstepper','Ext.dataview.listswiper.Stepper','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.tip.ToolTip (widget.tooltip)','Ext.tip.ToolTip','Ext.Panel','widget.tooltip','Ext.tip.ToolTip','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.plugin.ItemTip (plugin.dataviewtip)','Ext.dataview.plugin.ItemTip','Ext.tip.ToolTip','plugin.dataviewtip','Ext.dataview.plugin.ItemTip','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.plugin.ListPaging (plugin.listpaging)','Ext.dataview.plugin.ListPaging','Ext.plugin.Abstract','plugin.listpaging','Ext.dataview.plugin.ListPaging','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.plugin.SortableList (plugin.sortablelist)','Ext.dataview.plugin.SortableList','Ext.plugin.Abstract','plugin.sortablelist','Ext.dataview.plugin.SortableList','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.pullrefresh.Bar (widget.pullrefreshbar)','Ext.dataview.pullrefresh.Bar','Ext.dataview.pullrefresh.Item','widget.pullrefreshbar','Ext.dataview.pullrefresh.Bar','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.pullrefresh.PullRefresh (plugin.pullrefresh)','Ext.dataview.pullrefresh.PullRefresh','Ext.plugin.Abstract','plugin.pullrefresh','Ext.dataview.pullrefresh.PullRefresh','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.dataview.pullrefresh.Spinner (widget.pullrefreshspinner)','Ext.dataview.pullrefresh.Spinner','Ext.dataview.pullrefresh.Item','widget.pullrefreshspinner','Ext.dataview.pullrefresh.Spinner','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Checkbox (widget.checkbox)','Ext.field.Checkbox','Ext.field.Input','widget.checkbox','Ext.field.Checkbox','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Checkbox (widget.checkboxfield)','Ext.field.Checkbox','Ext.field.Input','widget.checkboxfield','Ext.field.Checkbox','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Container (widget.containerfield)','Ext.field.Container','Ext.field.Field','widget.containerfield','Ext.field.Container','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Container (widget.fieldcontainer)','Ext.field.Container','Ext.field.Field','widget.fieldcontainer','Ext.field.Container','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.FieldGroupContainer (widget.groupcontainer)','Ext.field.FieldGroupContainer','Ext.field.Container','widget.groupcontainer','Ext.field.FieldGroupContainer','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.CheckboxGroup (widget.checkboxgroup)','Ext.field.CheckboxGroup','Ext.field.FieldGroupContainer','widget.checkboxgroup','Ext.field.CheckboxGroup','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.ChipViewNavigationModel (navmodel.fieldchipview)','Ext.field.ChipViewNavigationModel','Ext.dataview.BoundListNavigationModel','navmodel.fieldchipview','Ext.field.ChipViewNavigationModel','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.Expand (trigger.expand)','Ext.field.trigger.Expand','Ext.field.trigger.Trigger','trigger.expand','Ext.field.trigger.Expand','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.Expand (widget.expandtrigger)','Ext.field.trigger.Expand','Ext.field.trigger.Trigger','widget.expandtrigger','Ext.field.trigger.Expand','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Picker (widget.pickerfield)','Ext.field.Picker','Ext.field.Text','widget.pickerfield','Ext.field.Picker','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.picker.Slot (widget.pickerslot)','Ext.picker.Slot','Ext.dataview.DataView','widget.pickerslot','Ext.picker.Slot','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.picker.Picker (widget.picker)','Ext.picker.Picker','Ext.Sheet','widget.picker','Ext.picker.Picker','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.picker.Tablet (widget.tabletpicker)','Ext.picker.Tablet','Ext.Panel','widget.tabletpicker','Ext.picker.Tablet','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.picker.SelectPicker (widget.selectpicker)','Ext.picker.SelectPicker','Ext.picker.Picker','widget.selectpicker','Ext.picker.SelectPicker','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Select (widget.selectfield)','Ext.field.Select','Ext.field.Picker','widget.selectfield','Ext.field.Select','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.ComboBox (widget.combobox)','Ext.field.ComboBox','Ext.field.Select','widget.combobox','Ext.field.ComboBox','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.ComboBox (widget.comboboxfield)','Ext.field.ComboBox','Ext.field.Select','widget.comboboxfield','Ext.field.ComboBox','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.Date (trigger.date)','Ext.field.trigger.Date','Ext.field.trigger.Expand','trigger.date','Ext.field.trigger.Date','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.Date (widget.datetrigger)','Ext.field.trigger.Date','Ext.field.trigger.Expand','widget.datetrigger','Ext.field.trigger.Date','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.picker.Date (widget.datepicker)','Ext.picker.Date','Ext.picker.Picker','widget.datepicker','Ext.picker.Date','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.Carousel (layout.carousel)','Ext.layout.Carousel','Ext.layout.Auto','layout.carousel','Ext.layout.Carousel','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.panel.DateView (widget.dateview)','Ext.panel.DateView','Ext.Widget','widget.dateview','Ext.panel.DateView','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.panel.Title (widget.paneltitle)','Ext.panel.Title','Ext.Component','widget.paneltitle','Ext.panel.Title','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.panel.DateTitle (widget.datetitle)','Ext.panel.DateTitle','Ext.panel.Title','widget.datetitle','Ext.panel.DateTitle','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.panel.YearPicker (widget.yearpicker)','Ext.panel.YearPicker','Ext.dataview.BoundList','widget.yearpicker','Ext.panel.YearPicker','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.panel.Date (widget.datepanel)','Ext.panel.Date','Ext.Panel','widget.datepanel','Ext.panel.Date','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Date (widget.datefield)','Ext.field.Date','Ext.field.Picker','widget.datefield','Ext.field.Date','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Date (widget.datepickerfield)','Ext.field.Date','Ext.field.Picker','widget.datepickerfield','Ext.field.Date','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.DatePickerNative (widget.datepickernativefield)','Ext.field.DatePickerNative','Ext.field.Date','widget.datepickernativefield','Ext.field.DatePickerNative','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Display (widget.displayfield)','Ext.field.Display','Ext.field.Field','widget.displayfield','Ext.field.Display','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Email (widget.emailfield)','Ext.field.Email','Ext.field.Text','widget.emailfield','Ext.field.Email','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.File (widget.filefield)','Ext.field.File','Ext.field.Text','widget.filefield','Ext.field.File','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.FileButton (widget.filebutton)','Ext.field.FileButton','Ext.Button','widget.filebutton','Ext.field.FileButton','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Hidden (widget.hiddenfield)','Ext.field.Hidden','Ext.field.Input','widget.hiddenfield','Ext.field.Hidden','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Number (widget.numberfield)','Ext.field.Number','Ext.field.Text','widget.numberfield','Ext.field.Number','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Panel (widget.fieldpanel)','Ext.field.Panel','Ext.Panel','widget.fieldpanel','Ext.field.Panel','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.Reveal (trigger.reveal)','Ext.field.trigger.Reveal','Ext.field.trigger.Trigger','trigger.reveal','Ext.field.trigger.Reveal','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.Reveal (widget.revealtrigger)','Ext.field.trigger.Reveal','Ext.field.trigger.Trigger','widget.revealtrigger','Ext.field.trigger.Reveal','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Password (widget.passwordfield)','Ext.field.Password','Ext.field.Text','widget.passwordfield','Ext.field.Password','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Radio (widget.radio)','Ext.field.Radio','Ext.field.Checkbox','widget.radio','Ext.field.Radio','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Radio (widget.radiofield)','Ext.field.Radio','Ext.field.Checkbox','widget.radiofield','Ext.field.Radio','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.RadioGroup (widget.radiogroup)','Ext.field.RadioGroup','Ext.field.FieldGroupContainer','widget.radiogroup','Ext.field.RadioGroup','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.Search (trigger.search)','Ext.field.trigger.Search','Ext.field.trigger.Trigger','trigger.search','Ext.field.trigger.Search','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.Search (widget.searchtrigger)','Ext.field.trigger.Search','Ext.field.trigger.Trigger','widget.searchtrigger','Ext.field.trigger.Search','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Search (widget.searchfield)','Ext.field.Search','Ext.field.Text','widget.searchfield','Ext.field.Search','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.slider.Thumb (widget.thumb)','Ext.slider.Thumb','Ext.Component','widget.thumb','Ext.slider.Thumb','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.slider.Slider (widget.slider)','Ext.slider.Slider','Ext.Component','widget.slider','Ext.slider.Slider','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Slider (widget.sliderfield)','Ext.field.Slider','Ext.field.Field','widget.sliderfield','Ext.field.Slider','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.SingleSlider (widget.singlesliderfield)','Ext.field.SingleSlider','Ext.field.Slider','widget.singlesliderfield','Ext.field.SingleSlider','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.SpinDown (trigger.spindown)','Ext.field.trigger.SpinDown','Ext.field.trigger.Trigger','trigger.spindown','Ext.field.trigger.SpinDown','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.SpinDown (widget.spindowntrigger)','Ext.field.trigger.SpinDown','Ext.field.trigger.Trigger','widget.spindowntrigger','Ext.field.trigger.SpinDown','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.SpinUp (trigger.spinup)','Ext.field.trigger.SpinUp','Ext.field.trigger.Trigger','trigger.spinup','Ext.field.trigger.SpinUp','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.SpinUp (widget.spinuptrigger)','Ext.field.trigger.SpinUp','Ext.field.trigger.Trigger','widget.spinuptrigger','Ext.field.trigger.SpinUp','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Spinner (widget.spinnerfield)','Ext.field.Spinner','Ext.field.Number','widget.spinnerfield','Ext.field.Spinner','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.Time (trigger.time)','Ext.field.trigger.Time','Ext.field.trigger.Expand','trigger.time','Ext.field.trigger.Time','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.Time (widget.timetrigger)','Ext.field.trigger.Time','Ext.field.trigger.Expand','widget.timetrigger','Ext.field.trigger.Time','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.panel.TimeHeader (widget.analogtimeheader)','Ext.panel.TimeHeader','Ext.Component','widget.analogtimeheader','Ext.panel.TimeHeader','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.panel.TimeView (widget.analogtime)','Ext.panel.TimeView','Ext.Panel','widget.analogtime','Ext.panel.TimeView','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.panel.Time (widget.timepanel)','Ext.panel.Time','Ext.Panel','widget.timepanel','Ext.panel.Time','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Time (widget.timefield)','Ext.field.Time','Ext.field.Picker','widget.timefield','Ext.field.Time','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.slider.Toggle (widget.toggleslider)','Ext.slider.Toggle','Ext.slider.Slider','widget.toggleslider','Ext.slider.Toggle','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Toggle (widget.togglefield)','Ext.field.Toggle','Ext.field.SingleSlider','widget.togglefield','Ext.field.Toggle','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.Url (widget.urlfield)','Ext.field.Url','Ext.field.Text','widget.urlfield','Ext.field.Url','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.Component (trigger.component)','Ext.field.trigger.Component','Ext.field.trigger.Base','trigger.component','Ext.field.trigger.Component','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.File (trigger.file)','Ext.field.trigger.File','Ext.field.trigger.Component','trigger.file','Ext.field.trigger.File','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.Menu (trigger.menu)','Ext.field.trigger.Menu','Ext.field.trigger.Trigger','trigger.menu','Ext.field.trigger.Menu','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.field.trigger.Menu (widget.menutrigger)','Ext.field.trigger.Menu','Ext.field.trigger.Trigger','widget.menutrigger','Ext.field.trigger.Menu','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.form.FieldSet (widget.fieldset)','Ext.form.FieldSet','Ext.Container','widget.fieldset','Ext.form.FieldSet','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.form.Panel (widget.formpanel)','Ext.form.Panel','Ext.field.Panel','widget.formpanel','Ext.form.Panel','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.CellEditor (widget.celleditor)','Ext.grid.CellEditor','Ext.Editor','widget.celleditor','Ext.grid.CellEditor','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.NavigationModel (navmodel.grid)','Ext.grid.NavigationModel','Ext.dataview.NavigationModel','navmodel.grid','Ext.grid.NavigationModel','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.cell.Base (widget.gridcellbase)','Ext.grid.cell.Base','Ext.Widget','widget.gridcellbase','Ext.grid.cell.Base','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.cell.Text (widget.textcell)','Ext.grid.cell.Text','Ext.grid.cell.Base','widget.textcell','Ext.grid.cell.Text','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.cell.Cell (widget.gridcell)','Ext.grid.cell.Cell','Ext.grid.cell.Text','widget.gridcell','Ext.grid.cell.Cell','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.RowBody (widget.rowbody)','Ext.grid.RowBody','Ext.Component','widget.rowbody','Ext.grid.RowBody','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.Row (widget.gridrow)','Ext.grid.Row','Ext.Component','widget.gridrow','Ext.grid.Row','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.HeaderContainer (widget.headercontainer)','Ext.grid.HeaderContainer','Ext.Container','widget.headercontainer','Ext.grid.HeaderContainer','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.menu.CheckItem (widget.menucheckitem)','Ext.menu.CheckItem','Ext.menu.Item','widget.menucheckitem','Ext.menu.CheckItem','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.column.Column (widget.gridcolumn)','Ext.grid.column.Column','Ext.grid.HeaderContainer','widget.gridcolumn','Ext.grid.column.Column','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.column.Column (widget.column)','Ext.grid.column.Column','Ext.grid.HeaderContainer','widget.column','Ext.grid.column.Column','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.column.Column (widget.templatecolumn)','Ext.grid.column.Column','Ext.grid.HeaderContainer','widget.templatecolumn','Ext.grid.column.Column','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.cell.Date (widget.datecell)','Ext.grid.cell.Date','Ext.grid.cell.Text','widget.datecell','Ext.grid.cell.Date','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.column.Date (widget.datecolumn)','Ext.grid.column.Date','Ext.grid.column.Column','widget.datecolumn','Ext.grid.column.Date','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.menu.Columns (widget.gridcolumnsmenu)','Ext.grid.menu.Columns','Ext.grid.menu.Shared','widget.gridcolumnsmenu','Ext.grid.menu.Columns','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.menu.GroupByThis (widget.gridgroupbythismenuitem)','Ext.grid.menu.GroupByThis','Ext.menu.Item','widget.gridgroupbythismenuitem','Ext.grid.menu.GroupByThis','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.menu.ShowInGroups (widget.gridshowingroupsmenuitem)','Ext.grid.menu.ShowInGroups','Ext.menu.CheckItem','widget.gridshowingroupsmenuitem','Ext.grid.menu.ShowInGroups','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.menu.RadioItem (widget.menuradioitem)','Ext.menu.RadioItem','Ext.menu.CheckItem','widget.menuradioitem','Ext.menu.RadioItem','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.menu.SortAsc (widget.gridsortascmenuitem)','Ext.grid.menu.SortAsc','Ext.menu.RadioItem','widget.gridsortascmenuitem','Ext.grid.menu.SortAsc','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.menu.SortDesc (widget.gridsortdescmenuitem)','Ext.grid.menu.SortDesc','Ext.menu.RadioItem','widget.gridsortdescmenuitem','Ext.grid.menu.SortDesc','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.selection.Cells (selection.cells)','Ext.grid.selection.Cells','Ext.dataview.selection.Selection','selection.cells','Ext.grid.selection.Cells','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.selection.Columns (selection.columns)','Ext.grid.selection.Columns','Ext.dataview.selection.Selection','selection.columns','Ext.grid.selection.Columns','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.selection.Replicator (plugin.selectionreplicator)','Ext.grid.selection.Replicator','Ext.plugin.Abstract','plugin.selectionreplicator','Ext.grid.selection.Replicator','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.cell.Number (widget.numbercell)','Ext.grid.cell.Number','Ext.grid.cell.Text','widget.numbercell','Ext.grid.cell.Number','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.cell.Check (widget.checkcell)','Ext.grid.cell.Check','Ext.grid.cell.Base','widget.checkcell','Ext.grid.cell.Check','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.column.Check (widget.checkcolumn)','Ext.grid.column.Check','Ext.grid.column.Column','widget.checkcolumn','Ext.grid.column.Check','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.column.Selection (widget.selectioncolumn)','Ext.grid.column.Selection','Ext.grid.column.Check','widget.selectioncolumn','Ext.grid.column.Selection','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.column.Number (widget.numbercolumn)','Ext.grid.column.Number','Ext.grid.column.Column','widget.numbercolumn','Ext.grid.column.Number','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.cell.RowNumberer (widget.rownumberercell)','Ext.grid.cell.RowNumberer','Ext.grid.cell.Number','widget.rownumberercell','Ext.grid.cell.RowNumberer','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.column.RowNumberer (widget.rownumberer)','Ext.grid.column.RowNumberer','Ext.grid.column.Number','widget.rownumberer','Ext.grid.column.RowNumberer','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.selection.Model (selmodel.grid)','Ext.grid.selection.Model','Ext.dataview.selection.Model','selmodel.grid','Ext.grid.selection.Model','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.plugin.ColumnResizing (plugin.columnresizing)','Ext.grid.plugin.ColumnResizing','Ext.Component','plugin.columnresizing','Ext.grid.plugin.ColumnResizing','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.plugin.ColumnResizing (plugin.gridcolumnresizing)','Ext.grid.plugin.ColumnResizing','Ext.Component','plugin.gridcolumnresizing','Ext.grid.plugin.ColumnResizing','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.plugin.dd.DragDrop (plugin.viewdragdrop)','Ext.plugin.dd.DragDrop','Ext.plugin.Abstract','plugin.viewdragdrop','Ext.plugin.dd.DragDrop','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.plugin.HeaderReorder (plugin.headerreorder)','Ext.grid.plugin.HeaderReorder','Ext.plugin.dd.DragDrop','plugin.headerreorder','Ext.grid.plugin.HeaderReorder','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.RowHeader (widget.rowheader)','Ext.grid.RowHeader','Ext.dataview.ItemHeader','widget.rowheader','Ext.grid.RowHeader','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.Grid (widget.grid)','Ext.grid.Grid','Ext.dataview.List','widget.grid','Ext.grid.Grid','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.PagingToolbar (widget.pagingtoolbar)','Ext.grid.PagingToolbar','Ext.Toolbar','widget.pagingtoolbar','Ext.grid.PagingToolbar','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.SummaryRow (widget.gridsummaryrow)','Ext.grid.SummaryRow','Ext.grid.Row','widget.gridsummaryrow','Ext.grid.SummaryRow','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.cell.Boolean (widget.booleancell)','Ext.grid.cell.Boolean','Ext.grid.cell.Text','widget.booleancell','Ext.grid.cell.Boolean','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.cell.Expander (widget.expandercell)','Ext.grid.cell.Expander','Ext.grid.cell.Base','widget.expandercell','Ext.grid.cell.Expander','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.cell.Widget (widget.widgetcell)','Ext.grid.cell.Widget','Ext.grid.cell.Base','widget.widgetcell','Ext.grid.cell.Widget','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.column.Boolean (widget.booleancolumn)','Ext.grid.column.Boolean','Ext.grid.column.Column','widget.booleancolumn','Ext.grid.column.Boolean','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.column.Drag (widget.dragcolumn)','Ext.grid.column.Drag','Ext.grid.column.Column','widget.dragcolumn','Ext.grid.column.Drag','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.column.Text (widget.textcolumn)','Ext.grid.column.Text','Ext.grid.column.Column','widget.textcolumn','Ext.grid.column.Text','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.filters.menu.Boolean (gridFilters.boolean)','Ext.grid.filters.menu.Boolean','Ext.grid.filters.menu.Base','gridFilters.boolean','Ext.grid.filters.menu.Boolean','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.filters.menu.Date (gridFilters.date)','Ext.grid.filters.menu.Date','Ext.grid.filters.menu.Base','gridFilters.date','Ext.grid.filters.menu.Date','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.filters.menu.Number (gridFilters.number)','Ext.grid.filters.menu.Number','Ext.grid.filters.menu.Base','gridFilters.number','Ext.grid.filters.menu.Number','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.filters.menu.String (gridFilters.string)','Ext.grid.filters.menu.String','Ext.grid.filters.menu.Base','gridFilters.string','Ext.grid.filters.menu.String','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.filters.Plugin (plugin.gridfilters)','Ext.grid.filters.Plugin','Ext.plugin.Abstract','plugin.gridfilters','Ext.grid.filters.Plugin','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.Fit (layout.fit)','Ext.layout.Fit','Ext.layout.Auto','layout.fit','Ext.layout.Fit','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.locked.Grid (widget.lockedgrid)','Ext.grid.locked.Grid','Ext.Panel','widget.lockedgrid','Ext.grid.locked.Grid','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.locked.Region (widget.lockedgridregion)','Ext.grid.locked.Region','Ext.Panel','widget.lockedgridregion','Ext.grid.locked.Region','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.plugin.CellEditing (plugin.gridcellediting)','Ext.grid.plugin.CellEditing','Ext.plugin.Abstract','plugin.gridcellediting','Ext.grid.plugin.CellEditing','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.plugin.CellEditing (plugin.cellediting)','Ext.grid.plugin.CellEditing','Ext.plugin.Abstract','plugin.cellediting','Ext.grid.plugin.CellEditing','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.plugin.Clipboard (plugin.clipboard)','Ext.grid.plugin.Clipboard','Ext.plugin.AbstractClipboard','plugin.clipboard','Ext.grid.plugin.Clipboard','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.plugin.Editable (plugin.grideditable)','Ext.grid.plugin.Editable','Ext.plugin.Abstract','plugin.grideditable','Ext.grid.plugin.Editable','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.plugin.PagingToolbar (plugin.pagingtoolbar)','Ext.grid.plugin.PagingToolbar','Ext.plugin.Abstract','plugin.pagingtoolbar','Ext.grid.plugin.PagingToolbar','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.plugin.PagingToolbar (plugin.gridpagingtoolbar)','Ext.grid.plugin.PagingToolbar','Ext.plugin.Abstract','plugin.gridpagingtoolbar','Ext.grid.plugin.PagingToolbar','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.plugin.RowDragDrop (plugin.gridrowdragdrop)','Ext.grid.plugin.RowDragDrop','Ext.plugin.dd.DragDrop','plugin.gridrowdragdrop','Ext.grid.plugin.RowDragDrop','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.plugin.RowExpander (plugin.rowexpander)','Ext.grid.plugin.RowExpander','Ext.plugin.Abstract','plugin.rowexpander','Ext.grid.plugin.RowExpander','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.plugin.RowOperations (plugin.rowoperations)','Ext.grid.plugin.RowOperations','Ext.plugin.Abstract','plugin.rowoperations','Ext.grid.plugin.RowOperations','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.plugin.RowOperations (plugin.multiselection)','Ext.grid.plugin.RowOperations','Ext.plugin.Abstract','plugin.multiselection','Ext.grid.plugin.RowOperations','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.plugin.RowOperations (plugin.gridmultiselection)','Ext.grid.plugin.RowOperations','Ext.plugin.Abstract','plugin.gridmultiselection','Ext.grid.plugin.RowOperations','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.plugin.Summary (plugin.gridsummary)','Ext.grid.plugin.Summary','Ext.plugin.Abstract','plugin.gridsummary','Ext.grid.plugin.Summary','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.plugin.Summary (plugin.summaryrow)','Ext.grid.plugin.Summary','Ext.plugin.Abstract','plugin.summaryrow','Ext.grid.plugin.Summary','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.plugin.Summary (plugin.gridsummaryrow)','Ext.grid.plugin.Summary','Ext.plugin.Abstract','plugin.gridsummaryrow','Ext.grid.plugin.Summary','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.plugin.ViewOptionsListItem (widget.viewoptionslistitem)','Ext.grid.plugin.ViewOptionsListItem','Ext.dataview.SimpleListItem','widget.viewoptionslistitem','Ext.grid.plugin.ViewOptionsListItem','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.plugin.ViewOptions (plugin.gridviewoptions)','Ext.grid.plugin.ViewOptions','Ext.plugin.Abstract','plugin.gridviewoptions','Ext.grid.plugin.ViewOptions','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.rowedit.Bar (widget.roweditorbar)','Ext.grid.rowedit.Bar','Ext.Panel','widget.roweditorbar','Ext.grid.rowedit.Bar','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.rowedit.Cell (widget.roweditorcell)','Ext.grid.rowedit.Cell','Ext.Component','widget.roweditorcell','Ext.grid.rowedit.Cell','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.plugin.TabGuard (plugin.tabguard)','Ext.plugin.TabGuard','Ext.plugin.Abstract','plugin.tabguard','Ext.plugin.TabGuard','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.rowedit.Editor (widget.roweditor)','Ext.grid.rowedit.Editor','Ext.dataview.ListItem','widget.roweditor','Ext.grid.rowedit.Editor','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.rowedit.Gap (widget.roweditorgap)','Ext.grid.rowedit.Gap','Ext.Component','widget.roweditorgap','Ext.grid.rowedit.Gap','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.rowedit.Plugin (plugin.rowedit)','Ext.grid.rowedit.Plugin','Ext.plugin.Abstract','plugin.rowedit','Ext.grid.rowedit.Plugin','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.Center (layout.center)','Ext.layout.Center','Ext.layout.Auto','layout.center','Ext.layout.Center','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.Float (layout.float)','Ext.layout.Float','Ext.layout.Auto','layout.float','Ext.layout.Float','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.layout.Form (layout.form)','Ext.layout.Form','Ext.layout.Auto','layout.form','Ext.layout.Form','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.menu.Separator (widget.menuseparator)','Ext.menu.Separator','Ext.Component','widget.menuseparator','Ext.menu.Separator','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.navigation.View (widget.navigationview)','Ext.navigation.View','Ext.Container','widget.navigationview','Ext.navigation.View','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.panel.Accordion (widget.accordion)','Ext.panel.Accordion','Ext.Panel','widget.accordion','Ext.panel.Accordion','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.panel.Header (widget.panelheader)','Ext.panel.Header','Ext.Container','widget.panelheader','Ext.panel.Header','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.plugin.Responsive (plugin.responsive)','Ext.plugin.Responsive','Ext.plugin.Abstract','plugin.responsive','Ext.plugin.Responsive','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.scroll.NativeScroller (scroller.native)','Ext.scroll.NativeScroller','Ext.scroll.Scroller','scroller.native','Ext.scroll.NativeScroller','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.scroll.indicator.Indicator (scrollindicator.indicator)','Ext.scroll.indicator.Indicator','Ext.Widget','scrollindicator.indicator','Ext.scroll.indicator.Indicator','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.scroll.indicator.Bar (scrollindicator.bar)','Ext.scroll.indicator.Bar','Ext.scroll.indicator.Indicator','scrollindicator.bar','Ext.scroll.indicator.Bar','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.scroll.indicator.Overlay (scrollindicator.overlay)','Ext.scroll.indicator.Overlay','Ext.scroll.indicator.Indicator','scrollindicator.overlay','Ext.scroll.indicator.Overlay','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.scroll.VirtualScroller (scroller.virtual)','Ext.scroll.VirtualScroller','Ext.scroll.Scroller','scroller.virtual','Ext.scroll.VirtualScroller','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.tab.Tab (widget.tab)','Ext.tab.Tab','Ext.Button','widget.tab','Ext.tab.Tab','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.tab.Bar (widget.tabbar)','Ext.tab.Bar','Ext.Toolbar','widget.tabbar','Ext.tab.Bar','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.tab.Panel (widget.tabpanel)','Ext.tab.Panel','Ext.Container','widget.tabpanel','Ext.tab.Panel','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.util.translatable.Component (translatable.component)','Ext.util.translatable.Component','Ext.util.translatable.CssTransform','translatable.component','Ext.util.translatable.Component','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.Tree (widget.tree)','Ext.grid.Tree','Ext.grid.Grid','widget.tree','Ext.grid.Tree','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.cell.Tree (widget.treecell)','Ext.grid.cell.Tree','Ext.grid.cell.Cell','widget.treecell','Ext.grid.cell.Tree','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.column.Tree (widget.treecolumn)','Ext.grid.column.Tree','Ext.grid.column.Column','widget.treecolumn','Ext.grid.column.Tree','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_modern,name,vendor) values ('Ext.grid.plugin.TreeDragDrop (plugin.treedragdrop)','Ext.grid.plugin.TreeDragDrop','Ext.plugin.dd.DragDrop','plugin.treedragdrop','Ext.grid.plugin.TreeDragDrop','Sencha ExtJS') on duplicate key update xtype_long_modern=values(xtype_long_modern);


-- classic
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.Widget (widget.widget)','Ext.Widget','Ext.Evented','widget.widget','Ext.Widget','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.Progress (widget.progress)','Ext.Progress','Ext.Widget','widget.progress','Ext.Progress','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.Progress (widget.progressbarwidget)','Ext.Progress','Ext.Widget','widget.progressbarwidget','Ext.Progress','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.fx.easing.Linear (easing.linear)','Ext.fx.easing.Linear','Ext.fx.easing.Abstract','easing.linear','Ext.fx.easing.Linear','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.util.translatable.Dom (translatable.dom)','Ext.util.translatable.Dom','Ext.util.translatable.Abstract','translatable.dom','Ext.util.translatable.Dom','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.util.translatable.ScrollPosition (translatable.scrollposition)','Ext.util.translatable.ScrollPosition','Ext.util.translatable.Dom','translatable.scrollposition','Ext.util.translatable.ScrollPosition','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.scroll.Scroller (scroller.scroller)','Ext.scroll.Scroller','Ext.Evented','scroller.scroller','Ext.scroll.Scroller','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.Component (widget.box)','Ext.Component','Ext.Base','widget.box','Ext.Component','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.Component (widget.component)','Ext.Component','Ext.Base','widget.component','Ext.Component','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.Base (widget.field)','Ext.form.field.Base','Ext.Component','widget.field','Ext.form.field.Base','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.component.Auto (layout.autocomponent)','Ext.layout.component.Auto','Ext.layout.component.Component','layout.autocomponent','Ext.layout.component.Auto','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.component.field.Text (layout.textfield)','Ext.layout.component.field.Text','Ext.layout.component.Auto','layout.textfield','Ext.layout.component.field.Text','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.trigger.Trigger (trigger.trigger)','Ext.form.trigger.Trigger','Ext.Base','trigger.trigger','Ext.form.trigger.Trigger','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.Text (widget.textfield)','Ext.form.field.Text','Ext.form.field.Base','widget.textfield','Ext.form.field.Text','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.Picker (widget.pickerfield)','Ext.form.field.Picker','Ext.form.field.Text','widget.pickerfield','Ext.form.field.Picker','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.schema.Namer (namer.default)','Ext.data.schema.Namer','Ext.Base','namer.default','Ext.data.schema.Namer','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.schema.Schema (schema.default)','Ext.data.schema.Schema','Ext.Base','schema.default','Ext.data.schema.Schema','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.operation.Create (data.operation.create)','Ext.data.operation.Create','Ext.data.operation.Operation','data.operation.create','Ext.data.operation.Create','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.operation.Destroy (data.operation.destroy)','Ext.data.operation.Destroy','Ext.data.operation.Operation','data.operation.destroy','Ext.data.operation.Destroy','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.operation.Read (data.operation.read)','Ext.data.operation.Read','Ext.data.operation.Operation','data.operation.read','Ext.data.operation.Read','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.operation.Update (data.operation.update)','Ext.data.operation.Update','Ext.data.operation.Operation','data.operation.update','Ext.data.operation.Update','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.Validator (data.validator.base)','Ext.data.validator.Validator','Ext.Base','data.validator.base','Ext.data.validator.Validator','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.summary.Base (data.summary.base)','Ext.data.summary.Base','Ext.Base','data.summary.base','Ext.data.summary.Base','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.field.Field (data.field.auto)','Ext.data.field.Field','Ext.Base','data.field.auto','Ext.data.field.Field','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.field.Array (data.field.array)','Ext.data.field.Array','Ext.data.field.Field','data.field.array','Ext.data.field.Array','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.field.Boolean (data.field.bool)','Ext.data.field.Boolean','Ext.data.field.Field','data.field.bool','Ext.data.field.Boolean','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.field.Boolean (data.field.boolean)','Ext.data.field.Boolean','Ext.data.field.Field','data.field.boolean','Ext.data.field.Boolean','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.field.Date (data.field.date)','Ext.data.field.Date','Ext.data.field.Field','data.field.date','Ext.data.field.Date','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.field.Integer (data.field.int)','Ext.data.field.Integer','Ext.data.field.Field','data.field.int','Ext.data.field.Integer','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.field.Integer (data.field.integer)','Ext.data.field.Integer','Ext.data.field.Field','data.field.integer','Ext.data.field.Integer','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.field.Number (data.field.float)','Ext.data.field.Number','Ext.data.field.Integer','data.field.float','Ext.data.field.Number','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.field.Number (data.field.number)','Ext.data.field.Number','Ext.data.field.Integer','data.field.number','Ext.data.field.Number','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.field.String (data.field.string)','Ext.data.field.String','Ext.data.field.Field','data.field.string','Ext.data.field.String','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.identifier.Generator (data.identifier.default)','Ext.data.identifier.Generator','Ext.Base','data.identifier.default','Ext.data.identifier.Generator','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.identifier.Sequential (data.identifier.sequential)','Ext.data.identifier.Sequential','Ext.data.identifier.Generator','data.identifier.sequential','Ext.data.identifier.Sequential','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.reader.Reader (reader.base)','Ext.data.reader.Reader','Ext.Base','reader.base','Ext.data.reader.Reader','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.writer.Writer (writer.base)','Ext.data.writer.Writer','Ext.Base','writer.base','Ext.data.writer.Writer','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.proxy.Proxy (proxy.proxy)','Ext.data.proxy.Proxy','Ext.Base','proxy.proxy','Ext.data.proxy.Proxy','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.proxy.Memory (proxy.memory)','Ext.data.proxy.Memory','Ext.data.proxy.Client','proxy.memory','Ext.data.proxy.Memory','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.proxy.Server (proxy.server)','Ext.data.proxy.Server','Ext.data.proxy.Proxy','proxy.server','Ext.data.proxy.Server','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.proxy.Ajax (proxy.ajax)','Ext.data.proxy.Ajax','Ext.data.proxy.Server','proxy.ajax','Ext.data.proxy.Ajax','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.reader.Json (reader.json)','Ext.data.reader.Json','Ext.data.reader.Reader','reader.json','Ext.data.reader.Json','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.writer.Json (writer.json)','Ext.data.writer.Json','Ext.data.writer.Writer','writer.json','Ext.data.writer.Json','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.Store (store.store)','Ext.data.Store','Ext.data.ProxyStore','store.store','Ext.data.Store','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.reader.Array (reader.array)','Ext.data.reader.Array','Ext.data.reader.Json','reader.array','Ext.data.reader.Array','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.ArrayStore (store.array)','Ext.data.ArrayStore','Ext.data.Store','store.array','Ext.data.ArrayStore','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.selection.Model (selection.abstract)','Ext.selection.Model','Ext.mixin.Observable','selection.abstract','Ext.selection.Model','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.selection.DataViewModel (selection.dataviewmodel)','Ext.selection.DataViewModel','Ext.selection.Model','selection.dataviewmodel','Ext.selection.DataViewModel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.view.NavigationModel (view.navigation.default)','Ext.view.NavigationModel','Ext.Base','view.navigation.default','Ext.view.NavigationModel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.view.View (widget.dataview)','Ext.view.View','Ext.view.AbstractView','widget.dataview','Ext.view.View','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.view.BoundListKeyNav (view.navigation.boundlist)','Ext.view.BoundListKeyNav','Ext.view.NavigationModel','view.navigation.boundlist','Ext.view.BoundListKeyNav','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.component.BoundList (layout.boundlist)','Ext.layout.component.BoundList','Ext.layout.component.Auto','layout.boundlist','Ext.layout.component.BoundList','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.Container (layout.container)','Ext.layout.container.Container','Ext.layout.Layout','layout.container','Ext.layout.container.Container','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.Auto (layout.auto)','Ext.layout.container.Auto','Ext.layout.container.Container','layout.auto','Ext.layout.container.Auto','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.Auto (layout.autocontainer)','Ext.layout.container.Auto','Ext.layout.container.Container','layout.autocontainer','Ext.layout.container.Auto','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.container.Container (widget.container)','Ext.container.Container','Ext.Component','widget.container','Ext.container.Container','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.boxOverflow.None (box.overflow.None)','Ext.layout.container.boxOverflow.None','Ext.Base','box.overflow.None','Ext.layout.container.boxOverflow.None','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.boxOverflow.None (box.overflow.none)','Ext.layout.container.boxOverflow.None','Ext.Base','box.overflow.none','Ext.layout.container.boxOverflow.None','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.resizer.Splitter (widget.splitter)','Ext.resizer.Splitter','Ext.Component','widget.splitter','Ext.resizer.Splitter','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.Box (layout.box)','Ext.layout.container.Box','Ext.layout.container.Container','layout.box','Ext.layout.container.Box','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.HBox (layout.hbox)','Ext.layout.container.HBox','Ext.layout.container.Box','layout.hbox','Ext.layout.container.HBox','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.VBox (layout.vbox)','Ext.layout.container.VBox','Ext.layout.container.Box','layout.vbox','Ext.layout.container.VBox','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.toolbar.Item (widget.tbitem)','Ext.toolbar.Item','Ext.Component','widget.tbitem','Ext.toolbar.Item','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.toolbar.TextItem (widget.tbtext)','Ext.toolbar.TextItem','Ext.toolbar.Item','widget.tbtext','Ext.toolbar.TextItem','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.trigger.Spinner (trigger.spinner)','Ext.form.trigger.Spinner','Ext.form.trigger.Trigger','trigger.spinner','Ext.form.trigger.Spinner','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.Spinner (widget.spinnerfield)','Ext.form.field.Spinner','Ext.form.field.Text','widget.spinnerfield','Ext.form.field.Spinner','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.Number (widget.numberfield)','Ext.form.field.Number','Ext.form.field.Spinner','widget.numberfield','Ext.form.field.Number','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.toolbar.Paging (widget.pagingtoolbar)','Ext.toolbar.Paging','Ext.toolbar.Toolbar','widget.pagingtoolbar','Ext.toolbar.Paging','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.view.BoundList (widget.boundlist)','Ext.view.BoundList','Ext.view.View','widget.boundlist','Ext.view.BoundList','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.ComboBox (widget.combo)','Ext.form.field.ComboBox','Ext.form.field.Picker','widget.combo','Ext.form.field.ComboBox','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.ComboBox (widget.combobox)','Ext.form.field.ComboBox','Ext.form.field.Picker','widget.combobox','Ext.form.field.ComboBox','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.component.field.FieldContainer (layout.fieldcontainer)','Ext.layout.component.field.FieldContainer','Ext.layout.component.Auto','layout.fieldcontainer','Ext.layout.component.field.FieldContainer','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.FieldContainer (widget.fieldcontainer)','Ext.form.FieldContainer','Ext.container.Container','widget.fieldcontainer','Ext.form.FieldContainer','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.panel.Title (widget.title)','Ext.panel.Title','Ext.Component','widget.title','Ext.panel.Title','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.panel.Tool (widget.tool)','Ext.panel.Tool','Ext.Component','widget.tool','Ext.panel.Tool','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.panel.Header (widget.header)','Ext.panel.Header','Ext.panel.Bar','widget.header','Ext.panel.Header','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.component.Dock (layout.dock)','Ext.layout.component.Dock','Ext.layout.component.Component','layout.dock','Ext.layout.component.Dock','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.panel.Panel (widget.panel)','Ext.panel.Panel','Ext.container.Container','widget.panel','Ext.panel.Panel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.tip.Tip (widget.tip)','Ext.tip.Tip','Ext.panel.Panel','widget.tip','Ext.tip.Tip','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.tip.ToolTip (widget.tooltip)','Ext.tip.ToolTip','Ext.tip.Tip','widget.tooltip','Ext.tip.ToolTip','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.tip.QuickTip (widget.quicktip)','Ext.tip.QuickTip','Ext.tip.ToolTip','widget.quicktip','Ext.tip.QuickTip','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.picker.Color (widget.colorpicker)','Ext.picker.Color','Ext.Component','widget.colorpicker','Ext.picker.Color','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.component.field.HtmlEditor (layout.htmleditor)','Ext.layout.component.field.HtmlEditor','Ext.layout.component.field.FieldContainer','layout.htmleditor','Ext.layout.component.field.HtmlEditor','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.toolbar.Separator (widget.tbseparator)','Ext.toolbar.Separator','Ext.toolbar.Item','widget.tbseparator','Ext.toolbar.Separator','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.button.Button (widget.button)','Ext.button.Button','Ext.Component','widget.button','Ext.button.Button','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.boxOverflow.Menu (box.overflow.Menu)','Ext.layout.container.boxOverflow.Menu','Ext.layout.container.boxOverflow.None','box.overflow.Menu','Ext.layout.container.boxOverflow.Menu','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.boxOverflow.Menu (box.overflow.menu)','Ext.layout.container.boxOverflow.Menu','Ext.layout.container.boxOverflow.None','box.overflow.menu','Ext.layout.container.boxOverflow.Menu','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.HtmlEditor (widget.htmleditor)','Ext.form.field.HtmlEditor','Ext.form.FieldContainer','widget.htmleditor','Ext.form.field.HtmlEditor','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.app.ViewController (controller.controller)','Ext.app.ViewController','Ext.app.BaseController','controller.controller','Ext.app.ViewController','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.ChainedStore (store.chained)','Ext.data.ChainedStore','Ext.data.AbstractStore','store.chained','Ext.data.ChainedStore','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.app.ViewModel (viewmodel.default)','Ext.app.ViewModel','Ext.Base','viewmodel.default','Ext.app.ViewModel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.direct.Provider (direct.provider)','Ext.direct.Provider','Ext.Base','direct.provider','Ext.direct.Provider','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.BufferedStore (store.buffered)','Ext.data.BufferedStore','Ext.data.ProxyStore','store.buffered','Ext.data.BufferedStore','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.ClientStore (store.clientstorage)','Ext.data.ClientStore','Ext.data.Store','store.clientstorage','Ext.data.ClientStore','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.proxy.Direct (proxy.direct)','Ext.data.proxy.Direct','Ext.data.proxy.Server','proxy.direct','Ext.data.proxy.Direct','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.DirectStore (store.direct)','Ext.data.DirectStore','Ext.data.Store','store.direct','Ext.data.DirectStore','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.proxy.JsonP (proxy.jsonp)','Ext.data.proxy.JsonP','Ext.data.proxy.Server','proxy.jsonp','Ext.data.proxy.JsonP','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.proxy.JsonP (proxy.scripttag)','Ext.data.proxy.JsonP','Ext.data.proxy.Server','proxy.scripttag','Ext.data.proxy.JsonP','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.JsonPStore (store.jsonp)','Ext.data.JsonPStore','Ext.data.Store','store.jsonp','Ext.data.JsonPStore','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.JsonStore (store.json)','Ext.data.JsonStore','Ext.data.Store','store.json','Ext.data.JsonStore','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.NodeStore (store.node)','Ext.data.NodeStore','Ext.data.Store','store.node','Ext.data.NodeStore','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.Query (query.default)','Ext.data.Query','Ext.util.BasicFilter','query.default','Ext.data.Query','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.TreeStore (store.tree)','Ext.data.TreeStore','Ext.data.Store','store.tree','Ext.data.TreeStore','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.reader.Xml (reader.xml)','Ext.data.reader.Xml','Ext.data.reader.Reader','reader.xml','Ext.data.reader.Xml','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.writer.Xml (writer.xml)','Ext.data.writer.Xml','Ext.data.writer.Writer','writer.xml','Ext.data.writer.Xml','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.XmlStore (store.xml)','Ext.data.XmlStore','Ext.data.Store','store.xml','Ext.data.XmlStore','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.identifier.Negative (data.identifier.negative)','Ext.data.identifier.Negative','Ext.data.identifier.Sequential','data.identifier.negative','Ext.data.identifier.Negative','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.identifier.Uuid (data.identifier.uuid)','Ext.data.identifier.Uuid','Ext.data.identifier.Generator','data.identifier.uuid','Ext.data.identifier.Uuid','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.proxy.LocalStorage (proxy.localstorage)','Ext.data.proxy.LocalStorage','Ext.data.proxy.WebStorage','proxy.localstorage','Ext.data.proxy.LocalStorage','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.proxy.Rest (proxy.rest)','Ext.data.proxy.Rest','Ext.data.proxy.Ajax','proxy.rest','Ext.data.proxy.Rest','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.proxy.SessionStorage (proxy.sessionstorage)','Ext.data.proxy.SessionStorage','Ext.data.proxy.WebStorage','proxy.sessionstorage','Ext.data.proxy.SessionStorage','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.summary.Sum (data.summary.sum)','Ext.data.summary.Sum','Ext.data.summary.Base','data.summary.sum','Ext.data.summary.Sum','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.summary.Average (data.summary.average)','Ext.data.summary.Average','Ext.data.summary.Sum','data.summary.average','Ext.data.summary.Average','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.summary.Count (data.summary.count)','Ext.data.summary.Count','Ext.data.summary.Base','data.summary.count','Ext.data.summary.Count','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.summary.Max (data.summary.max)','Ext.data.summary.Max','Ext.data.summary.Base','data.summary.max','Ext.data.summary.Max','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.summary.Min (data.summary.min)','Ext.data.summary.Min','Ext.data.summary.Base','data.summary.min','Ext.data.summary.Min','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.summary.None (data.summary.none)','Ext.data.summary.None','Ext.data.summary.Base','data.summary.none','Ext.data.summary.None','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.summary.Variance (data.summary.variance)','Ext.data.summary.Variance','Ext.data.summary.Base','data.summary.variance','Ext.data.summary.Variance','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.summary.StdDev (data.summary.stddev)','Ext.data.summary.StdDev','Ext.data.summary.Variance','data.summary.stddev','Ext.data.summary.StdDev','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.summary.VarianceP (data.summary.variancep)','Ext.data.summary.VarianceP','Ext.data.summary.Variance','data.summary.variancep','Ext.data.summary.VarianceP','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.summary.StdDevP (data.summary.stddevp)','Ext.data.summary.StdDevP','Ext.data.summary.VarianceP','data.summary.stddevp','Ext.data.summary.StdDevP','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.Bound (data.validator.bound)','Ext.data.validator.Bound','Ext.data.validator.Validator','data.validator.bound','Ext.data.validator.Bound','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.Format (data.validator.format)','Ext.data.validator.Format','Ext.data.validator.Validator','data.validator.format','Ext.data.validator.Format','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.CIDRv4 (data.validator.cidrv4)','Ext.data.validator.CIDRv4','Ext.data.validator.Format','data.validator.cidrv4','Ext.data.validator.CIDRv4','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.CIDRv6 (data.validator.cidrv6)','Ext.data.validator.CIDRv6','Ext.data.validator.Format','data.validator.cidrv6','Ext.data.validator.CIDRv6','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.Number (data.validator.number)','Ext.data.validator.Number','Ext.data.validator.Validator','data.validator.number','Ext.data.validator.Number','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.Currency (data.validator.currency)','Ext.data.validator.Currency','Ext.data.validator.Number','data.validator.currency','Ext.data.validator.Currency','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.CurrencyUS (data.validator.currency-us)','Ext.data.validator.CurrencyUS','Ext.data.validator.Currency','data.validator.currency-us','Ext.data.validator.CurrencyUS','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.Date (data.validator.date)','Ext.data.validator.Date','Ext.data.validator.AbstractDate','data.validator.date','Ext.data.validator.Date','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.DateTime (data.validator.datetime)','Ext.data.validator.DateTime','Ext.data.validator.AbstractDate','data.validator.datetime','Ext.data.validator.DateTime','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.Email (data.validator.email)','Ext.data.validator.Email','Ext.data.validator.Format','data.validator.email','Ext.data.validator.Email','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.List (data.validator.list)','Ext.data.validator.List','Ext.data.validator.Validator','data.validator.list','Ext.data.validator.List','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.Exclusion (data.validator.exclusion)','Ext.data.validator.Exclusion','Ext.data.validator.List','data.validator.exclusion','Ext.data.validator.Exclusion','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.IPAddress (data.validator.ipaddress)','Ext.data.validator.IPAddress','Ext.data.validator.Format','data.validator.ipaddress','Ext.data.validator.IPAddress','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.Inclusion (data.validator.inclusion)','Ext.data.validator.Inclusion','Ext.data.validator.List','data.validator.inclusion','Ext.data.validator.Inclusion','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.Length (data.validator.length)','Ext.data.validator.Length','Ext.data.validator.Bound','data.validator.length','Ext.data.validator.Length','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.Presence (data.validator.presence)','Ext.data.validator.Presence','Ext.data.validator.Validator','data.validator.presence','Ext.data.validator.Presence','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.NotNull (data.validator.notnull)','Ext.data.validator.NotNull','Ext.data.validator.Presence','data.validator.notnull','Ext.data.validator.NotNull','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.Phone (data.validator.phone)','Ext.data.validator.Phone','Ext.data.validator.Format','data.validator.phone','Ext.data.validator.Phone','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.Range (data.validator.range)','Ext.data.validator.Range','Ext.data.validator.Bound','data.validator.range','Ext.data.validator.Range','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.Time (data.validator.time)','Ext.data.validator.Time','Ext.data.validator.AbstractDate','data.validator.time','Ext.data.validator.Time','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.validator.Url (data.validator.url)','Ext.data.validator.Url','Ext.data.validator.Format','data.validator.url','Ext.data.validator.Url','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.data.virtual.Store (store.virtual)','Ext.data.virtual.Store','Ext.data.ProxyStore','store.virtual','Ext.data.virtual.Store','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.direct.Event (direct.event)','Ext.direct.Event','Ext.Base','direct.event','Ext.direct.Event','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.direct.RemotingEvent (direct.rpc)','Ext.direct.RemotingEvent','Ext.direct.Event','direct.rpc','Ext.direct.RemotingEvent','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.direct.ExceptionEvent (direct.exception)','Ext.direct.ExceptionEvent','Ext.direct.RemotingEvent','direct.exception','Ext.direct.ExceptionEvent','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.direct.JsonProvider (direct.jsonprovider)','Ext.direct.JsonProvider','Ext.direct.Provider','direct.jsonprovider','Ext.direct.JsonProvider','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.direct.PollingProvider (direct.pollingprovider)','Ext.direct.PollingProvider','Ext.direct.JsonProvider','direct.pollingprovider','Ext.direct.PollingProvider','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.direct.Transaction (direct.transaction)','Ext.direct.Transaction','Ext.Base','direct.transaction','Ext.direct.Transaction','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.direct.RemotingProvider (direct.remotingprovider)','Ext.direct.RemotingProvider','Ext.direct.JsonProvider','direct.remotingprovider','Ext.direct.RemotingProvider','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.drag.Constraint (drag.constraint.base)','Ext.drag.Constraint','Ext.Base','drag.constraint.base','Ext.drag.Constraint','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.drag.proxy.None (drag.proxy.none)','Ext.drag.proxy.None','Ext.Base','drag.proxy.none','Ext.drag.proxy.None','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.drag.proxy.Original (drag.proxy.original)','Ext.drag.proxy.Original','Ext.drag.proxy.None','drag.proxy.original','Ext.drag.proxy.Original','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.drag.proxy.Placeholder (drag.proxy.placeholder)','Ext.drag.proxy.Placeholder','Ext.drag.proxy.None','drag.proxy.placeholder','Ext.drag.proxy.Placeholder','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.fx.animation.Slide (animation.slide)','Ext.fx.animation.Slide','Ext.fx.animation.Abstract','animation.slide','Ext.fx.animation.Slide','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.fx.animation.Slide (animation.slideIn)','Ext.fx.animation.Slide','Ext.fx.animation.Abstract','animation.slideIn','Ext.fx.animation.Slide','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.fx.animation.SlideOut (animation.slideOut)','Ext.fx.animation.SlideOut','Ext.fx.animation.Slide','animation.slideOut','Ext.fx.animation.SlideOut','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.fx.animation.Fade (animation.fade)','Ext.fx.animation.Fade','Ext.fx.animation.Abstract','animation.fade','Ext.fx.animation.Fade','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.fx.animation.Fade (animation.fadeIn)','Ext.fx.animation.Fade','Ext.fx.animation.Abstract','animation.fadeIn','Ext.fx.animation.Fade','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.fx.animation.FadeOut (animation.fadeOut)','Ext.fx.animation.FadeOut','Ext.fx.animation.Fade','animation.fadeOut','Ext.fx.animation.FadeOut','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.fx.animation.Flip (animation.flip)','Ext.fx.animation.Flip','Ext.fx.animation.Abstract','animation.flip','Ext.fx.animation.Flip','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.fx.animation.Pop (animation.pop)','Ext.fx.animation.Pop','Ext.fx.animation.Abstract','animation.pop','Ext.fx.animation.Pop','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.fx.animation.Pop (animation.popIn)','Ext.fx.animation.Pop','Ext.fx.animation.Abstract','animation.popIn','Ext.fx.animation.Pop','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.fx.animation.PopOut (animation.popOut)','Ext.fx.animation.PopOut','Ext.fx.animation.Pop','animation.popOut','Ext.fx.animation.PopOut','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.fx.animation.Cube (animation.cube)','Ext.fx.animation.Cube','Ext.fx.animation.Abstract','animation.cube','Ext.fx.animation.Cube','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.fx.easing.EaseIn (easing.ease-in)','Ext.fx.easing.EaseIn','Ext.fx.easing.Linear','easing.ease-in','Ext.fx.easing.EaseIn','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.fx.easing.EaseOut (easing.ease-out)','Ext.fx.easing.EaseOut','Ext.fx.easing.Linear','easing.ease-out','Ext.fx.easing.EaseOut','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.list.TreeItem (widget.treelistitem)','Ext.list.TreeItem','Ext.list.AbstractTreeItem','widget.treelistitem','Ext.list.TreeItem','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.list.Tree (widget.treelist)','Ext.list.Tree','Ext.Widget','widget.treelist','Ext.list.Tree','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.plugin.MouseEnter (plugin.mouseenter)','Ext.plugin.MouseEnter','Ext.plugin.Abstract','plugin.mouseenter','Ext.plugin.MouseEnter','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.sparkline.Base (widget.sparkline)','Ext.sparkline.Base','Ext.Widget','widget.sparkline','Ext.sparkline.Base','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.sparkline.Bar (widget.sparklinebar)','Ext.sparkline.Bar','Ext.sparkline.BarBase','widget.sparklinebar','Ext.sparkline.Bar','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.sparkline.Box (widget.sparklinebox)','Ext.sparkline.Box','Ext.sparkline.Base','widget.sparklinebox','Ext.sparkline.Box','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.sparkline.Bullet (widget.sparklinebullet)','Ext.sparkline.Bullet','Ext.sparkline.Base','widget.sparklinebullet','Ext.sparkline.Bullet','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.sparkline.Discrete (widget.sparklinediscrete)','Ext.sparkline.Discrete','Ext.sparkline.BarBase','widget.sparklinediscrete','Ext.sparkline.Discrete','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.sparkline.Line (widget.sparklineline)','Ext.sparkline.Line','Ext.sparkline.Base','widget.sparklineline','Ext.sparkline.Line','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.sparkline.Pie (widget.sparklinepie)','Ext.sparkline.Pie','Ext.sparkline.Base','widget.sparklinepie','Ext.sparkline.Pie','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.sparkline.TriState (widget.sparklinetristate)','Ext.sparkline.TriState','Ext.sparkline.BarBase','widget.sparklinetristate','Ext.sparkline.TriState','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.util.translatable.CssPosition (translatable.cssposition)','Ext.util.translatable.CssPosition','Ext.util.translatable.Dom','translatable.cssposition','Ext.util.translatable.CssPosition','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.util.translatable.CssTransform (translatable.csstransform)','Ext.util.translatable.CssTransform','Ext.util.translatable.Dom','translatable.csstransform','Ext.util.translatable.CssTransform','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.util.translatable.ScrollParent (translatable.scrollparent)','Ext.util.translatable.ScrollParent','Ext.util.translatable.Dom','translatable.scrollparent','Ext.util.translatable.ScrollParent','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.Editor (layout.editor)','Ext.layout.container.Editor','Ext.layout.container.Container','layout.editor','Ext.layout.container.Editor','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.Editor (widget.editor)','Ext.Editor','Ext.container.Container','widget.editor','Ext.Editor','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.Img (widget.image)','Ext.Img','Ext.Component','widget.image','Ext.Img','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.Img (widget.imagecomponent)','Ext.Img','Ext.Component','widget.imagecomponent','Ext.Img','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.component.ProgressBar (layout.progressbar)','Ext.layout.component.ProgressBar','Ext.layout.component.Auto','layout.progressbar','Ext.layout.component.ProgressBar','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ProgressBar (widget.progressbar)','Ext.ProgressBar','Ext.Component','widget.progressbar','Ext.ProgressBar','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.button.Split (widget.splitbutton)','Ext.button.Split','Ext.button.Button','widget.splitbutton','Ext.button.Split','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.SegmentedButton (layout.segmentedbutton)','Ext.layout.container.SegmentedButton','Ext.layout.container.Container','layout.segmentedbutton','Ext.layout.container.SegmentedButton','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.button.Segmented (widget.segmentedbutton)','Ext.button.Segmented','Ext.container.Container','widget.segmentedbutton','Ext.button.Segmented','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.Table (layout.table)','Ext.layout.container.Table','Ext.layout.container.Container','layout.table','Ext.layout.container.Table','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.container.ButtonGroup (widget.buttongroup)','Ext.container.ButtonGroup','Ext.panel.Panel','widget.buttongroup','Ext.container.ButtonGroup','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.plugin.Viewport (plugin.viewport)','Ext.plugin.Viewport','Ext.plugin.Abstract','plugin.viewport','Ext.plugin.Viewport','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.container.Viewport (widget.viewport)','Ext.container.Viewport','Ext.container.Container','widget.viewport','Ext.container.Viewport','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.Anchor (layout.anchor)','Ext.layout.container.Anchor','Ext.layout.container.Auto','layout.anchor','Ext.layout.container.Anchor','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.dashboard.Panel (widget.dashboard-panel)','Ext.dashboard.Panel','Ext.panel.Panel','widget.dashboard-panel','Ext.dashboard.Panel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.dashboard.Column (widget.dashboard-column)','Ext.dashboard.Column','Ext.container.Container','widget.dashboard-column','Ext.dashboard.Column','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.Column (layout.column)','Ext.layout.container.Column','Ext.layout.container.Auto','layout.column','Ext.layout.container.Column','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.ColumnSplitter (widget.columnsplitter)','Ext.layout.container.ColumnSplitter','Ext.resizer.Splitter','widget.columnsplitter','Ext.layout.container.ColumnSplitter','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.Dashboard (layout.dashboard)','Ext.layout.container.Dashboard','Ext.layout.container.Column','layout.dashboard','Ext.layout.container.Dashboard','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.dashboard.Part (part.part)','Ext.dashboard.Part','Ext.Base','part.part','Ext.dashboard.Part','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.dashboard.Dashboard (widget.dashboard)','Ext.dashboard.Dashboard','Ext.panel.Panel','widget.dashboard','Ext.dashboard.Dashboard','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.flash.Component (widget.flash)','Ext.flash.Component','Ext.Component','widget.flash','Ext.flash.Component','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.window.Window (widget.window)','Ext.window.Window','Ext.panel.Panel','widget.window','Ext.window.Window','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.TextArea (widget.textarea)','Ext.form.field.TextArea','Ext.form.field.Text','widget.textarea','Ext.form.field.TextArea','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.TextArea (widget.textareafield)','Ext.form.field.TextArea','Ext.form.field.Text','widget.textareafield','Ext.form.field.TextArea','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.window.MessageBox (widget.messagebox)','Ext.window.MessageBox','Ext.window.Window','widget.messagebox','Ext.window.MessageBox','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.CheckboxGroup (layout.checkboxgroup)','Ext.layout.container.CheckboxGroup','Ext.layout.container.Container','layout.checkboxgroup','Ext.layout.container.CheckboxGroup','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.Checkbox (widget.checkbox)','Ext.form.field.Checkbox','Ext.form.field.Base','widget.checkbox','Ext.form.field.Checkbox','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.Checkbox (widget.checkboxfield)','Ext.form.field.Checkbox','Ext.form.field.Base','widget.checkboxfield','Ext.form.field.Checkbox','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.CheckboxGroup (widget.checkboxgroup)','Ext.form.CheckboxGroup','Ext.form.FieldContainer','widget.checkboxgroup','Ext.form.CheckboxGroup','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.FieldSet (widget.fieldset)','Ext.form.FieldSet','Ext.container.Container','widget.fieldset','Ext.form.FieldSet','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.Label (widget.label)','Ext.form.Label','Ext.Component','widget.label','Ext.form.Label','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.Panel (widget.form)','Ext.form.Panel','Ext.panel.Panel','widget.form','Ext.form.Panel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.Radio (widget.radio)','Ext.form.field.Radio','Ext.form.field.Checkbox','widget.radio','Ext.form.field.Radio','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.Radio (widget.radiofield)','Ext.form.field.Radio','Ext.form.field.Checkbox','widget.radiofield','Ext.form.field.Radio','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.RadioGroup (widget.radiogroup)','Ext.form.RadioGroup','Ext.form.CheckboxGroup','widget.radiogroup','Ext.form.RadioGroup','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.picker.Month (widget.monthpicker)','Ext.picker.Month','Ext.Component','widget.monthpicker','Ext.picker.Month','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.picker.Date (widget.datepicker)','Ext.picker.Date','Ext.Component','widget.datepicker','Ext.picker.Date','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.Date (widget.datefield)','Ext.form.field.Date','Ext.form.field.Picker','widget.datefield','Ext.form.field.Date','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.Display (widget.displayfield)','Ext.form.field.Display','Ext.form.field.Base','widget.displayfield','Ext.form.field.Display','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.FileButton (widget.filebutton)','Ext.form.field.FileButton','Ext.button.Button','widget.filebutton','Ext.form.field.FileButton','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.trigger.Component (trigger.component)','Ext.form.trigger.Component','Ext.form.trigger.Trigger','trigger.component','Ext.form.trigger.Component','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.File (widget.filefield)','Ext.form.field.File','Ext.form.field.Text','widget.filefield','Ext.form.field.File','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.File (widget.fileuploadfield)','Ext.form.field.File','Ext.form.field.Text','widget.fileuploadfield','Ext.form.field.File','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.Hidden (widget.hidden)','Ext.form.field.Hidden','Ext.form.field.Base','widget.hidden','Ext.form.field.Hidden','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.Hidden (widget.hiddenfield)','Ext.form.field.Hidden','Ext.form.field.Base','widget.hiddenfield','Ext.form.field.Hidden','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.view.TagKeyNav (view.navigation.tagfield)','Ext.view.TagKeyNav','Ext.view.BoundListKeyNav','view.navigation.tagfield','Ext.view.TagKeyNav','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.Tag (widget.tagfield)','Ext.form.field.Tag','Ext.form.field.ComboBox','widget.tagfield','Ext.form.field.Tag','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.picker.Time (widget.timepicker)','Ext.picker.Time','Ext.view.BoundList','widget.timepicker','Ext.picker.Time','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.Time (widget.timefield)','Ext.form.field.Time','Ext.form.field.ComboBox','widget.timefield','Ext.form.field.Time','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.Trigger (widget.trigger)','Ext.form.field.Trigger','Ext.form.field.Text','widget.trigger','Ext.form.field.Trigger','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.form.field.Trigger (widget.triggerfield)','Ext.form.field.Trigger','Ext.form.field.Text','widget.triggerfield','Ext.form.field.Trigger','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.CellEditor (widget.celleditor)','Ext.grid.CellEditor','Ext.Editor','widget.celleditor','Ext.grid.CellEditor','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.ColumnComponentLayout (layout.columncomponent)','Ext.grid.ColumnComponentLayout','Ext.layout.component.Auto','layout.columncomponent','Ext.grid.ColumnComponentLayout','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.Fit (layout.fit)','Ext.layout.container.Fit','Ext.layout.container.Container','layout.fit','Ext.layout.container.Fit','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.ColumnLayout (layout.gridcolumn)','Ext.grid.ColumnLayout','Ext.layout.container.HBox','layout.gridcolumn','Ext.grid.ColumnLayout','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.NavigationModel (view.navigation.grid)','Ext.grid.NavigationModel','Ext.view.NavigationModel','view.navigation.grid','Ext.grid.NavigationModel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.view.TableLayout (layout.tableview)','Ext.view.TableLayout','Ext.layout.component.Auto','layout.tableview','Ext.view.TableLayout','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.scroll.TableScroller (scroller.table)','Ext.scroll.TableScroller','Ext.scroll.Scroller','scroller.table','Ext.scroll.TableScroller','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.Panel (widget.grid)','Ext.grid.Panel','Ext.panel.Table','widget.grid','Ext.grid.Panel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.Panel (widget.gridpanel)','Ext.grid.Panel','Ext.panel.Table','widget.gridpanel','Ext.grid.Panel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.plugin.HeaderResizer (plugin.gridheaderresizer)','Ext.grid.plugin.HeaderResizer','Ext.plugin.Abstract','plugin.gridheaderresizer','Ext.grid.plugin.HeaderResizer','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.plugin.HeaderReorderer (plugin.gridheaderreorderer)','Ext.grid.plugin.HeaderReorderer','Ext.plugin.Abstract','plugin.gridheaderreorderer','Ext.grid.plugin.HeaderReorderer','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.header.Container (widget.headercontainer)','Ext.grid.header.Container','Ext.container.Container','widget.headercontainer','Ext.grid.header.Container','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.column.Column (widget.gridcolumn)','Ext.grid.column.Column','Ext.grid.header.Container','widget.gridcolumn','Ext.grid.column.Column','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.column.Action (widget.actioncolumn)','Ext.grid.column.Action','Ext.grid.column.Column','widget.actioncolumn','Ext.grid.column.Action','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.column.Boolean (widget.booleancolumn)','Ext.grid.column.Boolean','Ext.grid.column.Column','widget.booleancolumn','Ext.grid.column.Boolean','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.column.Check (widget.checkcolumn)','Ext.grid.column.Check','Ext.grid.column.Column','widget.checkcolumn','Ext.grid.column.Check','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.column.Date (widget.datecolumn)','Ext.grid.column.Date','Ext.grid.column.Column','widget.datecolumn','Ext.grid.column.Date','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.column.Groups (widget.groupscolumn)','Ext.grid.column.Groups','Ext.grid.column.Column','widget.groupscolumn','Ext.grid.column.Groups','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.column.Number (widget.numbercolumn)','Ext.grid.column.Number','Ext.grid.column.Column','widget.numbercolumn','Ext.grid.column.Number','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.column.RowNumberer (widget.rownumberer)','Ext.grid.column.RowNumberer','Ext.grid.column.Column','widget.rownumberer','Ext.grid.column.RowNumberer','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.column.Widget (widget.widgetcolumn)','Ext.grid.column.Widget','Ext.grid.column.Column','widget.widgetcolumn','Ext.grid.column.Widget','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.feature.Feature (feature.feature)','Ext.grid.feature.Feature','Ext.util.Observable','feature.feature','Ext.grid.feature.Feature','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.feature.AbstractSummary (feature.abstractsummary)','Ext.grid.feature.AbstractSummary','Ext.grid.feature.Feature','feature.abstractsummary','Ext.grid.feature.AbstractSummary','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.feature.AdvancedGrouping (feature.advancedgrouping)','Ext.grid.feature.AdvancedGrouping','Ext.grid.feature.Feature','feature.advancedgrouping','Ext.grid.feature.AdvancedGrouping','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.feature.AdvancedGroupingSummary (feature.advancedgroupingsummary)','Ext.grid.feature.AdvancedGroupingSummary','Ext.grid.feature.AdvancedGrouping','feature.advancedgroupingsummary','Ext.grid.feature.AdvancedGroupingSummary','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.feature.Grouping (feature.grouping)','Ext.grid.feature.Grouping','Ext.grid.feature.Feature','feature.grouping','Ext.grid.feature.Grouping','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.feature.GroupingSummary (feature.groupingsummary)','Ext.grid.feature.GroupingSummary','Ext.grid.feature.Grouping','feature.groupingsummary','Ext.grid.feature.GroupingSummary','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.feature.RowBody (feature.rowbody)','Ext.grid.feature.RowBody','Ext.grid.feature.Feature','feature.rowbody','Ext.grid.feature.RowBody','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.feature.Summary (feature.summary)','Ext.grid.feature.Summary','Ext.grid.feature.AbstractSummary','feature.summary','Ext.grid.feature.Summary','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.menu.Item (widget.menuitem)','Ext.menu.Item','Ext.Component','widget.menuitem','Ext.menu.Item','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.menu.CheckItem (widget.menucheckitem)','Ext.menu.CheckItem','Ext.menu.Item','widget.menucheckitem','Ext.menu.CheckItem','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.menu.Separator (widget.menuseparator)','Ext.menu.Separator','Ext.menu.Item','widget.menuseparator','Ext.menu.Separator','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.menu.Menu (widget.menu)','Ext.menu.Menu','Ext.panel.Panel','widget.menu','Ext.menu.Menu','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.filters.Filters (plugin.gridfilters)','Ext.grid.filters.Filters','Ext.plugin.Abstract','plugin.gridfilters','Ext.grid.filters.Filters','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.scroll.LockingScroller (scroller.locking)','Ext.scroll.LockingScroller','Ext.scroll.Scroller','scroller.locking','Ext.scroll.LockingScroller','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.plugin.BufferedRenderer (plugin.bufferedrenderer)','Ext.grid.plugin.BufferedRenderer','Ext.plugin.Abstract','plugin.bufferedrenderer','Ext.grid.plugin.BufferedRenderer','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.plugin.Editing (editing.editing)','Ext.grid.plugin.Editing','Ext.plugin.Abstract','editing.editing','Ext.grid.plugin.Editing','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.plugin.CellEditing (plugin.cellediting)','Ext.grid.plugin.CellEditing','Ext.grid.plugin.Editing','plugin.cellediting','Ext.grid.plugin.CellEditing','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.plugin.Clipboard (plugin.clipboard)','Ext.grid.plugin.Clipboard','Ext.plugin.AbstractClipboard','plugin.clipboard','Ext.grid.plugin.Clipboard','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.plugin.DragDrop (plugin.gridviewdragdrop)','Ext.grid.plugin.DragDrop','Ext.plugin.Abstract','plugin.gridviewdragdrop','Ext.grid.plugin.DragDrop','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.plugin.grouping.Column (widget.groupingpanelcolumn)','Ext.grid.plugin.grouping.Column','Ext.Component','widget.groupingpanelcolumn','Ext.grid.plugin.grouping.Column','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.plugin.grouping.Panel (widget.groupingpanel)','Ext.grid.plugin.grouping.Panel','Ext.panel.Panel','widget.groupingpanel','Ext.grid.plugin.grouping.Panel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.plugin.GroupingPanel (plugin.groupingpanel)','Ext.grid.plugin.GroupingPanel','Ext.grid.plugin.BaseGroupingPanel','plugin.groupingpanel','Ext.grid.plugin.GroupingPanel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.plugin.RowEditing (plugin.rowediting)','Ext.grid.plugin.RowEditing','Ext.grid.plugin.Editing','plugin.rowediting','Ext.grid.plugin.RowEditing','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.plugin.RowExpander (plugin.rowexpander)','Ext.grid.plugin.RowExpander','Ext.plugin.Abstract','plugin.rowexpander','Ext.grid.plugin.RowExpander','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.plugin.RowWidget (plugin.rowwidget)','Ext.grid.plugin.RowWidget','Ext.grid.plugin.RowExpander','plugin.rowwidget','Ext.grid.plugin.RowWidget','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.plugin.Summaries (plugin.gridsummaries)','Ext.grid.plugin.Summaries','Ext.grid.plugin.BaseSummaries','plugin.gridsummaries','Ext.grid.plugin.Summaries','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.plugin.filterbar.Operator (plugin.operator)','Ext.grid.plugin.filterbar.Operator','Ext.plugin.Abstract','plugin.operator','Ext.grid.plugin.filterbar.Operator','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.plugin.filterbar.FilterBar (plugin.gridfilterbar)','Ext.grid.plugin.filterbar.FilterBar','Ext.grid.plugin.BaseFilterBar','plugin.gridfilterbar','Ext.grid.plugin.filterbar.FilterBar','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.property.Grid (widget.propertygrid)','Ext.grid.property.Grid','Ext.grid.Panel','widget.propertygrid','Ext.grid.property.Grid','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.selection.Replicator (plugin.selectionreplicator)','Ext.grid.selection.Replicator','Ext.plugin.Abstract','plugin.selectionreplicator','Ext.grid.selection.Replicator','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.selection.SpreadsheetModel (selection.spreadsheet)','Ext.grid.selection.SpreadsheetModel','Ext.selection.Model','selection.spreadsheet','Ext.grid.selection.SpreadsheetModel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.component.Body (layout.body)','Ext.layout.component.Body','Ext.layout.component.Auto','layout.body','Ext.layout.component.Body','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.component.FieldSet (layout.fieldset)','Ext.layout.component.FieldSet','Ext.layout.component.Body','layout.fieldset','Ext.layout.component.FieldSet','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.Absolute (layout.absolute)','Ext.layout.container.Absolute','Ext.layout.container.Anchor','layout.absolute','Ext.layout.container.Absolute','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.Accordion (layout.accordion)','Ext.layout.container.Accordion','Ext.layout.container.VBox','layout.accordion','Ext.layout.container.Accordion','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.resizer.BorderSplitter (widget.bordersplitter)','Ext.resizer.BorderSplitter','Ext.resizer.Splitter','widget.bordersplitter','Ext.resizer.BorderSplitter','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.Border (layout.border)','Ext.layout.container.Border','Ext.layout.container.Container','layout.border','Ext.layout.container.Border','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.Card (layout.card)','Ext.layout.container.Card','Ext.layout.container.Fit','layout.card','Ext.layout.container.Card','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.Center (layout.center)','Ext.layout.container.Center','Ext.layout.container.Fit','layout.center','Ext.layout.container.Center','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.Center (layout.ux.center)','Ext.layout.container.Center','Ext.layout.container.Fit','layout.ux.center','Ext.layout.container.Center','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.layout.container.Form (layout.form)','Ext.layout.container.Form','Ext.layout.container.Auto','layout.form','Ext.layout.container.Form','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.menu.Bar (widget.menubar)','Ext.menu.Bar','Ext.menu.Menu','widget.menubar','Ext.menu.Bar','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.menu.ColorPicker (widget.colormenu)','Ext.menu.ColorPicker','Ext.menu.Menu','widget.colormenu','Ext.menu.ColorPicker','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.menu.DatePicker (widget.datemenu)','Ext.menu.DatePicker','Ext.menu.Menu','widget.datemenu','Ext.menu.DatePicker','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.plugin.LazyItems (plugin.lazyitems)','Ext.plugin.LazyItems','Ext.plugin.Abstract','plugin.lazyitems','Ext.plugin.LazyItems','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.plugin.Responsive (plugin.responsive)','Ext.plugin.Responsive','Ext.plugin.Abstract','plugin.responsive','Ext.plugin.Responsive','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.selection.CellModel (selection.cellmodel)','Ext.selection.CellModel','Ext.selection.DataViewModel','selection.cellmodel','Ext.selection.CellModel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.selection.RowModel (selection.rowmodel)','Ext.selection.RowModel','Ext.selection.DataViewModel','selection.rowmodel','Ext.selection.RowModel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.selection.CheckboxModel (selection.checkboxmodel)','Ext.selection.CheckboxModel','Ext.selection.RowModel','selection.checkboxmodel','Ext.selection.CheckboxModel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.selection.TreeModel (selection.treemodel)','Ext.selection.TreeModel','Ext.selection.RowModel','selection.treemodel','Ext.selection.TreeModel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.slider.Tip (widget.slidertip)','Ext.slider.Tip','Ext.tip.Tip','widget.slidertip','Ext.slider.Tip','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.slider.Multi (widget.multislider)','Ext.slider.Multi','Ext.form.field.Base','widget.multislider','Ext.slider.Multi','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.slider.Single (widget.slider)','Ext.slider.Single','Ext.slider.Multi','widget.slider','Ext.slider.Single','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.slider.Single (widget.sliderfield)','Ext.slider.Single','Ext.slider.Multi','widget.sliderfield','Ext.slider.Single','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.slider.Widget (widget.sliderwidget)','Ext.slider.Widget','Ext.Widget','widget.sliderwidget','Ext.slider.Widget','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.state.LocalStorageProvider (state.localstorage)','Ext.state.LocalStorageProvider','Ext.state.Provider','state.localstorage','Ext.state.LocalStorageProvider','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.tab.Tab (widget.tab)','Ext.tab.Tab','Ext.button.Button','widget.tab','Ext.tab.Tab','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.tab.Bar (widget.tabbar)','Ext.tab.Bar','Ext.panel.Bar','widget.tabbar','Ext.tab.Bar','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.tab.Panel (widget.tabpanel)','Ext.tab.Panel','Ext.panel.Panel','widget.tabpanel','Ext.tab.Panel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.toolbar.Breadcrumb (widget.breadcrumb)','Ext.toolbar.Breadcrumb','Ext.container.Container','widget.breadcrumb','Ext.toolbar.Breadcrumb','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.toolbar.Fill (widget.tbfill)','Ext.toolbar.Fill','Ext.Component','widget.tbfill','Ext.toolbar.Fill','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.toolbar.Spacer (widget.tbspacer)','Ext.toolbar.Spacer','Ext.Component','widget.tbspacer','Ext.toolbar.Spacer','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.tree.Column (widget.treecolumn)','Ext.tree.Column','Ext.grid.column.Column','widget.treecolumn','Ext.tree.Column','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.tree.NavigationModel (view.navigation.tree)','Ext.tree.NavigationModel','Ext.grid.NavigationModel','view.navigation.tree','Ext.tree.NavigationModel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.tree.Panel (widget.treepanel)','Ext.tree.Panel','Ext.panel.Table','widget.treepanel','Ext.tree.Panel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.tree.plugin.TreeViewDragDrop (plugin.treeviewdragdrop)','Ext.tree.plugin.TreeViewDragDrop','Ext.plugin.Abstract','plugin.treeviewdragdrop','Ext.tree.plugin.TreeViewDragDrop','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.view.MultiSelector (widget.multiselector)','Ext.view.MultiSelector','Ext.grid.Panel','widget.multiselector','Ext.view.MultiSelector','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.window.Toast (widget.toast)','Ext.window.Toast','Ext.window.Window','widget.toast','Ext.window.Toast','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.ajax.Simlet (simlet.basic)','Ext.ux.ajax.Simlet','Ext.Base','simlet.basic','Ext.ux.ajax.Simlet','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.ajax.JsonSimlet (simlet.json)','Ext.ux.ajax.JsonSimlet','Ext.ux.ajax.DataSimlet','simlet.json','Ext.ux.ajax.JsonSimlet','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.ajax.GroupingSimlet (simlet.grouping)','Ext.ux.ajax.GroupingSimlet','Ext.ux.ajax.JsonSimlet','simlet.grouping','Ext.ux.ajax.GroupingSimlet','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.ajax.PivotSimlet (simlet.pivot)','Ext.ux.ajax.PivotSimlet','Ext.ux.ajax.JsonSimlet','simlet.pivot','Ext.ux.ajax.PivotSimlet','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.ajax.XmlSimlet (simlet.xml)','Ext.ux.ajax.XmlSimlet','Ext.ux.ajax.DataSimlet','simlet.xml','Ext.ux.ajax.XmlSimlet','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.gauge.Gauge (widget.gauge)','Ext.ux.gauge.Gauge','Ext.Widget','widget.gauge','Ext.ux.gauge.Gauge','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.rating.Picker (widget.rating)','Ext.ux.rating.Picker','Ext.Widget','widget.rating','Ext.ux.rating.Picker','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.BoxReorderer (plugin.boxreorderer)','Ext.ux.BoxReorderer','Ext.plugin.Abstract','plugin.boxreorderer','Ext.ux.BoxReorderer','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.CellDragDrop (plugin.celldragdrop)','Ext.ux.CellDragDrop','Ext.plugin.Abstract','plugin.celldragdrop','Ext.ux.CellDragDrop','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.DataTip (plugin.datatip)','Ext.ux.DataTip','Ext.tip.ToolTip','plugin.datatip','Ext.ux.DataTip','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.DataView.Animated (plugin.ux-animated-dataview)','Ext.ux.DataView.Animated','Ext.Base','plugin.ux-animated-dataview','Ext.ux.DataView.Animated','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.DataView.DragSelector (plugin.dataviewdragselector)','Ext.ux.DataView.DragSelector','Ext.Base','plugin.dataviewdragselector','Ext.ux.DataView.DragSelector','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.FieldReplicator (plugin.fieldreplicator)','Ext.ux.FieldReplicator','Ext.Base','plugin.fieldreplicator','Ext.ux.FieldReplicator','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.GMapPanel (widget.gmappanel)','Ext.ux.GMapPanel','Ext.panel.Panel','widget.gmappanel','Ext.ux.GMapPanel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.IFrame (widget.uxiframe)','Ext.ux.IFrame','Ext.Component','widget.uxiframe','Ext.ux.IFrame','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.statusbar.StatusBar (widget.statusbar)','Ext.ux.statusbar.StatusBar','Ext.toolbar.Toolbar','widget.statusbar','Ext.ux.statusbar.StatusBar','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.PreviewPlugin (plugin.preview)','Ext.ux.PreviewPlugin','Ext.plugin.Abstract','plugin.preview','Ext.ux.PreviewPlugin','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.ProgressBarPager (plugin.ux-progressbarpager)','Ext.ux.ProgressBarPager','Ext.Base','plugin.ux-progressbarpager','Ext.ux.ProgressBarPager','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.SlidingPager (plugin.ux-slidingpager)','Ext.ux.SlidingPager','Ext.Base','plugin.ux-slidingpager','Ext.ux.SlidingPager','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.TabCloseMenu (plugin.tabclosemenu)','Ext.ux.TabCloseMenu','Ext.plugin.Abstract','plugin.tabclosemenu','Ext.ux.TabCloseMenu','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.TabReorderer (plugin.tabreorderer)','Ext.ux.TabReorderer','Ext.ux.BoxReorderer','plugin.tabreorderer','Ext.ux.TabReorderer','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.TabScrollerMenu (plugin.tabscrollermenu)','Ext.ux.TabScrollerMenu','Ext.Base','plugin.tabscrollermenu','Ext.ux.TabScrollerMenu','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.colorpick.ColorMapController (controller.colorpickercolormapcontroller)','Ext.ux.colorpick.ColorMapController','Ext.app.ViewController','controller.colorpickercolormapcontroller','Ext.ux.colorpick.ColorMapController','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.colorpick.ColorMap (widget.colorpickercolormap)','Ext.ux.colorpick.ColorMap','Ext.container.Container','widget.colorpickercolormap','Ext.ux.colorpick.ColorMap','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.colorpick.SelectorModel (viewmodel.colorpick-selectormodel)','Ext.ux.colorpick.SelectorModel','Ext.app.ViewModel','viewmodel.colorpick-selectormodel','Ext.ux.colorpick.SelectorModel','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.colorpick.SelectorController (controller.colorpick-selectorcontroller)','Ext.ux.colorpick.SelectorController','Ext.app.ViewController','controller.colorpick-selectorcontroller','Ext.ux.colorpick.SelectorController','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.colorpick.ColorPreview (widget.colorpickercolorpreview)','Ext.ux.colorpick.ColorPreview','Ext.Component','widget.colorpickercolorpreview','Ext.ux.colorpick.ColorPreview','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.colorpick.SliderController (controller.colorpick-slidercontroller)','Ext.ux.colorpick.SliderController','Ext.app.ViewController','controller.colorpick-slidercontroller','Ext.ux.colorpick.SliderController','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.colorpick.Slider (widget.colorpickerslider)','Ext.ux.colorpick.Slider','Ext.container.Container','widget.colorpickerslider','Ext.ux.colorpick.Slider','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.colorpick.SliderAlpha (widget.colorpickerslideralpha)','Ext.ux.colorpick.SliderAlpha','Ext.ux.colorpick.Slider','widget.colorpickerslideralpha','Ext.ux.colorpick.SliderAlpha','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.colorpick.SliderSaturation (widget.colorpickerslidersaturation)','Ext.ux.colorpick.SliderSaturation','Ext.ux.colorpick.Slider','widget.colorpickerslidersaturation','Ext.ux.colorpick.SliderSaturation','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.colorpick.SliderValue (widget.colorpickerslidervalue)','Ext.ux.colorpick.SliderValue','Ext.ux.colorpick.Slider','widget.colorpickerslidervalue','Ext.ux.colorpick.SliderValue','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.colorpick.SliderHue (widget.colorpickersliderhue)','Ext.ux.colorpick.SliderHue','Ext.ux.colorpick.Slider','widget.colorpickersliderhue','Ext.ux.colorpick.SliderHue','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.colorpick.ButtonController (controller.colorpick-buttoncontroller)','Ext.ux.colorpick.ButtonController','Ext.app.ViewController','controller.colorpick-buttoncontroller','Ext.ux.colorpick.ButtonController','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.colorpick.Button (widget.colorbutton)','Ext.ux.colorpick.Button','Ext.Component','widget.colorbutton','Ext.ux.colorpick.Button','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.colorpick.Field (widget.colorfield)','Ext.ux.colorpick.Field','Ext.form.field.Picker','widget.colorfield','Ext.ux.colorpick.Field','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.data.PagingMemoryProxy (proxy.pagingmemory)','Ext.ux.data.PagingMemoryProxy','Ext.data.proxy.Memory','proxy.pagingmemory','Ext.ux.data.PagingMemoryProxy','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.dd.CellFieldDropZone (plugin.ux-cellfielddropzone)','Ext.ux.dd.CellFieldDropZone','Ext.dd.DropZone','plugin.ux-cellfielddropzone','Ext.ux.dd.CellFieldDropZone','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.dd.PanelFieldDragZone (plugin.ux-panelfielddragzone)','Ext.ux.dd.PanelFieldDragZone','Ext.dd.DragZone','plugin.ux-panelfielddragzone','Ext.ux.dd.PanelFieldDragZone','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.desktop.Desktop (widget.desktop)','Ext.ux.desktop.Desktop','Ext.panel.Panel','widget.desktop','Ext.ux.desktop.Desktop','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.desktop.TaskBar (widget.taskbar)','Ext.ux.desktop.TaskBar','Ext.toolbar.Toolbar','widget.taskbar','Ext.ux.desktop.TaskBar','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.desktop.TrayClock (widget.trayclock)','Ext.ux.desktop.TrayClock','Ext.toolbar.TextItem','widget.trayclock','Ext.ux.desktop.TrayClock','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.desktop.Video (widget.video)','Ext.ux.desktop.Video','Ext.panel.Panel','widget.video','Ext.ux.desktop.Video','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.desktop.Wallpaper (widget.wallpaper)','Ext.ux.desktop.Wallpaper','Ext.Component','widget.wallpaper','Ext.ux.desktop.Wallpaper','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.event.RecorderManager (widget.eventrecordermanager)','Ext.ux.event.RecorderManager','Ext.panel.Panel','widget.eventrecordermanager','Ext.ux.event.RecorderManager','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.form.MultiSelect (widget.multiselect)','Ext.ux.form.MultiSelect','Ext.form.FieldContainer','widget.multiselect','Ext.ux.form.MultiSelect','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.form.MultiSelect (widget.multiselectfield)','Ext.ux.form.MultiSelect','Ext.form.FieldContainer','widget.multiselectfield','Ext.ux.form.MultiSelect','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.grid.SubTable (plugin.subtable)','Ext.ux.grid.SubTable','Ext.grid.plugin.RowExpander','plugin.subtable','Ext.ux.grid.SubTable','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.grid.plugin.AutoSelector (plugin.gridautoselector)','Ext.ux.grid.plugin.AutoSelector','Ext.plugin.Abstract','plugin.gridautoselector','Ext.ux.grid.plugin.AutoSelector','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.layout.ResponsiveColumn (layout.responsivecolumn)','Ext.ux.layout.ResponsiveColumn','Ext.layout.container.Auto','layout.responsivecolumn','Ext.ux.layout.ResponsiveColumn','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.statusbar.ValidationStatus (plugin.validationstatus)','Ext.ux.statusbar.ValidationStatus','Ext.Component','plugin.validationstatus','Ext.ux.statusbar.ValidationStatus','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.modifier.Target (modifier.target)','Ext.draw.modifier.Target','Ext.draw.modifier.Modifier','modifier.target','Ext.draw.modifier.Target','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.modifier.Animation (modifier.animation)','Ext.draw.modifier.Animation','Ext.draw.modifier.Modifier','modifier.animation','Ext.draw.modifier.Animation','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.modifier.Highlight (modifier.highlight)','Ext.draw.modifier.Highlight','Ext.draw.modifier.Modifier','modifier.highlight','Ext.draw.modifier.Highlight','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.Sprite (sprite.sprite)','Ext.draw.sprite.Sprite','Ext.Base','sprite.sprite','Ext.draw.sprite.Sprite','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.Path (Ext.draw.Sprite)','Ext.draw.sprite.Path','Ext.draw.sprite.Sprite','Ext.draw.Sprite','Ext.draw.sprite.Path','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.Path (sprite.path)','Ext.draw.sprite.Path','Ext.draw.sprite.Sprite','sprite.path','Ext.draw.sprite.Path','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.Circle (sprite.circle)','Ext.draw.sprite.Circle','Ext.draw.sprite.Path','sprite.circle','Ext.draw.sprite.Circle','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.Arc (sprite.arc)','Ext.draw.sprite.Arc','Ext.draw.sprite.Circle','sprite.arc','Ext.draw.sprite.Arc','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.Arrow (sprite.arrow)','Ext.draw.sprite.Arrow','Ext.draw.sprite.Path','sprite.arrow','Ext.draw.sprite.Arrow','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.Composite (sprite.composite)','Ext.draw.sprite.Composite','Ext.draw.sprite.Sprite','sprite.composite','Ext.draw.sprite.Composite','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.Cross (sprite.cross)','Ext.draw.sprite.Cross','Ext.draw.sprite.Path','sprite.cross','Ext.draw.sprite.Cross','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.Diamond (sprite.diamond)','Ext.draw.sprite.Diamond','Ext.draw.sprite.Path','sprite.diamond','Ext.draw.sprite.Diamond','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.Ellipse (sprite.ellipse)','Ext.draw.sprite.Ellipse','Ext.draw.sprite.Path','sprite.ellipse','Ext.draw.sprite.Ellipse','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.EllipticalArc (sprite.ellipticalArc)','Ext.draw.sprite.EllipticalArc','Ext.draw.sprite.Ellipse','sprite.ellipticalArc','Ext.draw.sprite.EllipticalArc','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.Rect (sprite.rect)','Ext.draw.sprite.Rect','Ext.draw.sprite.Path','sprite.rect','Ext.draw.sprite.Rect','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.Image (sprite.image)','Ext.draw.sprite.Image','Ext.draw.sprite.Rect','sprite.image','Ext.draw.sprite.Image','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.Instancing (sprite.instancing)','Ext.draw.sprite.Instancing','Ext.draw.sprite.Sprite','sprite.instancing','Ext.draw.sprite.Instancing','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.Line (sprite.line)','Ext.draw.sprite.Line','Ext.draw.sprite.Sprite','sprite.line','Ext.draw.sprite.Line','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.Plus (sprite.plus)','Ext.draw.sprite.Plus','Ext.draw.sprite.Path','sprite.plus','Ext.draw.sprite.Plus','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.Sector (sprite.sector)','Ext.draw.sprite.Sector','Ext.draw.sprite.Path','sprite.sector','Ext.draw.sprite.Sector','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.Square (sprite.square)','Ext.draw.sprite.Square','Ext.draw.sprite.Path','sprite.square','Ext.draw.sprite.Square','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.Text (sprite.text)','Ext.draw.sprite.Text','Ext.draw.sprite.Sprite','sprite.text','Ext.draw.sprite.Text','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.Tick (sprite.tick)','Ext.draw.sprite.Tick','Ext.draw.sprite.Line','sprite.tick','Ext.draw.sprite.Tick','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.sprite.Triangle (sprite.triangle)','Ext.draw.sprite.Triangle','Ext.draw.sprite.Path','sprite.triangle','Ext.draw.sprite.Triangle','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.Surface (widget.surface)','Ext.draw.Surface','Ext.draw.SurfaceBase','widget.surface','Ext.draw.Surface','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.Container (widget.draw)','Ext.draw.Container','Ext.draw.ContainerBase','widget.draw','Ext.draw.Container','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.interactions.Abstract (widget.interaction)','Ext.chart.interactions.Abstract','Ext.Base','widget.interaction','Ext.chart.interactions.Abstract','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.axis.segmenter.Names (segmenter.names)','Ext.chart.axis.segmenter.Names','Ext.chart.axis.segmenter.Segmenter','segmenter.names','Ext.chart.axis.segmenter.Names','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.axis.segmenter.Numeric (segmenter.numeric)','Ext.chart.axis.segmenter.Numeric','Ext.chart.axis.segmenter.Segmenter','segmenter.numeric','Ext.chart.axis.segmenter.Numeric','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.axis.segmenter.Time (segmenter.time)','Ext.chart.axis.segmenter.Time','Ext.chart.axis.segmenter.Segmenter','segmenter.time','Ext.chart.axis.segmenter.Time','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.axis.layout.Discrete (axisLayout.discrete)','Ext.chart.axis.layout.Discrete','Ext.chart.axis.layout.Layout','axisLayout.discrete','Ext.chart.axis.layout.Discrete','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.axis.layout.CombineByIndex (axisLayout.combineByIndex)','Ext.chart.axis.layout.CombineByIndex','Ext.chart.axis.layout.Discrete','axisLayout.combineByIndex','Ext.chart.axis.layout.CombineByIndex','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.axis.layout.CombineDuplicate (axisLayout.combineDuplicate)','Ext.chart.axis.layout.CombineDuplicate','Ext.chart.axis.layout.Discrete','axisLayout.combineDuplicate','Ext.chart.axis.layout.CombineDuplicate','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.axis.layout.Continuous (axisLayout.continuous)','Ext.chart.axis.layout.Continuous','Ext.chart.axis.layout.Layout','axisLayout.continuous','Ext.chart.axis.layout.Continuous','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.axis.Axis (widget.axis)','Ext.chart.axis.Axis','Ext.Base','widget.axis','Ext.chart.axis.Axis','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.legend.Legend (legend.dom)','Ext.chart.legend.Legend','Ext.chart.legend.LegendBase','legend.dom','Ext.chart.legend.Legend','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.legend.Legend (widget.legend)','Ext.chart.legend.Legend','Ext.chart.legend.LegendBase','widget.legend','Ext.chart.legend.Legend','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.legend.sprite.Item (sprite.legenditem)','Ext.chart.legend.sprite.Item','Ext.draw.sprite.Composite','sprite.legenditem','Ext.chart.legend.sprite.Item','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.legend.sprite.Border (sprite.legendborder)','Ext.chart.legend.sprite.Border','Ext.draw.sprite.Rect','sprite.legendborder','Ext.chart.legend.sprite.Border','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.legend.SpriteLegend (legend.sprite)','Ext.chart.legend.SpriteLegend','Ext.Base','legend.sprite','Ext.chart.legend.SpriteLegend','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.grid.HorizontalGrid (grid.horizontal)','Ext.chart.grid.HorizontalGrid','Ext.draw.sprite.Sprite','grid.horizontal','Ext.chart.grid.HorizontalGrid','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.grid.VerticalGrid (grid.vertical)','Ext.chart.grid.VerticalGrid','Ext.draw.sprite.Sprite','grid.vertical','Ext.chart.grid.VerticalGrid','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.CartesianChart (widget.cartesian)','Ext.chart.CartesianChart','Ext.chart.AbstractChart','widget.cartesian','Ext.chart.CartesianChart','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.CartesianChart (widget.chart)','Ext.chart.CartesianChart','Ext.chart.AbstractChart','widget.chart','Ext.chart.CartesianChart','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.grid.CircularGrid (grid.circular)','Ext.chart.grid.CircularGrid','Ext.draw.sprite.Circle','grid.circular','Ext.chart.grid.CircularGrid','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.grid.RadialGrid (grid.radial)','Ext.chart.grid.RadialGrid','Ext.draw.sprite.Path','grid.radial','Ext.chart.grid.RadialGrid','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.PolarChart (widget.polar)','Ext.chart.PolarChart','Ext.chart.AbstractChart','widget.polar','Ext.chart.PolarChart','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.SpaceFillingChart (widget.spacefilling)','Ext.chart.SpaceFillingChart','Ext.chart.AbstractChart','widget.spacefilling','Ext.chart.SpaceFillingChart','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.axis.Axis3D (widget.axis3d)','Ext.chart.axis.Axis3D','Ext.chart.axis.Axis','widget.axis3d','Ext.chart.axis.Axis3D','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.axis.Category (axis.category)','Ext.chart.axis.Category','Ext.chart.axis.Axis','axis.category','Ext.chart.axis.Category','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.axis.Category3D (axis.category3d)','Ext.chart.axis.Category3D','Ext.chart.axis.Axis3D','axis.category3d','Ext.chart.axis.Category3D','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.axis.Numeric (axis.numeric)','Ext.chart.axis.Numeric','Ext.chart.axis.Axis','axis.numeric','Ext.chart.axis.Numeric','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.axis.Numeric (axis.radial)','Ext.chart.axis.Numeric','Ext.chart.axis.Axis','axis.radial','Ext.chart.axis.Numeric','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.axis.Numeric3D (axis.numeric3d)','Ext.chart.axis.Numeric3D','Ext.chart.axis.Axis3D','axis.numeric3d','Ext.chart.axis.Numeric3D','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.axis.Time (axis.time)','Ext.chart.axis.Time','Ext.chart.axis.Numeric','axis.time','Ext.chart.axis.Time','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.axis.Time3D (axis.time3d)','Ext.chart.axis.Time3D','Ext.chart.axis.Numeric3D','axis.time3d','Ext.chart.axis.Time3D','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.grid.HorizontalGrid3D (grid.horizontal3d)','Ext.chart.grid.HorizontalGrid3D','Ext.chart.grid.HorizontalGrid','grid.horizontal3d','Ext.chart.grid.HorizontalGrid3D','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.grid.VerticalGrid3D (grid.vertical3d)','Ext.chart.grid.VerticalGrid3D','Ext.chart.grid.VerticalGrid','grid.vertical3d','Ext.chart.grid.VerticalGrid3D','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.interactions.CrossZoom (interaction.crosszoom)','Ext.chart.interactions.CrossZoom','Ext.chart.interactions.Abstract','interaction.crosszoom','Ext.chart.interactions.CrossZoom','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.interactions.Crosshair (interaction.crosshair)','Ext.chart.interactions.Crosshair','Ext.chart.interactions.Abstract','interaction.crosshair','Ext.chart.interactions.Crosshair','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.interactions.ItemHighlight (interaction.itemhighlight)','Ext.chart.interactions.ItemHighlight','Ext.chart.interactions.Abstract','interaction.itemhighlight','Ext.chart.interactions.ItemHighlight','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.interactions.ItemEdit (interaction.itemedit)','Ext.chart.interactions.ItemEdit','Ext.chart.interactions.ItemHighlight','interaction.itemedit','Ext.chart.interactions.ItemEdit','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.interactions.PanZoom (interaction.panzoom)','Ext.chart.interactions.PanZoom','Ext.chart.interactions.Abstract','interaction.panzoom','Ext.chart.interactions.PanZoom','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.interactions.Rotate (interaction.rotate)','Ext.chart.interactions.Rotate','Ext.chart.interactions.Abstract','interaction.rotate','Ext.chart.interactions.Rotate','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.interactions.Rotate (interaction.rotatePie3d)','Ext.chart.interactions.Rotate','Ext.chart.interactions.Abstract','interaction.rotatePie3d','Ext.chart.interactions.Rotate','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.navigator.sprite.RangeMask (sprite.rangemask)','Ext.chart.navigator.sprite.RangeMask','Ext.draw.sprite.Sprite','sprite.rangemask','Ext.chart.navigator.sprite.RangeMask','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.plugin.ItemEvents (plugin.chartitemevents)','Ext.chart.plugin.ItemEvents','Ext.plugin.Abstract','plugin.chartitemevents','Ext.chart.plugin.ItemEvents','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.series.sprite.Area (sprite.areaSeries)','Ext.chart.series.sprite.Area','Ext.chart.series.sprite.StackedCartesian','sprite.areaSeries','Ext.chart.series.sprite.Area','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.series.Area (series.area)','Ext.chart.series.Area','Ext.chart.series.StackedCartesian','series.area','Ext.chart.series.Area','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.series.sprite.Bar (sprite.barSeries)','Ext.chart.series.sprite.Bar','Ext.chart.series.sprite.StackedCartesian','sprite.barSeries','Ext.chart.series.sprite.Bar','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.series.Bar (series.bar)','Ext.chart.series.Bar','Ext.chart.series.StackedCartesian','series.bar','Ext.chart.series.Bar','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.series.sprite.Bar3D (sprite.bar3dSeries)','Ext.chart.series.sprite.Bar3D','Ext.chart.series.sprite.Bar','sprite.bar3dSeries','Ext.chart.series.sprite.Bar3D','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.sprite.Bar3D (sprite.bar3d)','Ext.chart.sprite.Bar3D','Ext.draw.sprite.Sprite','sprite.bar3d','Ext.chart.sprite.Bar3D','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.series.Bar3D (series.bar3d)','Ext.chart.series.Bar3D','Ext.chart.series.Bar','series.bar3d','Ext.chart.series.Bar3D','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.series.sprite.BoxPlot (sprite.boxplotSeries)','Ext.chart.series.sprite.BoxPlot','Ext.chart.series.sprite.Cartesian','sprite.boxplotSeries','Ext.chart.series.sprite.BoxPlot','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.sprite.BoxPlot (sprite.boxplot)','Ext.chart.sprite.BoxPlot','Ext.draw.sprite.Sprite','sprite.boxplot','Ext.chart.sprite.BoxPlot','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.series.BoxPlot (series.boxplot)','Ext.chart.series.BoxPlot','Ext.chart.series.Cartesian','series.boxplot','Ext.chart.series.BoxPlot','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.series.sprite.CandleStick (sprite.candlestickSeries)','Ext.chart.series.sprite.CandleStick','Ext.chart.series.sprite.Aggregative','sprite.candlestickSeries','Ext.chart.series.sprite.CandleStick','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.series.CandleStick (series.candlestick)','Ext.chart.series.CandleStick','Ext.chart.series.Cartesian','series.candlestick','Ext.chart.series.CandleStick','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.series.sprite.Line (sprite.lineSeries)','Ext.chart.series.sprite.Line','Ext.chart.series.sprite.Aggregative','sprite.lineSeries','Ext.chart.series.sprite.Line','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.series.Line (series.line)','Ext.chart.series.Line','Ext.chart.series.Cartesian','series.line','Ext.chart.series.Line','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.series.sprite.PieSlice (sprite.pieslice)','Ext.chart.series.sprite.PieSlice','Ext.draw.sprite.Sector','sprite.pieslice','Ext.chart.series.sprite.PieSlice','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.series.Pie (series.pie)','Ext.chart.series.Pie','Ext.chart.series.Polar','series.pie','Ext.chart.series.Pie','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.series.sprite.Pie3DPart (sprite.pie3dPart)','Ext.chart.series.sprite.Pie3DPart','Ext.draw.sprite.Path','sprite.pie3dPart','Ext.chart.series.sprite.Pie3DPart','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.series.sprite.Radar (sprite.radar)','Ext.chart.series.sprite.Radar','Ext.chart.series.sprite.Polar','sprite.radar','Ext.chart.series.sprite.Radar','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.series.sprite.Scatter (sprite.scatterSeries)','Ext.chart.series.sprite.Scatter','Ext.chart.series.sprite.Cartesian','sprite.scatterSeries','Ext.chart.series.sprite.Scatter','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.series.Scatter (series.scatter)','Ext.chart.series.Scatter','Ext.chart.series.Cartesian','series.scatter','Ext.chart.series.Scatter','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.draw.plugin.SpriteEvents (plugin.spriteevents)','Ext.draw.plugin.SpriteEvents','Ext.plugin.Abstract','plugin.spriteevents','Ext.draw.plugin.SpriteEvents','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.chart.interactions.ItemInfo (interaction.iteminfo)','Ext.chart.interactions.ItemInfo','Ext.chart.interactions.Abstract','interaction.iteminfo','Ext.chart.interactions.ItemInfo','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('IconFont.form.field.ComboBox (widget.iconcombo)','IconFont.form.field.ComboBox','Ext.form.field.ComboBox','widget.iconcombo','IconFont.form.field.ComboBox','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.column.ColumnEdit (plugin.columneditors)','Ext.grid.column.ColumnEdit','Ext.plugin.Abstract','plugin.columneditors','Ext.grid.column.ColumnEdit','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.feature.SelectedSummary (feature.selectedsummary)','Ext.grid.feature.SelectedSummary','Ext.grid.feature.AbstractSummary','feature.selectedsummary','Ext.grid.feature.SelectedSummary','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.grid.filters.DefaultFilters (plugin.defaultfilters)','Ext.grid.filters.DefaultFilters','Ext.plugin.Abstract','plugin.defaultfilters','Ext.grid.filters.DefaultFilters','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.DateTimePicker (widget.datetimepicker)','Ext.ux.DateTimePicker','Ext.picker.Date','widget.datetimepicker','Ext.ux.DateTimePicker','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);
insert into  extjs_base_types (id,classname,baseclass,xtype_long_classic,name,vendor,iscolumn,isformfield) values ('Ext.ux.DateTimeField (widget.datetimefield)','Ext.ux.DateTimeField','Ext.form.field.Date','widget.datetimefield','Ext.ux.DateTimeField','Sencha ExtJS',0,0) on duplicate key update xtype_long_classic=values(xtype_long_classic),iscolumn=values(iscolumn),isformfield=values(isformfield);

-- SOURCE FILE: ./src//500-ui/000-types/001.custom.sql 

delimiter ;

create or replace view view_ds_custom as
select
    concat(
        'Ext.define(',doublequote( custom_types.id ),',',
            JSON_MERGE(
                JSON_OBJECT(
                    "extend",extendsxtype_modern,
                    "alias",xtype_long_modern
                ),
                ifnull(_str.c,'{}'),
                ifnull(_int.c,'{}'),
                ifnull(_bool.c,'{}')
            ),

        ')',char(59)
    )  js
from 
    custom_types 
    left join ( select JSON_OBJECTAGG(property,val) c,id from custom_types_attributes_string group by id) _str on custom_types.id = _str.id
    left join ( select JSON_OBJECTAGG(property,val) c,id from custom_types_attributes_integer group by id) _int on custom_types.id = _int.id
    left join ( select JSON_OBJECTAGG(property,if(val=1,true,false)) c,id from custom_types_attributes_boolean group by id) _bool on custom_types.id = _bool.id

where xtype_long_modern is not null
group by custom_types.id;

-- SOURCE FILE: ./src//500-ui/000-types/003.dstypes.sql 
delimiter ;

create or replace view view_readtable_ds_types as

-- DS Store
select 
    concat('Tualo.DataSets.store.',UCASE(LEFT(`ds`.`table_name`, 1)), lower(SUBSTRING(`ds`.`table_name`, 2))) `id`,
    concat('store.ds_',`ds`.`table_name`) `xtype_long_modern`,
    concat('store.ds_',`ds`.`table_name`) `xtype_long_classic`,

    'store' `modern_typeclass`,
    concat('ds_',`ds`.`table_name`) `modern_type`,

    'store' `classic_typeclass`,
    concat('ds_',`ds`.`table_name`) `classic_type`,

    concat('Datastore ',`ds`.`title`,' (',`ds`.`table_name`,')') `name`,
    'Tualo DS' `vendor`,
    '' `description`,
    0 isformfield,
    0 iscolumn

    

from `ds` 
join ( 
        select `table_name` 
        from `ds_access` join `view_session_groups` on `ds_access`.`role` = `view_session_groups`.`group` and  `ds_access`.`read`=1 
        group by  `table_name` 
    ) `acc` on `acc`.`table_name` = `ds`.`table_name`
where `ds`.`title`<>''

union


-- DS List
select 
    concat('Tualo.DataSets.list.',UCASE(LEFT(`ds`.`table_name`, 1)), lower(SUBSTRING(`ds`.`table_name`, 2))) `id`,
    concat('widget.dslist_',`ds`.`table_name`) `xtype_long_modern`,
    concat('widget.dslist_',`ds`.`table_name`) `xtype_long_classic`,

    'widget' `modern_typeclass`,
    concat('dslist_',`ds`.`table_name`) `modern_type`,

    'widget' `classic_typeclass`,
    concat('dslist_',`ds`.`table_name`) `classic_type`,

    concat('DS List ',`ds`.`title`,' (',`ds`.`table_name`,')') `name`,
    'Tualo DS' `vendor`,
    '' `description`,
    0 isformfield,
    0 iscolumn

from `ds` 
join ( 
        select `table_name` 
        from `ds_access` join `view_session_groups` on `ds_access`.`role` = `view_session_groups`.`group` and  `ds_access`.`read`=1 
        group by  `table_name` 
    ) `acc` on `acc`.`table_name` = `ds`.`table_name`
where `ds`.`title`<>''

union

-- DS Form
select 
    concat('Tualo.DataSets.form.',UCASE(LEFT(`ds`.`table_name`, 1)), lower(SUBSTRING(`ds`.`table_name`, 2))) `id`,
    concat('widget.dsform_',`ds`.`table_name`) `xtype_long_modern`,
    concat('widget.dsform_',`ds`.`table_name`) `xtype_long_classic`,

    'widget' `modern_typeclass`,
    concat('dsform_',`ds`.`table_name`) `modern_type`,

    'widget' `classic_typeclass`,
    concat('dsform_',`ds`.`table_name`) `classic_type`,

    concat('DS Form ',`ds`.`title`,' (',`ds`.`table_name`,')') `name`,
    'Tualo DS' `vendor`,
    '' `description`,
    1 isformfield,
    0 iscolumn

from `ds` 
join ( 
        select `table_name` 
        from `ds_access` join `view_session_groups` on `ds_access`.`role` = `view_session_groups`.`group` and  `ds_access`.`read`=1 
        group by  `table_name` 
    ) `acc` on `acc`.`table_name` = `ds`.`table_name`
where `ds`.`title`<>''
    

union

-- DS Column
select 
    concat('Tualo.DataSets.column.',lower(ds_dropdownfields.table_name),'.',UCASE(LEFT(ds_dropdownfields.name, 1)), lower(SUBSTRING(ds_dropdownfields.name, 2))  ) `id`,
    concat('widget.column_',`ds_dropdownfields`.`table_name`,'_',lower(ds_dropdownfields.name)) `xtype_long_modern`,
    concat('widget.column_',`ds_dropdownfields`.`table_name`,'_',lower(ds_dropdownfields.name)) `xtype_long_classic`,

    'widget' `modern_typeclass`,
    concat('column_',`ds_dropdownfields`.`table_name`,'_',lower(ds_dropdownfields.name)) `modern_type`,

    'widget' `classic_typeclass`,
    concat('column_',`ds_dropdownfields`.`table_name`,'_',lower(ds_dropdownfields.name)) `classic_type`,

    concat('DS Column ',`ds`.`title`,'-',ds_dropdownfields.name,' (',`ds`.`table_name`,' ',lower(ds_dropdownfields.name),')') `name`,
    'Tualo DS' `vendor`,
    '' `description`,
    0 isformfield,
    1 iscolumn

from
    `ds_dropdownfields`
    join `ds` 
        on `ds_dropdownfields`.`table_name` = `ds`.`table_name`
    join `ds_column` 
        on (`ds_dropdownfields`.`table_name`,`ds_dropdownfields`.`idfield`) = (`ds_column`.`table_name`,`ds_column`.`column_name`)
        and `ds_column`.`existsreal`=1
    join ( 
        select `table_name` 
        from `ds_access` join `view_session_groups` on `ds_access`.`role` = `view_session_groups`.`group` and  `ds_access`.`read`=1 
        group by  `table_name` 
    ) `acc` on `acc`.`table_name` = `ds`.`table_name`
union 
-- DS Displayfield
select 
    concat('Tualo.DataSets.displayfield.',lower(ds_dropdownfields.table_name),'.',UCASE(LEFT(ds_dropdownfields.name, 1)), lower(SUBSTRING(ds_dropdownfields.name, 2))  ) `id`,
    concat('widget.displaycombobox_',`ds_dropdownfields`.`table_name`,'_',lower(ds_dropdownfields.name)) `xtype_long_modern`,
    concat('widget.displaycombobox_',`ds_dropdownfields`.`table_name`,'_',lower(ds_dropdownfields.name)) `xtype_long_classic`,

    'widget' `modern_typeclass`,
    concat('displaycombobox_',`ds_dropdownfields`.`table_name`,'_',lower(ds_dropdownfields.name)) `modern_type`,

    'widget' `classic_typeclass`,
    concat('displaycombobox_',`ds_dropdownfields`.`table_name`,'_',lower(ds_dropdownfields.name)) `classic_type`,

    concat('DS DisplayField ',`ds`.`title`,'-',ds_dropdownfields.name,' (',`ds`.`table_name`,' ',lower(ds_dropdownfields.name),')') `name`,
    'Tualo DS' `vendor`,
    '' `description`,
    1 isformfield,
    0 iscolumn

from
    `ds_dropdownfields`
    join `ds` 
        on `ds_dropdownfields`.`table_name` = `ds`.`table_name`
    join `ds_column` 
        on (`ds_dropdownfields`.`table_name`,`ds_dropdownfields`.`idfield`) = (`ds_column`.`table_name`,`ds_column`.`column_name`)
        and `ds_column`.`existsreal`=1

union 
-- DS DD Field
select 
    concat('Tualo.DataSets.combobox.',lower(ds_dropdownfields.table_name),'.',UCASE(LEFT(ds_dropdownfields.name, 1)), lower(SUBSTRING(ds_dropdownfields.name, 2))  ) `id`,
    concat('widget.combobox_',`ds_dropdownfields`.`table_name`,'_',lower(ds_dropdownfields.name)) `xtype_long_modern`,
    concat('widget.combobox_',`ds_dropdownfields`.`table_name`,'_',lower(ds_dropdownfields.name)) `xtype_long_classic`,

    'widget' `modern_typeclass`,
    concat('combobox_',`ds_dropdownfields`.`table_name`,'_',lower(ds_dropdownfields.name)) `modern_type`,

    'widget' `classic_typeclass`,
    concat('combobox_',`ds_dropdownfields`.`table_name`,'_',lower(ds_dropdownfields.name)) `classic_type`,

    concat('DS ComboBox ',`ds`.`title`,'-',ds_dropdownfields.name,' (',`ds`.`table_name`,' ',lower(ds_dropdownfields.name),')') `name`,
    'Tualo DS' `vendor`,
    '' `description`,
    1 isformfield,
    0 iscolumn

from
    `ds_dropdownfields`
    join `ds` 
        on `ds_dropdownfields`.`table_name` = `ds`.`table_name`
    join `ds_column` 
        on (`ds_dropdownfields`.`table_name`,`ds_dropdownfields`.`idfield`) = (`ds_column`.`table_name`,`ds_column`.`column_name`)
        and `ds_column`.`existsreal`=1
join ( 
        select `table_name` 
        from `ds_access` join `view_session_groups` on `ds_access`.`role` = `view_session_groups`.`group` and  `ds_access`.`read`=1 
        group by  `table_name` 
    ) `acc` on `acc`.`table_name` = `ds`.`table_name`
;





create or replace view view_readtable_all_types as
        select `name` as `id`,`xtype_long_modern`,`xtype_long_classic`,`modern_typeclass`,`modern_type`,`classic_typeclass`,`classic_type`,`name`,`vendor`,`description` from view_readtable_extjs_base_types
union   select `id`,`xtype_long_modern`,`xtype_long_classic`,`modern_typeclass`,`modern_type`,`classic_typeclass`,`classic_type`,`name`,`vendor`,`description` from view_readtable_custom_types
union   select `id`,`xtype_long_modern`,`xtype_long_classic`,`modern_typeclass`,`modern_type`,`classic_typeclass`,`classic_type`,`name`,`vendor`,`description` from view_readtable_ds_types
;

create or replace view view_readtable_all_types_modern as
select `id`,`xtype_long_modern` `xtype`,`modern_typeclass` `typeclass`,`modern_type` `type`,`name`,`vendor`,`description`
from view_readtable_all_types where  xtype_long_modern is not null  
;

create or replace view view_readtable_all_types_classic as
select `id`,`xtype_long_classic` `xtype`,`classic_typeclass` `typeclass`,`classic_type` `type`,`name`,`vendor`,`description`
from view_readtable_all_types where  xtype_long_classic is not null  
;


-- ds_dropdownfields
-- SOURCE FILE: ./src//500-ui/010-model/010.view_ds_model.sql 
delimiter ;



create or replace view view_ds_column_merge as
select
    `ds_column`.`table_name`, 
    `ds_column`.`column_name`,
    if (ds_column.data_type in ('date','datetime','time'),
        JSON_OBJECT(
            "dateFormat", 
            if (
                ds_column.data_type ='date',
                "Y-m-d",
                if (
                    ds_column.data_type ='datetime',
                    "Y-m-d H:i:s",
                    if (
                        ds_column.data_type ='time',
                        "H:i:s",
                        ""
                    )
                )
            ),
            "dateWriteFormat", 
            if (
                ds_column.data_type ='date',
                "Y-m-d",
                if (
                    ds_column.data_type ='datetime',
                    "Y-m-d H:i:s",
                    if (
                        ds_column.data_type ='time',
                        "H:i:s",
                        ""
                    )
                )
            )
        ),
        if (ds_column.data_type in ('varchar'),
            JSON_OBJECT(
                "maxLength", ds_column.character_maximum_length
            ),
            JSON_OBJECT()
        )
    )
     obj
from ds_column
where ds_column.existsreal = 1
    -- ds_column.data_type in ('date','datetime','time')
;

create or replace view view_ds_model as
select 
    concat('Tualo.DataSets.model.',UCASE(LEFT(ds.table_name, 1)), lower(SUBSTRING(ds.table_name, 2))) name,
    concat('Tualo/DataSets/model/',UCASE(LEFT(ds.table_name, 1)), lower(SUBSTRING(ds.table_name, 2)),'.js') filename,

concat( 'Ext.define(',quote( concat('Tualo.DataSets.model.',UCASE(LEFT(ds.table_name, 1)), lower(SUBSTRING(ds.table_name, 2))) ) , ', ',
 JSON_OBJECT(
     'extend', 'Tualo.DataSets.model.Basic',
     'entityName',  ds.table_name,
     'idProperty', '__id',
     'fields',
        JSON_MERGE(
            concat('[',
                '{"name": "__table_name", "defaultValue": "',ds.table_name,'","critical": true,"type":"string"},',
                '{"name": "__id", "critical": true, "type":"string"},',
                '{"name": "__rownumber", "critical": true, "type":"number"}',
            ']'),
            ifnull(
            concat('[',group_concat( 
                JSON_MERGE(
                    JSON_OBJECT(
                        'name', concat(`ds_column`.`table_name`,'__',`ds_column`.`column_name`),
                        'type', if(ds_column.column_type='bigint(4)' or ds_column.column_type='int(4)' or ds_column.column_type='tinyint(4)','boolean', ifnull(`ds_column_forcetype`.`fieldtype`, ifnull(`ds_db_types_fieldtype`.`fieldtype`,'string')))
                    ),
                    if(
                        ds_column.default_value='',
                        '{}',
                        JSON_OBJECT(
                            'defaultValue', if( substring(ds_column.default_value,1,1)='{',null,ds_column.default_value )
                        )
                    ),
                    if(
                        ds_column.is_primary=1,
                        '{"critical": true}',
                        '{}'
                    )
                    ,
                    view_ds_column_merge.obj
                )
                  order by ds_column.column_name separator ','),']'
            ),'[]')
        )
 ),')',char(59)) js,
 ds.table_name
from
    ds
    join ds_column 
        on ds.table_name = ds_column.table_name
        and `ds_column`.`existsreal`=1 
        -- and `ds`.`title`<>''
        -- and (`ds_column`.table_name, `ds_column`.column_name) in (select table_name, column_name from ds_column_list_label where active=1)
    join view_ds_column_merge
        on view_ds_column_merge.table_name = `ds_column`.`table_name`
        and view_ds_column_merge.column_name = `ds_column`.`column_name`
    
    left join `ds_db_types_fieldtype` on `ds_column`.`data_type` = `ds_db_types_fieldtype`.`dbtype`
    left join `ds_column_forcetype` 
        on (`ds_column`.`table_name`,`ds_column`.`column_name`) =  (`ds_column_forcetype`.`table_name`,`ds_column_forcetype`.`column_name`)
-- where ds.table_name='adressen'       
      
group by ds.table_name
;

-- SOURCE FILE: ./src//500-ui/020-store/020.view_ds_store.sql 
delimiter ;

create or replace view view_ds_store as
select 
    concat('Tualo.DataSets.store.',UCASE(LEFT(ds.table_name, 1)), lower(SUBSTRING(ds.table_name, 2))) name,
    concat('Tualo/DataSets/store/',UCASE(LEFT(ds.table_name, 1)), lower(SUBSTRING(ds.table_name, 2)),'.js') filename,
    concat(
        'Ext.define(',doublequote(concat('Tualo.DataSets.store.',UCASE(LEFT(ds.table_name, 1)), lower(SUBSTRING(ds.table_name, 2)))),',',
        JSON_OBJECT(
            "extend",  "Tualo.DataSets.data.Store",
            "tablename", table_name,
            "alias", JSON_ARRAY( concat('store.ds_',table_name) ,concat('store.',table_name,'_store') ),
            "storeId", concat('ds_',table_name),
            -- "requires", JSON_MERGE('[]', if( suppressRequires() ,  '[]', concat('[',doublequote(concat('Tualo.DataSets.model.',UCASE(LEFT(ds.table_name, 1)), lower(SUBSTRING(ds.table_name, 2)))),']')) ),
            "model", concat('Tualo.DataSets.model.',UCASE(LEFT(ds.table_name, 1)), lower(SUBSTRING(ds.table_name, 2))),
            "remoteFilter", TRUE is true,
            "autoLoad", FALSE is true,
            "autoSync", FALSE is true
        ),')',char(59)) js,
        table_name
from
    ds
    
where
    /*`ds`.`title`<>'' and*/ (table_name in (
        select 
            table_name
        from 
            ds_column 
        where `ds_column`.`existsreal`=1 
        -- and (`ds_column`.table_name, `ds_column`.column_name) in (select table_name, column_name from ds_column_list_label where active=1)
    ))
;
-- SOURCE FILE: ./src//500-ui/030-column/030.view_ds_column.sql 
delimiter ;

create or replace view view_ds_column as
select 
    concat(
        'Ext.define(',doublequote(concat('Tualo.DataSets.column.',lower(ds_dropdownfields.table_name),'.',UCASE(LEFT(ds_dropdownfields.name, 1)), lower(SUBSTRING(ds_dropdownfields.name, 2))  )),',',
            JSON_OBJECT(
                "extend",  "Tualo.cmp.cmp_ds.column.DS",
                -- "requires", JSON_MERGE('[]',concat('[',doublequote(concat('Tualo.DataSets.store.',UCASE(LEFT(ds_dropdownfields.table_name, 1)), lower(SUBSTRING(ds_dropdownfields.table_name, 2)))),']')) ,
                "tablename", `ds_dropdownfields`.`table_name`,
                "idField", lower(ds_dropdownfields.idfield),
                "displayField", lower(ds_dropdownfields.displayfield),
                "configStore", JSON_OBJECT(
                    "type", concat('ds_',`ds_dropdownfields`.`table_name`),
                    "storeId", concat('ds_',`ds_dropdownfields`.`table_name`,'_columnstore'),
                    "pageSize", 1000000
                ),
                "alias", concat('widget.column_',`ds_dropdownfields`.`table_name`,'_',lower(ds_dropdownfields.name))
            ),
        ')',char(59)
    ) js,
    `ds_dropdownfields`.`table_name`,
    `ds_dropdownfields`.`name`
from
    `ds_dropdownfields`
    join `ds_column` 
        on (`ds_dropdownfields`.`table_name`,`ds_dropdownfields`.`idfield`) = (`ds_column`.`table_name`,`ds_column`.`column_name`)
        and `ds_column`.`existsreal`=1
where
    `ds_dropdownfields`.`name`<>''
;

-- select * from view_ds_column;


create or replace view view_ds_column_stores as
select  ds_column_list_label.table_name,JSON_ARRAYAGG(

    distinct JSON_OBJECT(
        "type", x.store_type,
        "storeId", x.store_id,
        "pageSize", 1000000
    )
) stores  from 
	ds_column_list_label 
    join ( select 
	concat('column_',`ds_dropdownfields`.`table_name`,'_',lower(ds_dropdownfields.name)) id,
	concat('ds_',`ds_dropdownfields`.`table_name`) store_type,
    concat('ds_',`ds_dropdownfields`.`table_name`,'_columnstore') store_id,
	`ds_dropdownfields`.`table_name`,
    `ds_dropdownfields`.`name`
from
    `ds_dropdownfields`
    join `ds_column` 
        on (`ds_dropdownfields`.`table_name`,`ds_dropdownfields`.`idfield`) = (`ds_column`.`table_name`,`ds_column`.`column_name`)
        and `ds_column`.`existsreal`=1
where
    `ds_dropdownfields`.`name`<>'' ) x
    on ds_column_list_label.xtype=x.id
group by ds_column_list_label.table_name;
-- SOURCE FILE: ./src//500-ui/040-field/040.display.sql 
delimiter ;

create or replace view view_ds_displayfield as
select 
    concat(
        'Ext.define(',doublequote(concat('Tualo.DataSets.displayfield.',lower(ds_dropdownfields.table_name),'.',UCASE(LEFT(ds_dropdownfields.name, 1)), lower(SUBSTRING(ds_dropdownfields.name, 2))  )),',',
            JSON_OBJECT(
                "extend",  "Tualo.cmp.cmp_ds.field.DisplayDS",
                -- "requires", JSON_MERGE('[]',concat('[',doublequote(concat('Tualo.DataSets.store.',UCASE(LEFT(ds_dropdownfields.table_name, 1)), lower(SUBSTRING(ds_dropdownfields.table_name, 2)))),']')) ,
                "tablename", `ds_dropdownfields`.`table_name`,
                "idField", lower(ds_dropdownfields.idfield),
                "displayField", lower(ds_dropdownfields.displayfield),
                "configStore", JSON_OBJECT(
                    "type", concat('ds_',`ds_dropdownfields`.`table_name`),
                    "storeId", concat('ds_',`ds_dropdownfields`.`table_name`,'_columnstore'),
                    "pageSize", 1000000
                ),
                "alias", concat('widget.displaycombobox_',`ds_dropdownfields`.`table_name`,'_',lower(ds_dropdownfields.name))
            ),
        ')',char(59)
    ) js,
    `ds_dropdownfields`.`table_name`,
    `ds_dropdownfields`.`name`
from
    `ds_dropdownfields`
    join `ds_column` 
        on (`ds_dropdownfields`.`table_name`,`ds_dropdownfields`.`idfield`) = (`ds_column`.`table_name`,`ds_column`.`column_name`)
        and `ds_column`.`existsreal`=1
where
    `ds_dropdownfields`.`name`<>''
;

-- select * from view_ds_column;
-- SOURCE FILE: ./src//500-ui/040-field/041.combobox.sql 
delimiter ;

create or replace view view_ds_combobox as
select 
    concat(
        'Ext.define(',doublequote(concat('Tualo.DataSets.combobox.',lower(ds_dropdownfields.table_name),'.',UCASE(LEFT(ds_dropdownfields.name, 1)), lower(SUBSTRING(ds_dropdownfields.name, 2))  )),',',
            JSON_OBJECT(
                "extend",  "Tualo.cmp.cmp_ds.field.ComboBoxDS",
                -- "requires", JSON_MERGE('[]',concat('[',doublequote(concat('Tualo.DataSets.store.',UCASE(LEFT(ds_dropdownfields.table_name, 1)), lower(SUBSTRING(ds_dropdownfields.table_name, 2)))),']')) ,
                "tablename", `ds_dropdownfields`.`table_name`,
                "valueField", lower( concat( `ds_dropdownfields`.`table_name`,'__', `ds_dropdownfields`.`idfield` )),
                "displayField", lower( concat( `ds_dropdownfields`.`table_name`,'__', `ds_dropdownfields`.`displayfield` )),
                "store", JSON_OBJECT(
                    "type", concat('ds_',`ds_dropdownfields`.`table_name`),
                    "storeId", concat('ds_',`ds_dropdownfields`.`table_name`,'_columnstore'),
                    "pageSize", 1000000
                ),
                "alias", concat('widget.combobox_',`ds_dropdownfields`.`table_name`,'_',lower(ds_dropdownfields.name))
            ),
        ')',char(59)
    ) js,
    `ds_dropdownfields`.`table_name`,
    `ds_dropdownfields`.`name`
from
    `ds_dropdownfields`
    join `ds_column` 
        on (`ds_dropdownfields`.`table_name`,`ds_dropdownfields`.`idfield`) = (`ds_column`.`table_name`,`ds_column`.`column_name`)
        and `ds_column`.`existsreal`=1
where
    `ds_dropdownfields`.`name`<>''
;

-- select * from view_ds_column;
-- SOURCE FILE: ./src//500-ui/050-list/050.view_ds_listcolumn.sql 
delimiter ;
/*
update ds_column_list_label set xtype='booleancolumn' where (table_name,column_name) in (
select table_name,column_name from ds_column where   data_type='tinyint'
) and xtype='gridcolumn'


if( ifnull(ds_column_list_label.editor,'')='','', concat( '"editor": "', ds_column_list_label.editor ,'"', ', ') ),
      

*/

create or replace view view_ds_listcolumn as
select 


    JSON_MERGE('[]',
        concat('[',
            group_concat(
                JSON_OBJECT(
                    'text', `ds_column_list_label`.`label`,
                    'xtype', if(types.type is null,'gridcolumn', `ds_column_list_label`.`xtype`),
                    'dataIndex', concat(`ds_column`.`table_name`,'__',`ds_column`.`column_name`),
                    'summaryFormatter', null,
                    'hidden', if (`ds_column_list_label`.`hidden`=1,true=true,false=true),
                    'summaryRenderer', null,
                    'editor', if(
                        (ifnull(ds_column_list_label.editor,'')=''   ),
                        null,
                        if (types.type is null,'missedxtypefield',ds_column_list_label.editor )
                        
                    ),
                    'flex', 1 -- ,
                    -- 'filter', 'string'
                    -- 'filter', if(ds_column_list_label.listfiltertype <>'',  concat(' {"type":"',ds_column_list_label.listfiltertype,'"}') ,if(ds_column.data_type='date','{"type":"date", "dateFormat": "Y-m-d"}',  if(ds_column.data_type='int','{"type":"number"}', if((ds_column.data_type in ('tinyint','boolean') or ds_column.column_type='bigint(4)' ),'{"type":"boolean", "yesText": "Ja", "noText":"Nein"}','{"type":"string"}') )   ) )
                    -- 'filter', 'string',
                    -- 'flex', 1
                )
            order by ds_column_list_label.position separator ','),
        ']')
    ) js,
    `ds`.`table_name`,
    concat('[',
            group_concat(
                distinct 
                concat('"',types.id,'"')
                separator ','
            ),
        ']'
    ) `requiresJS`
from 
    `ds`
    join `ds_column` 
        on `ds`.`table_name` = `ds_column`.`table_name`
        and `ds_column`.`existsreal`=1 
        and `ds`.`title`<>''
    join `ds_column_list_label`
        on (`ds_column`.`table_name`, `ds_column`.`column_name`) = (`ds_column_list_label`.`table_name`, `ds_column_list_label`.`column_name`)
        and `ds_column_list_label`.`active` = 1
    left join view_readtable_all_types_classic types on  types.type = `ds_column_list_label`.`xtype`
        and typeclass='widget'
group by 
    `ds`.`table_name`;


-- SOURCE FILE: ./src//500-ui/050-list/054.view_ds_list.sql 
delimiter ;

call addfieldifnotexists('ds_listplugins','placement','varchar(50) default "view"');


create or replace view view_ds_list_plugins as


    SELECT
        table_name,
        JSON_OBJECT(
            'ptype', 'cellediting',
            'clicksToEdit', 1,
            'pluginId', concat(LOWER(table_name),'_cellediting')
        )   fld,
        'view' placement
    FROM 
        ds 
    where false

    union

    SELECT
        table_name,
        JSON_OBJECT(
            'ptype', 'gridfilters',
            'pluginId', concat(LOWER(table_name),'_gridfilters')
        ) fld,
        'view' placement
    FROM 
        ds 
    where false

    union 
    SELECT
        table_name,
        JSON_OBJECT(
            'ptype', 'gridviewdragdrop',
            'pluginId', concat(LOWER(table_name),'_gridviewdragdrop'),
            'dragText', 'Reihenfolge ändern',
            'reorderfield', concat(table_name,'__',reorderfield)
        ) fld,
        'viewConfig' placement
      FROM 
        ds 
      WHERE  
        ds.reorderfield<>'' 
        and ds.reorderfield is not null
        
      UNION

      SELECT
        ds_listplugins.table_name,
        JSON_OBJECT(
            'ptype', ds_listplugins.ptype,
            'pluginId', concat(LOWER(ds_listplugins.table_name),'_',LOWER(ds_listplugins.ptype))
        ) fld,
        ds_listplugins.placement
      FROM 
        ds_listplugins 
      

;

create or replace view view_ds_list_plugins_grouped as

select
table_name,
json_arrayagg(
        fld
) plugins
from 
view_ds_list_plugins
group by table_name
;

create or replace view view_ds_list as
select 
    concat(
        'Ext.define(',doublequote(concat('Tualo.DataSets.list.',UCASE(LEFT(ds.table_name, 1)), lower(SUBSTRING(ds.table_name, 2)))),',',
        JSON_OBJECT(
            "extend", "Tualo.DataSets.grid.Grid",
            "tablename",  ds.table_name,
            "alias", concat('widget.dslist_',ds.table_name),
            "title", ds.title,
            
            "controller",concat('dsgridcontroller'),
            "stateful",JSON_OBJECT("columns",true),
            
            "plugins", 
            JSON_ARRAY(

                JSON_OBJECT(
                    'ptype', 'cellediting',
                    'clicksToEdit', 1,
                    'pluginId', concat(LOWER(ds.table_name),'_cellediting')
                ),
                JSON_OBJECT(
                    'ptype', 'gridfilters'
                )
            ),
            
            "viewConfig",JSON_OBJECT(
                'listeners', JSON_OBJECT(
                    'drop', 'onDropGrid'
                ),
                "plugins", ifnull(view_ds_list_plugins_grouped.plugins,JSON_ARRAY())
                -- "getRowClass", "onRowClass"
                -- "getRowClass", concat('function(record, rowIndex, rowParams, store){ console.log("1");return "";/*return onRowClass(record, rowIndex, rowParams, store, "',ds.table_name,'");*/ }')

            ),
            "store", concat('ds_',ds.table_name),
            /* JSON_OBJECT( 
                'type', concat('ds_',ds.table_name),
                'autoLoad', FALSE is true
            ),*/
            

            

            "columns",JSON_MERGE('[]', view_ds_listcolumn.js)
            /*,
            "requires", JSON_MERGE(
                concat('[',doublequote(concat('Tualo.DataSets.store.',UCASE(LEFT(ds.table_name, 1)), lower(SUBSTRING(ds.table_name, 2)))),']'), 
                view_ds_listcolumn.requiresJS
            )*/
        ),
    ')',char(59)) js,
    view_ds_listcolumn.js jsx,
    ds.table_name
from
    ds
    join view_ds_listcolumn 
        on ds.table_name = view_ds_listcolumn.table_name
    left join view_ds_list_plugins_grouped
        on view_ds_list_plugins_grouped.table_name = ds.table_name

where
    /*`ds`.`title`<>''*/ true;
-- SOURCE FILE: ./src//500-ui/050-list/view_dd_column.sql 
delimiter ;

create or replace view view_tualo_available_types as 

select 
    `id`,
    `xtype_long_modern`,
    `xtype_long_classic`,

    `name`,
    `vendor`,
    `description`,
    
    SUBSTRING_INDEX(`xtype_long_modern`, '.', 1) `modern_typeclass`,
    SUBSTRING_INDEX(`xtype_long_modern`, '.', -1) `modern_type`,

    SUBSTRING_INDEX(`xtype_long_classic`, '.', 1) `classic_typeclass`,
    SUBSTRING_INDEX(`xtype_long_classic`, '.', -1) `classic_type`,

        iscolumn,
        isformfield


from extjs_base_types where isformfield=1

union 

select 

    `id`,
    `xtype_long_modern`,
    `xtype_long_classic`,

    `name`,
    `vendor`,
    `description`,

        modern_typeclass,
        modern_type,
        
        classic_typeclass,
        classic_type,
        
        iscolumn,
        isformfield


from view_readtable_ds_types;


create or replace view view_tualo_form_fields as 
select * from view_tualo_available_types 
where isformfield = 1
;


create or replace view view_tualo_column_types as 
select * from view_tualo_available_types 
where iscolumn=1
;

call fill_ds('view_tualo_form_fields');
call fill_ds_column('view_tualo_form_fields');
call fill_ds('view_tualo_column_types');
call fill_ds_column('view_tualo_column_types');

-- SOURCE FILE: ./src//500-ui/060-form/064.view_ds_formfieldgroups.sql 
delimiter ;
call addfieldifnotexists('ds_column_form_label','fieldgroup','varchar(50) default ""');
call addfieldifnotexists('ds_column_form_label','flex','decimal(5,2) default 1');
call addfieldifnotexists('ds_reference_tables','tabtitle','varchar(50) default ""');




create or replace view view_ds_formfield_merge as
select
    `ds_column`.`table_name`, 
    `ds_column`.`column_name`,
    if (ds_column.data_type in ('varchar'),
        JSON_OBJECT(
            "maxLength", ds_column.character_maximum_length
        ),
        JSON_OBJECT()
    ) obj
from ds_column
where ds_column.existsreal = 1
    -- ds_column.data_type in ('date','datetime','time')
;


create or replace view view_ds_formfieldgroups as
select
    `ds_column_form_label`.`table_name`, 
    `ds_column_form_label`.`column_name`,
    `ds_column_form_label`.`field_path`,
    `ds_column_form_label`.`fieldgroup`,
    `ds_column_form_label`.`active`,
    `ds_column_form_label`.`position`,
    count(*) c,
    if(count(*) =1,
            JSON_MERGE(
            JSON_OBJECT(

                'fieldLabel', `ds_column_form_label`.`label`,
                -- 'boxLabel', `ds_column_form_label`.`label`,
                'flex', `ds_column_form_label`.flex,
                'tablename', `ds_column_form_label`.`table_name`,
                'xtype',  
                    if(view_readtable_all_types_modern.type is null,
                        'missedxtypefield', `ds_column_form_label`.`xtype`
                ),

                'missedXtype', if(view_readtable_all_types_modern.type is null,`ds_column_form_label`.`xtype`,''),
                /*
                'triggers', JSON_OBJECT(
                    "clear", JSON_OBJECT( "type", 'clear')/*,
                    "undo", JSON_OBJECT( "type", 'trigger', "iconCls", 'x-fa fa-undo',"weight",-2000) 
                
                ),
                */
                'placeholder', `ds_column_form_label`.`label`,
                'name', concat(`ds_column_form_label`.`table_name`,'__',`ds_column_form_label`.`column_name`),
                'bind', JSON_OBJECT( 
                    "value",concat('{record.',`ds_column_form_label`.`table_name`,'__',`ds_column_form_label`.`column_name`,'}')
                ),
                'listeners', JSON_OBJECT( 
                    'change', 'onFormFieldChanged'
                )
            
            ), view_ds_formfield_merge.obj)
            ,
            JSON_OBJECT(
                'fieldLabel', group_concat( `ds_column_form_label`.`label` ORDER BY `ds_column_form_label`.`position` separator ' | '),
                'xtype', 'fieldcontainer',
                'layout', 'hbox',
                'flex',1,   
                'items',
                JSON_MERGE('[]', 
                    concat('[',
                    group_concat(
                        JSON_MERGE(
                        JSON_OBJECT(
        
                            -- 'label', `ds_column_form_label`.`label`,
                            'flex', 1,
                            'xtype',  if(view_readtable_all_types_modern.type is null,'displayfield', `ds_column_form_label`.`xtype`),
                            /*
                            'triggers', JSON_OBJECT(
                                "clear", JSON_OBJECT( "type", 'clear')/*,
                                "undo", JSON_OBJECT( "type", 'trigger', "iconCls", 'x-fa fa-undo',"weight",-2000) 
                              
                            ),
                              */
                            'emptyText', `ds_column_form_label`.`label`,
                            'name', concat(`ds_column_form_label`.`table_name`,'__',`ds_column_form_label`.`column_name`),
                            'bind', JSON_OBJECT( 
                                "value",concat('{record.',`ds_column_form_label`.`table_name`,'__',`ds_column_form_label`.`column_name`,'}')
                            ),
                            'listeners', JSON_OBJECT( 
                                'change', 'onFormFieldChanged'
                            )
                            
                        ), view_ds_formfield_merge.obj)
                        ORDER BY `ds_column_form_label`.`position`
                        separator ','
                    ),
                    ']'
                    )
                )
            )
    
    ) jsfield

from 
    (
        select 
            table_name,
            column_name,
            language,
            label,
            xtype,
            field_path,
            position,
            hidden,
            flex,
            active,
            allowempty,
            concat( 
                table_name,
                if(fieldgroup is null or fieldgroup="" or fieldgroup="1",column_name,fieldgroup)
                
            ) fieldgroup
        from `ds_column_form_label` 
    ) 
    
    ds_column_form_label
    join view_ds_formfield_merge
        on view_ds_formfield_merge.table_name = `ds_column_form_label`.`table_name`
        and view_ds_formfield_merge.column_name = `ds_column_form_label`.`column_name`
    

    left join view_readtable_all_types_classic view_readtable_all_types_modern
         on  view_readtable_all_types_modern.type = `ds_column_form_label`.`xtype`
         and typeclass='widget'
where 
    `ds_column_form_label`.`active` = 1
    and `ds_column_form_label`.`hidden` = 0
--    and `ds_column_form_label`.`table_name` = 'adressen'
--    and  field_path='Allgemein/Anschrift'
group by 

    `ds_column_form_label`.`table_name`, 
    `ds_column_form_label`.`field_path`,
    `ds_column_form_label`.`fieldgroup` 
;
-- SOURCE FILE: ./src//500-ui/060-form/065.view_ds_formfields.sql 
delimiter ;

create
or replace view view_ds_formfields as
select
    JSON_MERGE(
        '[]',
        concat(
            '[',
            group_concat(
                `ds_column_form_label`.`jsfield`
                order by
                    `ds_column_form_label`.`position` separator ','
            ),
            ']'
        )
    ) js,
    `ds`.`table_name`,
    min(ds_column_form_label.position) position,
    SUBSTRING_INDEX(field_path, '/', 1) tab_title,
    SUBSTRING_INDEX(field_path, '/', -1) fieldset_title,
    group_concat(
        `ds_column`.`column_name` separator ','
    ) cols
from
    `ds`
    join `ds_column` on `ds`.`table_name` = `ds_column`.`table_name`
    and `ds_column`.`existsreal` = 1
    and `ds`.`title` <> ''
    join view_ds_formfieldgroups `ds_column_form_label` on (
        `ds_column`.`table_name`,
        `ds_column`.`column_name`
    ) = (
        `ds_column_form_label`.`table_name`,
        `ds_column_form_label`.`column_name`
    )
    and `ds_column_form_label`.`active` = 1
group by
    `ds`.`table_name`,
    SUBSTRING_INDEX(field_path, '/', 1),
    SUBSTRING_INDEX(field_path, '/', -1);

create
or replace view view_ds_formtabs_fieldsets as
select
    `ds_column_form_label`.`table_name`,
    `view_ds_formfields`.`tab_title`,
    group_concat(
        distinct `view_ds_formfields`.`cols` separator ' | '
    ) cols,
    min(ds_column_form_label.position) min_position,
    JSON_MERGE(
        '[]',
        concat(
            '[',
            group_concat(
                distinct JSON_OBJECT(
                    "xtype",
                    "fieldset",
                    "layout",
                    'anchor',
                    "title",
                    `view_ds_formfields`.`fieldset_title`,
                    "defaults",
                    JSON_OBJECT("anchor", "100%"),
                    --            "scrollable", "y",
                    "items",
                    JSON_MERGE('[]', `view_ds_formfields`.`js`)
                )
                order by
                    view_ds_formfields.position separator ','
            ),
            ']'
        )
    ) js
from
    `ds_column_form_label`
    join `view_ds_formfields` on `ds_column_form_label`.`table_name` = `view_ds_formfields`.`table_name`
    and SUBSTRING_INDEX(ds_column_form_label.`field_path`, '/', 1) = `view_ds_formfields`.`tab_title`
    and SUBSTRING_INDEX(ds_column_form_label.`field_path`, '/', -1) = `view_ds_formfields`.`fieldset_title`
    and `ds_column_form_label`.`active` = 1
group by
    `ds_column_form_label`.`table_name`,
    `view_ds_formfields`.`tab_title`
order by
    min_position;

create
or replace view view_ds_formtabs as
select
    `ds_column_form_label`.`table_name`,
    JSON_OBJECT(
        "xtype",
        "panel",
        "title",
        `view_ds_formtabs_fieldsets`.`tab_title`,
        "padding",
        12,
        "scrollable",
        "y",
        "items",
        JSON_MERGE('[]', `view_ds_formtabs_fieldsets`.`js`)
    ) js,
    min(ds_column_form_label.position) position
from
    `ds_column_form_label`
    join `view_ds_formtabs_fieldsets` on `ds_column_form_label`.`table_name` = `view_ds_formtabs_fieldsets`.`table_name`
    and SUBSTRING_INDEX(`field_path`, '/', 1) = `view_ds_formtabs_fieldsets`.`tab_title`
    and `ds_column_form_label`.`active` = 1
group by
    `ds_column_form_label`.`table_name`,
    `view_ds_formtabs_fieldsets`.`tab_title`
union
select
    ds_reference_tables.reference_table_name `table_name`,
    JSON_OBJECT(
        "title",
        if(
            ifnull(ds_reference_tables.tabtitle, '') = '',
            ds.title,
            ds_reference_tables.tabtitle
        ),
        "xtype",
        concat('dsview_', ds_reference_tables.table_name),
        "referencedList",
        1 = 1,
        "referencedXType",
        concat(
            'dsview_',
            ds_reference_tables.reference_table_name
        ),
        "referenced",
        JSON_MERGE('{}', ds_reference_tables.columnsdef)
    ) js,
    100 + ds_reference_tables.position
from
    ds_reference_tables
    join ds on ds.table_name = ds_reference_tables.table_name
where
    ds_reference_tables.active = 1
union
select
    adress_bezug table_name,
    JSON_OBJECT(
        "title", blg_config.name,
        "xtype", concat( 'dsview_', 'view_blg_list_', lower(blg_config.tabellenzusatz) ),
        -- "html", concat( 'dsview_', 'view_blg_list_', lower(blg_config.tabellenzusatz) ),
        "referencedList", 1 = 1,
        "referenced", JSON_OBJECT(
            concat( 'view_blg_list_', lower(blg_config.tabellenzusatz), '__kundennummer' ),
            concat(adress_bezug, '__', blg_config.bezug_id),
            concat( 'view_blg_list_', lower(blg_config.tabellenzusatz),'__kostenstelle' ),
            concat(adress_bezug, '__', bezug_kst)
        )
    ) js,
    9000000+(rank() over (order by blg_config.name)) position
from
    blg_config
where
    bezug_anzeigen = 1;

create
or replace view view_ds_formtabs_pertable as
select
    `view_ds_formtabs`.`table_name`,
    JSON_MERGE(
        '[]',
        concat(
            '[',
            /*JSON_OBJECT('xtype','tabbar','docked','top','activeItem',0),
             ',', */
            group_concat(
                view_ds_formtabs.js
                order by
                    view_ds_formtabs.position separator ','
            ),
            ']'
        )
    ) js
from
    view_ds_formtabs
group by
    `view_ds_formtabs`.`table_name`;

-- select * from view_ds_formtabs_pertable where table_name='adressen';
-- SOURCE FILE: ./src//500-ui/060-form/066.view_ds_form.sql 
delimiter ;


create or replace view view_ds_form_requires as
select 
        ds_reference_tables.reference_table_name `table_name`,
        JSON_ARRAYAGG( concat('Tualo.DataSets.form.',UCASE(LEFT(ds_reference_tables.table_name, 1)), lower(SUBSTRING(ds_reference_tables.table_name, 2)))) requires
from 
        ds_reference_tables 
where 
        ds_reference_tables.active=1
group by ds_reference_tables.reference_table_name
;

create or replace view view_ds_form as
select 
    concat(
        'Ext.define(',doublequote(concat('Tualo.DataSets.form.',UCASE(LEFT(ds.table_name, 1)), lower(SUBSTRING(ds.table_name, 2)))),',',

        JSON_OBJECT(
            "extend", "Tualo.DS.form.Form",
            "tablename",ds.table_name,
            "alias", concat('widget.dsform_',ds.table_name),
            "config", JSON_OBJECT(
                "title", ds.title
            ),
            "layout", JSON_OBJECT(
                "type", 'hbox',
                "align", 'stretch'
            ),
            "items", 
            JSON_OBJECT(
                "xtype", "tabpanel",
                "flex", 1,
                /*
                "tabBar", JSON_OBJECT(
                    "layout", JSON_OBJECT(
                        "pack", 'start',
                        "overflow", 'scroller'
                    )
                ),
                */
                -- "layout", JSON_OBJECT( 'type', 'card','animation' , JSON_OBJECT('type','slide') ),
                "items",  JSON_MERGE('[]',ifnull(  view_ds_formtabs_pertable.js, '[]' ))
                /*,
                "requires", 

                
                JSON_MERGE('[]', 
                        JSON_MERGE('[]',  
                            if( suppressRequires(),  '[]',  
                                ifnull( req.requiresJS, '[]')
                            ) 
                        ) -- ,  
                        -- ifnull( view_ds_form_requires.requires, '[]') 
                )
                */
                            -- if( suppressRequires()=1,  '[]',   req.requiresJS) )
            )
        ),
    ')',char(59)) js,
    view_ds_formtabs_pertable.js jsx,
    ds.table_name
from
    ds
    left join view_ds_form_requires 
        on ds.table_name = view_ds_form_requires.table_name
    left join view_ds_formtabs_pertable 
        on ds.table_name = view_ds_formtabs_pertable.table_name
    left join (
        select 
            ds_column_form_label.table_name,
            concat('[',
                    group_concat(
                        distinct 
                        concat('"',view_readtable_all_types_modern.id,'"')
                        separator ','
                    ),
                ']'
            ) `requiresJS`
        from 
            (
                select 
                    table_name,
                    column_name,
                    language,
                    label,
                    xtype,
                    field_path,
                    position,
                    hidden,
                    active,
                    allowempty,
                    concat( 
                        table_name,
                        if(fieldgroup is null or fieldgroup="",column_name,fieldgroup)
                        
                    ) fieldgroup
                from `ds_column_form_label` 
            ) ds_column_form_label
            left join view_readtable_all_types_classic view_readtable_all_types_modern on  view_readtable_all_types_modern.type = `ds_column_form_label`.`xtype`
        where 
            `ds_column_form_label`.`active` = 1
            and `ds_column_form_label`.`hidden` = 0
        group by ds_column_form_label.table_name
    ) req on ds.table_name = req.table_name

where
    /*`ds`.`title`<>''*/ 
    true;

-- SOURCE FILE: ./src//500-ui/060-form/view_reportform_fieldgroups.sql 
create or replace view view_reportform_fieldgroups as
select
    `blg_config`.tabellenzusatz,
    `ds_column_form_label`.`table_name`, 
    `ds_column_form_label`.`column_name`,
    `ds_column_form_label`.`field_path`,
    `ds_column_form_label`.`fieldgroup`,
    `ds_column_form_label`.`active`,
    `ds_column_form_label`.`position`,
    count(*) c,
    if(count(*) =1,
            JSON_MERGE(
            JSON_OBJECT(

                'fieldLabel', `ds_column_form_label`.`label`,
                -- 'boxLabel', `ds_column_form_label`.`label`,
                'flex', `ds_column_form_label`.flex,
                'tablename', `ds_column_form_label`.`table_name`,
                'xtype',  
                    if(view_readtable_all_types_modern.type is null,
                        'missedxtypefield', `ds_column_form_label`.`xtype`
                ),

                'missedXtype', if(view_readtable_all_types_modern.type is null,`ds_column_form_label`.`xtype`,''),
                /*
                'triggers', JSON_OBJECT(
                    "clear", JSON_OBJECT( "type", 'clear')/*,
                    "undo", JSON_OBJECT( "type", 'trigger', "iconCls", 'x-fa fa-undo',"weight",-2000) 
                
                ),
                */
                'placeholder', `ds_column_form_label`.`label`,
                'name', `ds_column_form_label`.`column_name`,
                'bind', JSON_OBJECT( 
                    "value",concat('{',`ds_column_form_label`.`column_name`,'}')
                ),
                'listeners', JSON_OBJECT( 
                    'change', 'onFormFieldChanged'
                )
            
            ), view_ds_formfield_merge.obj)
            ,
            JSON_OBJECT(
                'fieldLabel', fieldgroup_label,
                'xtype', 'fieldcontainer',
                'layout', 'hbox',
                'flex',1,   
                'items',
                JSON_MERGE('[]', 
                    concat('[',
                    group_concat(
                        JSON_MERGE(
                        JSON_OBJECT(
        
                            -- 'label', `ds_column_form_label`.`label`,
                            'flex', 1,
                            'xtype',  if(view_readtable_all_types_modern.type is null,'displayfield', `ds_column_form_label`.`xtype`),
                            /*
                            'triggers', JSON_OBJECT(
                                "clear", JSON_OBJECT( "type", 'clear')/*,
                                "undo", JSON_OBJECT( "type", 'trigger', "iconCls", 'x-fa fa-undo',"weight",-2000) 
                              
                            ),
                              */
                            'emptyText', `ds_column_form_label`.`label`,
                            'name', concat(`ds_column_form_label`.`column_name`),
                            'bind', JSON_OBJECT( 
                                "value",concat('{',`ds_column_form_label`.`column_name`,'}')
                            ),
                            'listeners', JSON_OBJECT( 
                                'change', 'onFormFieldChanged'
                            )
                            
                        ), view_ds_formfield_merge.obj)
                        ORDER BY `ds_column_form_label`.`position`
                        separator ','
                    ),
                    ']'
                    )
                )
            )
    
    ) jsfield

from 
    (
        select 
            table_name,
            column_name,
            language,
            label,
            xtype,
            field_path,
            position,
            hidden,
            flex,
            active,
            allowempty,
            fieldgroup fieldgroup_label,
            concat( 
                table_name,
                if(fieldgroup is null or fieldgroup="" or fieldgroup="1",column_name,fieldgroup)
                
            ) fieldgroup
        from `ds_column_form_label` 
    ) 
    
    ds_column_form_label
    join blg_config
        on concat('blg_hdr_',blg_config.tabellenzusatz) = ds_column_form_label.table_name
    join view_ds_formfield_merge
        on view_ds_formfield_merge.table_name = `ds_column_form_label`.`table_name`
        and view_ds_formfield_merge.column_name = `ds_column_form_label`.`column_name`
    

    left join view_readtable_all_types_classic view_readtable_all_types_modern
         on  view_readtable_all_types_modern.type = `ds_column_form_label`.`xtype`
         and typeclass='widget'
where 
    `ds_column_form_label`.`active` = 1
    and `ds_column_form_label`.`hidden` = 0

--    and `ds_column_form_label`.`table_name` = 'adressen'
--    and  field_path='Allgemein/Anschrift'
group by 

    `ds_column_form_label`.`table_name`, 
    `ds_column_form_label`.`field_path`,
    `ds_column_form_label`.`fieldgroup` 
;
-- SOURCE FILE: ./src//500-ui/070-controller/070.view_ds_controller.sql 
delimiter ;

create or replace view view_ds_controller as
select 
    concat(
        'Ext.define(',doublequote(concat('Tualo.DataSets.controller.',UCASE(LEFT(ds.table_name, 1)), lower(SUBSTRING(ds.table_name, 2)))),',',
        JSON_OBJECT(
            "extend", "Tualo.DS.panel.Controller",
            "alias", concat('controller.dsview_',ds.table_name)

        ),
    ')',char(59)) js,
    view_ds_listcolumn.js jsx,
    ds.table_name
from
    ds
    join view_ds_listcolumn 
        on ds.table_name = view_ds_listcolumn.table_name

where
    `ds`.`title`<>''; 
-- SOURCE FILE: ./src//500-ui/071-model/071.view_ds_viewmodel.sql 
create or replace view view_ds_viewmodel as
select 
    concat(
        'Ext.define(',doublequote(concat('Tualo.DataSets.viewmodel.',UCASE(LEFT(ds.table_name, 1)), lower(SUBSTRING(ds.table_name, 2)))),',',
        JSON_OBJECT(
            "extend", "Tualo.DS.panel.Model",
            "alias", concat('viewmodel.dsview_',ds.table_name),
            "data", JSON_OBJECT(
                "record", null,
                "pagerText","",
                "selectRecordRecordNumber",0,
                "reorderfield",ds.reorderfield,
                "disableNext",true,
                "disablePrev",  true,
                "isModified",false,
                "isNew",false,
                "table_name",ds.table_name
            )
        ),
    ')',char(59)) js,
    view_ds_listcolumn.js jsx,
    ds.table_name
from
    ds
    join view_ds_listcolumn 
        on ds.table_name = view_ds_listcolumn.table_name

where
    `ds`.`title`<>'';
-- SOURCE FILE: ./src//500-ui/080-dsview/080.view_ds_dsview.sql 
delimiter ;

/*
    SELECT 

        group_concat( F order by position SEPARATOR ',')
    INTO 
        rendererList
    FROM 
    (
        SELECT
        concat('{
            "xtype": "cmp_ds_pdfrendererpanel",
            "bind": {
                "record": "{record}"
            },
            "border": false,
            style: {
                paddingTop: "1px"
            },

            "title": ',DOUBLEQUOTE(`label`),',
            "template": ',DOUBLEQUOTE(`pug_template`),',
            "useremote": ',useremote,'
        }
        ') F,
        0 position
        FROM (

            select
              pug_template,
              label,
              if(useremote=1,'true','false') useremote
            from
              ds_renderer
            where
              table_name = in_table_name
            order by label
            
        ) RENDERER

        UNION

        SELECT 

            concat(
                '
                {
                    "title": ',DOUBLEQUOTE(`name`),',
                    "xtype": "',lower(`xtype`),'",
                    "bind": {
                        "record": "{record}"
                    },
                    "border": false,
                    "collapsible": false
                }
                '
            ) F,
        1900000+position position

        FROM 
            ds_extended_panels
        WHERE 
            table_name = in_table_name
      
            and active = 1 

    ) A;
*/


create or replace view view_ds_dsview_accordion as
select 
    ds.table_name,
    JSON_OBJECT(
        "title", ifnull(concat('Liste (',ds.title,')'),"Liste"),
        "iconCls", "x-fa fa-th",
        "xtype", concat("dslist_",ds.table_name),
        "bind", JSON_OBJECT(
                -- "store", "{list}",
                "hidden", "{hideList}"
                -- "selection", "{record}"
        ),

        
        "selModel", if(ifnull(ds.listselectionmodel,'')='','rowmodel',ds.listselectionmodel),
        "store", JSON_OBJECT(
            "type", concat("",ds.table_name,"_store"),
            "autoLoad", 1=0
        ),
        "listeners", JSON_OBJECT(
            "drop", "onDropGrid",
            "itemdblclick", 'onItemDblClick' -- ,
            -- "select", "onListSelect"
        ),
        "itemId", "list"
    ) js,
    1000000 position
from ds
union
select
    ds.table_name,
    JSON_OBJECT(
        
        "iconCls", "x-fa fa-clone",
        "bind", JSON_OBJECT(
                -- "store", "{list}",
                "disabled", "{!record}",
                "title", ifnull(concat('Formular (',ds.title,') {record.__displayfield}'),"Formular")
                -- "selection", "{record}"
        ),
        "xtype", 
            if(
                alternativeformxtype is null or alternativeformxtype = '',
                concat("dsform_",ds.table_name),
                alternativeformxtype
            )
        ,
        "itemId", "form"
    ),
    2000000 position
from ds

-- cmp_belege_report_editorform

union 
SELECT
    table_name,
    JSON_OBJECT(
        "iconCls", "x-fa fa-file-pdf",
        "xtype", "cmp_ds_pdfrendererpanel",
        "bind", JSON_OBJECT(
            "record", "{record}"
        ),
        "border", 1=0,
        "title",`label`,
        "template",pug_template,
        "useremote", useremote
    ) js,
    3000000 position
FROM ds_renderer 
;

create or replace view view_ds_dsview as
select 
    concat(
        'Ext.define(',doublequote(concat('Tualo.DataSets.dsview.',UCASE(LEFT(ds.table_name, 1)), lower(SUBSTRING(ds.table_name, 2)))),',',
        JSON_OBJECT(
            "extend", "Tualo.DS.Panel",
            "alias", concat('widget.dsview_',ds.table_name),
            "title", null, -- ds.title,
            "tablename", ds.table_name,

            "controller",concat('dsview_',ds.table_name),
            "viewModel", JSON_OBJECT(
                "type",  concat('dsview_',ds.table_name)
            ),

            "listeners", JSON_OBJECT(
                "boxready", 'onBoxReady'
            ),
            "layout", JSON_OBJECT(
                "type", 'accordion',
                "vertical",  1=0,
                "titleCollapse", 1=1,
                "animate", 1=1,
                "activeOnTop", 1=0
            ),
            "statics", JSON_OBJECT(
                "stores", view_ds_column_stores.stores,
                "globalsearch", JSON_OBJECT(
                    "title", ifnull(ds.title,'not set'),
                    "table_name", ds.table_name,
                    "loadClass", concat('Tualo.DataSets.dsview.',UCASE(LEFT(ds.table_name, 1)), lower(SUBSTRING(ds.table_name, 2))),
                    "hint", ds.hint,
                    "iconCls", "x-fa fa-search",
                    "routeTo", concat("ds/",ds.table_name)
                )
            ),
            "defaults", JSON_OBJECT(
                "headerPosition", "left"
            ),
            
            "items", JSON_ARRAYAGG(
                view_ds_dsview_accordion.js
                order by view_ds_dsview_accordion.position
            )
        )
    ,')',char(59)) js,
    ds.table_name
from ds
    join view_ds_dsview_accordion 
        on view_ds_dsview_accordion.table_name=ds.table_name
    left join view_ds_column_stores on ds.table_name = view_ds_column_stores.table_name
group by ds.table_name
;



-- SOURCE FILE: ./src//999-dsbackup/importance.sql 
DELIMITER //
create table if not exists ds_backup_importance (
  table_name varchar(128) primary key,
  type varchar(20),
  importance decimal(4,3) default 1.0,
  CONSTRAINT `fk_ds_backup_importance_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
) //


-- SOURCE FILE: ./src//999-dssetup/000-ds_column_form_label.sql 
-- BEGIN DS ds_column_form_label
-- NAME: Formular

insert into `ds`
                    (`table_name`)
                    values
                    ('ds_column_form_label')
                    on duplicate key update `table_name`=values(`table_name`);
update `ds` set `title`='Formular',`reorderfield`='position',`use_history`='0',`searchfield`='column_name',`displayfield`='column_name',`sortfield`='position',`searchany`='1',`hint`='',`overview_tpl`='',`sync_table`='',`writetable`='',`globalsearch`='0',`listselectionmodel`='cellmodel',`sync_view`='',`syncable`='0',`cssstyle`='',`alternativeformxtype`='',`read_table`='view_readtable_ds_column_form_label',`class_name`='Datenstamm',`special_add_panel`='',`existsreal`='1',`character_set_name`='',`read_filter`='',`listxtypeprefix`='listview',`phpexporter`='XlsxWriter',`phpexporterfilename`='{GUID}',`combined`='0',`default_pagesize`='100',`allowForm`= 0 ,`listviewbaseclass`='Tualo.DataSets.ListView',`showactionbtn`='1' where `table_name`='ds_column_form_label';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_form_label','active')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='1',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='tinyint',`column_key`='',`column_type`='int(4)',`character_maximum_length`='0',`numeric_precision`='10',`numeric_scale`='0',`character_set_name`='',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='active';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_form_label','allowempty')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='tinyint',`column_key`='',`column_type`='int(4)',`character_maximum_length`='0',`numeric_precision`='10',`numeric_scale`='0',`character_set_name`='',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='allowempty';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_form_label','column_name')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='1',`syncable`='0',`referenced_table`='ds_column',`referenced_column_name`='column_name',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='PRI',`column_type`='varchar(100)',`character_maximum_length`='100',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='column_name';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_form_label','fieldgroup')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='YES',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(50)',`character_maximum_length`='50',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='fieldgroup';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_form_label','field_path')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='Allgemein',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(255)',`character_maximum_length`='255',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='field_path';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_form_label','hidden')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='0',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='tinyint',`column_key`='',`column_type`='int(4)',`character_maximum_length`='0',`numeric_precision`='10',`numeric_scale`='0',`character_set_name`='',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='hidden';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_form_label','label')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='{column_name}',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(255)',`character_maximum_length`='255',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='label';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_form_label','language')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='DE',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='1',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='PRI',`column_type`='varchar(3)',`character_maximum_length`='3',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='language';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_form_label','position')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='0',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='int',`column_key`='',`column_type`='int(11)',`character_maximum_length`='0',`numeric_precision`='10',`numeric_scale`='0',`character_set_name`='',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='position';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_form_label','table_name')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='1',`syncable`='0',`referenced_table`='ds_column',`referenced_column_name`='table_name',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='PRI',`column_type`='varchar(128)',`character_maximum_length`='128',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='table_name';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_form_label','xtype')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='displayfield',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(255)',`character_maximum_length`='255',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='xtype';
insert into `ds_access`
                    (`role`,`table_name`)
                    values
                    ('administration','ds_column_form_label')
                    on duplicate key update `role`=values(`role`),`table_name`=values(`table_name`);
update `ds_access` set `read`='1',`write`='1',`delete`='0',`append`='0',`existsreal`='1' where `role`='administration' and `table_name`='ds_column_form_label';
insert into `ds_access`
                    (`role`,`table_name`)
                    values
                    ('_default_','ds_column_form_label')
                    on duplicate key update `role`=values(`role`),`table_name`=values(`table_name`);
update `ds_access` set `read`='0',`write`='0',`delete`='0',`append`='0',`existsreal`='1' where `role`='_default_' and `table_name`='ds_column_form_label';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_form_label','active','DE','Aktiv','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='checkbox',`position`='7',`hidden`='0',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_form_label' and `column_name`='active' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_form_label','column_name','DE','Spalte','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='1',`hidden`='0',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_form_label' and `column_name`='column_name' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_form_label','field_path','DE','Pfad','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='textfield',`position`='2',`hidden`='0',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_form_label' and `column_name`='field_path' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_form_label','hidden','DE','ausgeblendet','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='checkbox',`position`='8',`hidden`='0',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_form_label' and `column_name`='hidden' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_form_label','label','DE','Label','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='textfield',`position`='3',`hidden`='0',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_form_label' and `column_name`='label' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_form_label','language','DE','Sprache','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='5',`hidden`='1',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_form_label' and `column_name`='language' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_form_label','position','DE','Position','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='6',`hidden`='1',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_form_label' and `column_name`='position' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_form_label','table_name','DE','Tabelle','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='0',`hidden`='1',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_form_label' and `column_name`='table_name' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_form_label','xtype','DE','Typ','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='formxtype_combobox',`position`='4',`hidden`='0',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_form_label' and `column_name`='xtype' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_form_label','active','DE','Aktiv')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='checkcolumn',`editor`='',`position`='7',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='active' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_form_label','allowempty','DE','Leer erlaubt')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='checkcolumn',`editor`='',`position`='8',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='allowempty' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_form_label','column_name','DE','Spalte')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='1',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='column_name' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_form_label','field_path','DE','Pfad')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='textfield',`position`='2',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='field_path' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_form_label','hidden','DE','ausgeblendet')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='checkcolumn',`editor`='',`position`='8',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='hidden' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_form_label','label','DE','Label')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='textfield',`position`='3',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='label' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_form_label','language','DE','Sparche')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='5',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='1',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='language' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_form_label','position','DE','Position')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='6',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='1',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='position' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_form_label','table_name','DE','Tabelle')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='0',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='1',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='table_name' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_form_label','xtype','DE','Type')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='formxtype_combobox',`position`='4',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_form_label' and `column_name`='xtype' and `language`='DE';
insert into `ds_nm_tables`
                    (`table_name`,`constraint_name`,`referenced_constraint_name`,`language`,`label`)
                    values
                    ('ds_column_form_label','fk_ds_column_form_properties_form','fk_ds_column_form_properties_property','DE','')
                    on duplicate key update `table_name`=values(`table_name`),`constraint_name`=values(`constraint_name`),`referenced_constraint_name`=values(`referenced_constraint_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_nm_tables` set `referenced_table_name`='ds_form_properties',`intermedia_table_name`='ds_column_form_properties',`position`='99',`hidden`='0',`active`='0',`table_name_json`='{\"ds_column_form_properties__table_name\":\"ds_column_form_label__table_name\",\"ds_column_form_properties__column_name\":\"ds_column_form_label__column_name\"}',`referenced_table_json`='{\"ds_column_form_properties__property\":\"ds_form_properties__property\",\"ds_column_form_properties__property\":\"ds_form_properties__property\"}' where `table_name`='ds_column_form_label' and `constraint_name`='fk_ds_column_form_properties_form' and `referenced_constraint_name`='fk_ds_column_form_properties_property';
insert into `ds_reference_tables`
                    (`table_name`,`reference_table_name`,`constraint_name`)
                    values
                    ('ds_column_form_label','ds','fk_ds_column_form_label_ds')
                    on duplicate key update `table_name`=values(`table_name`),`reference_table_name`=values(`reference_table_name`),`constraint_name`=values(`constraint_name`);
update `ds_reference_tables` set `columnsdef`='{\"ds_column_form_label__table_name\":\"ds__table_name\"}',`active`='1',`searchable`='0',`autosync`='1',`position`='99999',`path`='' where `table_name`='ds_column_form_label' and `reference_table_name`='ds' and `constraint_name`='fk_ds_column_form_label_ds';
-- END DS ds_column_form_label



-- SOURCE FILE: ./src//999-dssetup/000-ds_column_form_properties.sql 
-- BEGIN DS ds_column_form_properties
-- NAME: Erweiterte Eigenschaften

insert into `ds`
                    (`table_name`)
                    values
                    ('ds_column_form_properties')
                    on duplicate key update `table_name`=values(`table_name`);
update `ds` set `title`='Erweiterte Eigenschaften',`reorderfield`='',`use_history`='0',`searchfield`='property',`displayfield`='property',`sortfield`='property',`searchany`='1',`hint`='',`overview_tpl`='',`sync_table`='',`writetable`='',`globalsearch`='0',`listselectionmodel`='tualomultirowmodel',`sync_view`='',`syncable`='0',`cssstyle`='',`alternativeformxtype`='',`read_table`='',`class_name`='Datenstamm',`special_add_panel`='',`existsreal`='1',`character_set_name`='',`read_filter`='',`listxtypeprefix`='listview',`phpexporter`='XlsxWriter',`phpexporterfilename`='',`combined`='0',`default_pagesize`='100',`allowForm`= 1 ,`listviewbaseclass`='Tualo.DataSets.ListView',`showactionbtn`='1' where `table_name`='ds_column_form_properties';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_form_properties','column_name')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='1',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='PRI',`column_type`='varchar(100)',`character_maximum_length`='100',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_form_properties' and `column_name`='column_name';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_form_properties','property')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='1',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='PRI',`column_type`='varchar(32)',`character_maximum_length`='32',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_form_properties' and `column_name`='property';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_form_properties','table_name')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='1',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='PRI',`column_type`='varchar(128)',`character_maximum_length`='128',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_form_properties' and `column_name`='table_name';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_form_properties','value')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(255)',`character_maximum_length`='255',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_form_properties' and `column_name`='value';
insert into `ds_access`
                    (`role`,`table_name`)
                    values
                    ('administration','ds_column_form_properties')
                    on duplicate key update `role`=values(`role`),`table_name`=values(`table_name`);
update `ds_access` set `read`='1',`write`='1',`delete`='1',`append`='1',`existsreal`='0' where `role`='administration' and `table_name`='ds_column_form_properties';
insert into `ds_access`
                    (`role`,`table_name`)
                    values
                    ('_default_','ds_column_form_properties')
                    on duplicate key update `role`=values(`role`),`table_name`=values(`table_name`);
update `ds_access` set `read`='1',`write`='0',`delete`='0',`append`='0',`existsreal`='0' where `role`='_default_' and `table_name`='ds_column_form_properties';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_form_properties','column_name','DE','Spalte','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='1',`hidden`='0',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_form_properties' and `column_name`='column_name' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_form_properties','property','DE','Eigenschaft','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='combobox_ds_form_properties_property',`position`='2',`hidden`='0',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_form_properties' and `column_name`='property' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_form_properties','table_name','DE','Tabelle','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='0',`hidden`='0',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_form_properties' and `column_name`='table_name' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_form_properties','value','DE','Wert','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='textfield',`position`='3',`hidden`='0',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_form_properties' and `column_name`='value' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_form_properties','column_name','DE','Spalte')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='1',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_form_properties' and `column_name`='column_name' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_form_properties','property','DE','Eigenschaft')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='2',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_form_properties' and `column_name`='property' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_form_properties','table_name','DE','Tabelle')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='0',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_form_properties' and `column_name`='table_name' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_form_properties','value','DE','Wert')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='3',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_form_properties' and `column_name`='value' and `language`='DE';
insert into `ds_reference_tables`
                    (`table_name`,`reference_table_name`,`constraint_name`)
                    values
                    ('ds_column_form_properties','ds_column_form_label','fk_ds_column_form_properties_form')
                    on duplicate key update `table_name`=values(`table_name`),`reference_table_name`=values(`reference_table_name`),`constraint_name`=values(`constraint_name`);
update `ds_reference_tables` set `columnsdef`='{\"ds_column_form_properties__column_name\":\"ds_column_form_label__column_name\",\"ds_column_form_properties__table_name\":\"ds_column_form_label__table_name\"}',`active`='0',`searchable`='0',`autosync`='1',`position`='99999',`path`='' where `table_name`='ds_column_form_properties' and `reference_table_name`='ds_column_form_label' and `constraint_name`='fk_ds_column_form_properties_form';
insert into `ds_reference_tables`
                    (`table_name`,`reference_table_name`,`constraint_name`)
                    values
                    ('ds_column_form_properties','ds_form_properties','fk_ds_column_form_properties_property')
                    on duplicate key update `table_name`=values(`table_name`),`reference_table_name`=values(`reference_table_name`),`constraint_name`=values(`constraint_name`);
update `ds_reference_tables` set `columnsdef`='{\"ds_column_form_properties__property\":\"ds_form_properties__property\"}',`active`='0',`searchable`='0',`autosync`='1',`position`='99999',`path`='' where `table_name`='ds_column_form_properties' and `reference_table_name`='ds_form_properties' and `constraint_name`='fk_ds_column_form_properties_property';
-- END DS ds_column_form_properties



-- SOURCE FILE: ./src//999-dssetup/000-ds_column_list_label.sql 
-- BEGIN DS ds_column_list_label
-- NAME: Liste

insert into `ds`
                    (`table_name`)
                    values
                    ('ds_column_list_label')
                    on duplicate key update `table_name`=values(`table_name`);
update `ds` set `title`='Liste',`reorderfield`='position',`use_history`='0',`searchfield`='column_name',`displayfield`='column_name',`sortfield`='position',`searchany`='1',`hint`='',`overview_tpl`='',`sync_table`='',`writetable`='',`globalsearch`='0',`listselectionmodel`='cellmodel',`sync_view`='',`syncable`='0',`cssstyle`='',`alternativeformxtype`='',`read_table`='view_readtable_ds_column_list_label_all',`class_name`='Datenstamm',`special_add_panel`='',`existsreal`='1',`character_set_name`='',`read_filter`='',`listxtypeprefix`='listview',`phpexporter`='XlsxWriter',`phpexporterfilename`='{GUID}',`combined`='0',`default_pagesize`='100',`allowForm`= 0 ,`listviewbaseclass`='Tualo.DataSets.ListView',`showactionbtn`='1' where `table_name`='ds_column_list_label';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','active')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='1',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='tinyint',`column_key`='',`column_type`='int(4)',`character_maximum_length`='0',`numeric_precision`='10',`numeric_scale`='0',`character_set_name`='',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='active';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','align')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='YES',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(8)',`character_maximum_length`='8',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='align';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','character_maximum_length')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='YES',`is_referenced`='',`writeable`='0',`note`='',`data_type`='bigint',`column_key`='',`column_type`='bigint(20)',`character_maximum_length`='0',`numeric_precision`='19',`numeric_scale`='0',`character_set_name`='',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='character_maximum_length';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','column_key')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='YES',`is_referenced`='',`writeable`='0',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(255)',`character_maximum_length`='255',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='column_key';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','column_name')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='1',`syncable`='0',`referenced_table`='ds_column',`referenced_column_name`='column_name',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='PRI',`column_type`='varchar(100)',`character_maximum_length`='100',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='column_name';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','column_type')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='YES',`is_referenced`='',`writeable`='0',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(255)',`character_maximum_length`='255',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='column_type';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','data_type')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='YES',`is_referenced`='',`writeable`='0',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(255)',`character_maximum_length`='255',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='data_type';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','default_value')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='YES',`is_referenced`='',`writeable`='0',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(255)',`character_maximum_length`='255',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='default_value';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','direction')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='YES',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(5)',`character_maximum_length`='5',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='direction';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','editor')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(255)',`character_maximum_length`='255',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='editor';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','filterstore')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(255)',`character_maximum_length`='255',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='filterstore';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','flex')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='decimal',`column_key`='',`column_type`='decimal(5,2)',`character_maximum_length`='0',`numeric_precision`='5',`numeric_scale`='2',`character_set_name`='',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='flex';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','grouped')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='0',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='tinyint',`column_key`='',`column_type`='int(4)',`character_maximum_length`='0',`numeric_precision`='10',`numeric_scale`='0',`character_set_name`='',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='grouped';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','hidden')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='0',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='tinyint',`column_key`='',`column_type`='int(4)',`character_maximum_length`='0',`numeric_precision`='10',`numeric_scale`='0',`character_set_name`='',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='hidden';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','hint')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='NULL',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(255)',`character_maximum_length`='255',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='hint';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','label')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(255)',`character_maximum_length`='255',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='label';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','language')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='DE',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='1',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='PRI',`column_type`='varchar(3)',`character_maximum_length`='3',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='language';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','listfiltertype')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(255)',`character_maximum_length`='255',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='listfiltertype';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','numeric_precision')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='YES',`is_referenced`='',`writeable`='0',`note`='',`data_type`='int',`column_key`='',`column_type`='int(11)',`character_maximum_length`='0',`numeric_precision`='10',`numeric_scale`='0',`character_set_name`='',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='numeric_precision';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','numeric_scale')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='YES',`is_referenced`='',`writeable`='0',`note`='',`data_type`='int',`column_key`='',`column_type`='int(11)',`character_maximum_length`='0',`numeric_precision`='10',`numeric_scale`='0',`character_set_name`='',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='numeric_scale';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','position')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='0',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='int',`column_key`='',`column_type`='int(11)',`character_maximum_length`='0',`numeric_precision`='10',`numeric_scale`='0',`character_set_name`='',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='position';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','renderer')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(255)',`character_maximum_length`='255',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='renderer';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','summaryrenderer')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(255)',`character_maximum_length`='255',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='summaryrenderer';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','summarytype')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(255)',`character_maximum_length`='255',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='summarytype';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','table_name')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='1',`syncable`='0',`referenced_table`='ds_column',`referenced_column_name`='table_name',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='PRI',`column_type`='varchar(128)',`character_maximum_length`='128',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='table_name';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_column_list_label','xtype')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='gridcolumn',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(255)',`character_maximum_length`='255',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='xtype';
insert into `ds_access`
                    (`role`,`table_name`)
                    values
                    ('administration','ds_column_list_label')
                    on duplicate key update `role`=values(`role`),`table_name`=values(`table_name`);
update `ds_access` set `read`='1',`write`='1',`delete`='0',`append`='0',`existsreal`='1' where `role`='administration' and `table_name`='ds_column_list_label';
insert into `ds_access`
                    (`role`,`table_name`)
                    values
                    ('_default_','ds_column_list_label')
                    on duplicate key update `role`=values(`role`),`table_name`=values(`table_name`);
update `ds_access` set `read`='0',`write`='0',`delete`='0',`append`='0',`existsreal`='1' where `role`='_default_' and `table_name`='ds_column_list_label';
insert into `ds_addcommands`
                    (`table_name`,`xtype`)
                    values
                    ('ds_column_list_label','ds_cloneformlabel_command')
                    on duplicate key update `table_name`=values(`table_name`),`xtype`=values(`xtype`);
update `ds_addcommands` set `location`='toolbar',`position`='1',`label`='' where `table_name`='ds_column_list_label' and `xtype`='ds_cloneformlabel_command';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_list_label','active','DE','active','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='5',`hidden`='1',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_list_label' and `column_name`='active' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_list_label','column_name','DE','column_name','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='1',`hidden`='1',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_list_label' and `column_name`='column_name' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_list_label','editor','DE','editor','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='3',`hidden`='1',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_list_label' and `column_name`='editor' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_list_label','filterstore','DE','filterstore','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='4',`hidden`='1',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_list_label' and `column_name`='filterstore' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_list_label','grouped','DE','grouped','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='999',`hidden`='1',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_list_label' and `column_name`='grouped' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_list_label','hidden','DE','hidden','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='6',`hidden`='1',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_list_label' and `column_name`='hidden' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_list_label','label','DE','label','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='2',`hidden`='1',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_list_label' and `column_name`='label' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_list_label','language','DE','language','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='7',`hidden`='1',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_list_label' and `column_name`='language' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_list_label','position','DE','position','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='8',`hidden`='1',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_list_label' and `column_name`='position' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_list_label','summaryrenderer','DE','summaryrenderer','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='9',`hidden`='1',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_list_label' and `column_name`='summaryrenderer' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_list_label','summarytype','DE','summarytype','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='10',`hidden`='1',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_list_label' and `column_name`='summarytype' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_list_label','table_name','DE','table_name','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='0',`hidden`='1',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_list_label' and `column_name`='table_name' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_column_list_label','xtype','DE','xtype','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='12',`hidden`='1',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_column_list_label' and `column_name`='xtype' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_list_label','active','DE','Aktiv')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='checkcolumn',`editor`='',`position`='5',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='active' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_list_label','align','DE','align')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='0',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='1',`active`='0',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='',`align`='',`listfiltertype`='',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='align' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_list_label','column_name','DE','Spalte')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='1',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='column_name' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_list_label','direction','DE','direction')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='2',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='1',`active`='0',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='',`align`='',`listfiltertype`='',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='direction' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_list_label','editor','DE','Editor')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='formxtype_combobox',`position`='4',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='editor' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_list_label','filterstore','DE','Filter')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='textfield',`position`='10',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='1',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='filterstore' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_list_label','flex','DE','flex')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='1',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='1',`active`='0',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='',`align`='',`listfiltertype`='',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='flex' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_list_label','grouped','DE','Gruppieren')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='checkcolumn',`editor`='',`position`='999',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='grouped' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_list_label','hidden','DE','ausgeblendet')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='checkcolumn',`editor`='',`position`='6',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='hidden' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_list_label','hint','DE','Hinweis')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='textfield',`position`='999',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='1',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='',`align`='',`listfiltertype`='',`hint`='NULL' where `table_name`='ds_column_list_label' and `column_name`='hint' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_list_label','label','DE','Label')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='textfield',`position`='2',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='label' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_list_label','language','DE','Sprache')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='8',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='1',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='language' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_list_label','listfiltertype','DE','Filtertyp')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='combobox_view_ds_listfilters_id',`position`='14',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='1',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='',`align`='',`listfiltertype`='',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='listfiltertype' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_list_label','position','DE','Position')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='numbercolumn',`editor`='',`position`='9',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='1',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='position' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_list_label','renderer','DE','renderer')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='textfield',`position`='999',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='1',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='renderer' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_list_label','summaryrenderer','DE','Sum. Renderer')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='textfield',`position`='12',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='1',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='summaryrenderer' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_list_label','summarytype','DE','Sum. Typ')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='textfield',`position`='11',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='1',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='summarytype' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_list_label','table_name','DE','Tabelle')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='0',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='1',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='table_name' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_column_list_label','xtype','DE','Typ')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='listxtype_combobox',`position`='3',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_column_list_label' and `column_name`='xtype' and `language`='DE';
insert into `ds_reference_tables`
                    (`table_name`,`reference_table_name`,`constraint_name`)
                    values
                    ('ds_column_list_label','ds','fk_ds_column_list_label_ds')
                    on duplicate key update `table_name`=values(`table_name`),`reference_table_name`=values(`reference_table_name`),`constraint_name`=values(`constraint_name`);
update `ds_reference_tables` set `columnsdef`='{\"ds_column_list_label__table_name\":\"ds__table_name\"}',`active`='1',`searchable`='0',`autosync`='1',`position`='99999',`path`='' where `table_name`='ds_column_list_label' and `reference_table_name`='ds' and `constraint_name`='fk_ds_column_list_label_ds';
-- END DS ds_column_list_label



-- SOURCE FILE: ./src//999-dssetup/000-ds_reference_tables.sql 
-- BEGIN DS ds_reference_tables
-- NAME: Referenzen

insert into `ds`
                    (`table_name`)
                    values
                    ('ds_reference_tables')
                    on duplicate key update `table_name`=values(`table_name`);
update `ds` set `title`='Referenzen',`reorderfield`='',`use_history`='0',`searchfield`='reference_table_name',`displayfield`='reference_table_name',`sortfield`='reference_table_name',`searchany`='1',`hint`='',`overview_tpl`='',`sync_table`='',`writetable`='',`globalsearch`='0',`listselectionmodel`='',`sync_view`='',`syncable`='0',`cssstyle`='',`alternativeformxtype`='',`read_table`='',`class_name`='Datenstamm',`special_add_panel`='',`existsreal`='1',`character_set_name`='',`read_filter`='',`listxtypeprefix`='listview',`phpexporter`='XlsxWriter',`phpexporterfilename`='{GUID}',`combined`='0',`default_pagesize`='100',`allowForm`= 0 ,`listviewbaseclass`='Tualo.DataSets.ListView',`showactionbtn`='1' where `table_name`='ds_reference_tables';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_reference_tables','active')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='YES',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='tinyint',`column_key`='',`column_type`='tinyint(4)',`character_maximum_length`='0',`numeric_precision`='3',`numeric_scale`='0',`character_set_name`='',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_reference_tables' and `column_name`='active';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_reference_tables','autosync')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='YES',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='tinyint',`column_key`='',`column_type`='tinyint(4)',`character_maximum_length`='0',`numeric_precision`='3',`numeric_scale`='0',`character_set_name`='',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_reference_tables' and `column_name`='autosync';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_reference_tables','columnsdef')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='YES',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='longtext',`column_key`='',`column_type`='longtext',`character_maximum_length`='4294967295',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_reference_tables' and `column_name`='columnsdef';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_reference_tables','constraint_name')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='1',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='PRI',`column_type`='varchar(128)',`character_maximum_length`='128',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_reference_tables' and `column_name`='constraint_name';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_reference_tables','path')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='\'\'',`default_max_value`='0',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='YES',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='',`column_type`='varchar(100)',`character_maximum_length`='100',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_reference_tables' and `column_name`='path';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_reference_tables','position')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='YES',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='int',`column_key`='',`column_type`='int(11)',`character_maximum_length`='0',`numeric_precision`='10',`numeric_scale`='0',`character_set_name`='',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_reference_tables' and `column_name`='position';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_reference_tables','reference_table_name')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='1',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='PRI',`column_type`='varchar(100)',`character_maximum_length`='100',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_reference_tables' and `column_name`='reference_table_name';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_reference_tables','searchable')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='0',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='YES',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='tinyint',`column_key`='',`column_type`='tinyint(4)',`character_maximum_length`='0',`numeric_precision`='3',`numeric_scale`='0',`character_set_name`='',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_reference_tables' and `column_name`='searchable';
insert into `ds_column`
                    (`table_name`,`column_name`)
                    values
                    ('ds_reference_tables','table_name')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`);
update `ds_column` set `default_value`='',`default_max_value`='10000000',`default_min_value`='0',`update_value`='',`is_primary`='1',`syncable`='0',`referenced_table`='',`referenced_column_name`='',`is_nullable`='NO',`is_referenced`='NO',`writeable`='1',`note`='',`data_type`='varchar',`column_key`='PRI',`column_type`='varchar(128)',`character_maximum_length`='128',`numeric_precision`='0',`numeric_scale`='0',`character_set_name`='utf8',`privileges`='select,insert,update,references',`existsreal`='1',`deferedload`='0',`hint`='' where `table_name`='ds_reference_tables' and `column_name`='table_name';
insert into `ds_access`
                    (`role`,`table_name`)
                    values
                    ('administration','ds_reference_tables')
                    on duplicate key update `role`=values(`role`),`table_name`=values(`table_name`);
update `ds_access` set `read`='1',`write`='1',`delete`='0',`append`='0',`existsreal`='1' where `role`='administration' and `table_name`='ds_reference_tables';
insert into `ds_access`
                    (`role`,`table_name`)
                    values
                    ('_default_','ds_reference_tables')
                    on duplicate key update `role`=values(`role`),`table_name`=values(`table_name`);
update `ds_access` set `read`='0',`write`='0',`delete`='0',`append`='0',`existsreal`='1' where `role`='_default_' and `table_name`='ds_reference_tables';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_reference_tables','constraint_name','DE','constraint_name','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='0',`hidden`='0',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_reference_tables' and `column_name`='constraint_name' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_reference_tables','reference_table_name','DE','reference_table_name','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='0',`hidden`='0',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_reference_tables' and `column_name`='reference_table_name' and `language`='DE';
insert into `ds_column_form_label`
                    (`table_name`,`column_name`,`language`,`label`,`field_path`)
                    values
                    ('ds_reference_tables','table_name','DE','table_name','Allgemein')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`),`field_path`=values(`field_path`);
update `ds_column_form_label` set `xtype`='displayfield',`position`='0',`hidden`='0',`active`='1',`allowempty`='1',`fieldgroup`='' where `table_name`='ds_reference_tables' and `column_name`='table_name' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_reference_tables','active','DE','Aktiv')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='checkcolumn',`editor`='',`position`='999',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_reference_tables' and `column_name`='active' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_reference_tables','autosync','DE','auto. Sync')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='0',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_reference_tables' and `column_name`='autosync' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_reference_tables','columnsdef','DE','columnsdef')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='999',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='1',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_reference_tables' and `column_name`='columnsdef' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_reference_tables','constraint_name','DE','Name')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='999',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_reference_tables' and `column_name`='constraint_name' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_reference_tables','reference_table_name','DE','reference_table_name')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='999',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_reference_tables' and `column_name`='reference_table_name' and `language`='DE';
insert into `ds_column_list_label`
                    (`table_name`,`column_name`,`language`,`label`)
                    values
                    ('ds_reference_tables','table_name','DE','Tabelle')
                    on duplicate key update `table_name`=values(`table_name`),`column_name`=values(`column_name`),`language`=values(`language`),`label`=values(`label`);
update `ds_column_list_label` set `xtype`='gridcolumn',`editor`='',`position`='999',`summaryrenderer`='',`renderer`='',`summarytype`='',`hidden`='0',`active`='1',`filterstore`='',`grouped`='0',`flex`='1.00',`direction`='ASC',`align`='left',`listfiltertype`='',`hint`='' where `table_name`='ds_reference_tables' and `column_name`='table_name' and `language`='DE';
insert into `ds_reference_tables`
                    (`table_name`,`reference_table_name`,`constraint_name`)
                    values
                    ('ds_reference_tables','ds','fk_ds_reference_tables_ds')
                    on duplicate key update `table_name`=values(`table_name`),`reference_table_name`=values(`reference_table_name`),`constraint_name`=values(`constraint_name`);
update `ds_reference_tables` set `columnsdef`='{\"ds_reference_tables__table_name\":\"ds__table_name\"}',`active`='1',`searchable`='0',`autosync`='1',`position`='99999',`path`='' where `table_name`='ds_reference_tables' and `reference_table_name`='ds' and `constraint_name`='fk_ds_reference_tables_ds';
insert into `ds_reference_tables`
                    (`table_name`,`reference_table_name`,`constraint_name`)
                    values
                    ('ds_reference_tables','ds','fk_ds_reference_tables_r_ds')
                    on duplicate key update `table_name`=values(`table_name`),`reference_table_name`=values(`reference_table_name`),`constraint_name`=values(`constraint_name`);
update `ds_reference_tables` set `columnsdef`='{\"ds_reference_tables__reference_table_name\":\"ds__table_name\"}',`active`='1',`searchable`='0',`autosync`='1',`position`='99999',`path`='' where `table_name`='ds_reference_tables' and `reference_table_name`='ds' and `constraint_name`='fk_ds_reference_tables_r_ds';
-- END DS ds_reference_tables



