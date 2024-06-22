DELIMITER ;;
CREATE FUNCTION IF NOT EXISTS `dsx_rest_api_unescape`(data longtext) RETURNS longtext CHARSET utf8mb4 COLLATE utf8mb4_general_ci
    DETERMINISTIC
BEGIN 
    set data = REPLACE(data,concat(char(92),'"'),'"');
    set data = REPLACE(data,concat(char(92),'f'),char(12));
    set data = REPLACE(data,concat(char(92),'n'),char(10));
    set data = REPLACE(data,concat(char(92),'t'),char(9));
    set data = REPLACE(data,concat(char(92),'t'),char(13));
    return data;    
END ;;