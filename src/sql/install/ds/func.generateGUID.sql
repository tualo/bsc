
DELIMITER //
CREATE FUNCTION IF NOT EXISTS `generateGUID`(length integer) RETURNS varchar(255) CHARSET utf8mb4 COLLATE utf8mb4_general_ci
    DETERMINISTIC
BEGIN
    DECLARE result varchar(255);
    SET result = '';


    WHILE length(result)<length DO
        SET result = concat(result, char( 90-floor(rand()*26)) );
    END WHILE;

    return result;

END //