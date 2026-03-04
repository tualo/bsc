DELIMITER //
CREATE OR REPLACE FUNCTION `doublequote`(txt longtext)
RETURNS longtext
NO SQL
BEGIN 
    RETURN CONCAT('"',REPLACE(txt,'"','\"'),'"');
END //