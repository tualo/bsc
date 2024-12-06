DELIMITER ;;
CREATE OR REPLACE FUNCTION   `dsx_rest_api_unescape`(data longtext) RETURNS longtext  
    DETERMINISTIC
BEGIN 
    set data = REPLACE(data,concat(char(92),'"'),'"');
    set data = REPLACE(data,concat(char(92),'f'),char(12));
    set data = REPLACE(data,concat(char(92),'n'),char(10));
    set data = REPLACE(data,concat(char(92),'t'),char(9));
    set data = REPLACE(data,concat(char(92),'t'),char(13));
    return data;    
END ;;