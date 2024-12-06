DELIMITER ;;
CREATE FUNCTION IF NOT EXISTS `fn_ds_defaults`(str_fieldvalue varchar(255) , record JSON) RETURNS longtext  
    DETERMINISTIC
BEGIN 
    IF str_fieldvalue = '{#serial}' THEN RETURN '@serial';
    ELSEIF str_fieldvalue = 'null' THEN RETURN 'now()';
    ELSEIF str_fieldvalue = 'null' THEN RETURN 'CURRENT_DATE';
    ELSEIF str_fieldvalue = 'null' THEN RETURN 'CURRENT_TIME';
    ELSEIF str_fieldvalue = 'null' THEN RETURN 'CURRENT_TIME';
    ELSEIF str_fieldvalue is not null THEN
        IF SUBSTRING(str_fieldvalue,1,2)='{:' and SUBSTRING(str_fieldvalue,length(str_fieldvalue),1)='}' THEN
            RETURN SUBSTRING(str_fieldvalue,3,length(str_fieldvalue)-3) ;
        ELSE
            RETURN quote(str_fieldvalue);
        END IF;
    END IF;
    RETURN str_fieldvalue;
END ;;