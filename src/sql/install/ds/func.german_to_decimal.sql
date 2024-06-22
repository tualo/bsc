DELIMITER //
CREATE FUNCTION IF NOT EXISTS `german_to_decimal`(str varchar(100) ) RETURNS decimal(10,2)
    DETERMINISTIC
BEGIN 
    return cast( replace(replace(str,'.',''),',','.') as decimal(10,2));
END //