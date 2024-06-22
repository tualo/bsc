DELIMITER //
CREATE FUNCTION IF NOT EXISTS `doublequote`(txt longtext)
RETURNS longtext
NO SQL
BEGIN 
    RETURN CONCAT('"',REPLACE(txt,'"','\"'),'"');
END //