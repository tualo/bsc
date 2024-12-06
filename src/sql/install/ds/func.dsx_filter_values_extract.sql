DELIMITER //
CREATE or replace function `dsx_filter_values_extract`(request JSON,  dtype varchar(36) ) RETURNS longtext 
    DETERMINISTIC
BEGIN 
    DECLARE _type varchar(36);
    DECLARE i int;
    DECLARE row_count int;
    DECLARE result LONGTEXT default '';
    DECLARE term LONGTEXT default '';

    IF JSON_VALID(request)=0 THEN 
        RETURN doublequote(request);
    END IF;
    
    SET _type = JSON_TYPE( request );
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