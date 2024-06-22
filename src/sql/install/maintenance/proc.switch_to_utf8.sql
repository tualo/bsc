DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `switch_to_utf8`(
  IN in_dbname varchar(150)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE loop_t_name VARCHAR(255);
    DECLARE collate_name VARCHAR(150);
    DECLARE cur CURSOR FOR select table_name from information_schema.tables where table_schema=in_dbname and TABLE_TYPE='BASE TABLE';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    select COLLATION_NAME into collate_name from INFORMATION_SCHEMA.COLLATIONS WHERE CHARACTER_SET_NAME = 'utf8' and `is_default` ='Yes' ;


    SET foreign_key_checks = 0;

    OPEN cur;
    read_loop: LOOP
    FETCH cur INTO loop_t_name;
    IF done THEN
        LEAVE read_loop;
    END IF;

    select loop_t_name msg;
    SET @s=concat('ALTER TABLE ',in_dbname,'.',loop_t_name, ' CONVERT TO CHARACTER SET utf8 COLLATE ',collate_name,' ');
    select @s msg;
    PREPARE stmt1 FROM @s;
    execute stmt1;
    DEALLOCATE PREPARE stmt1;

    END LOOP;
    CLOSE cur;

    SET @s=concat('YOU SHOULD CALL: ',char(10),'ALTER DATABASE ',in_dbname,' CHARACTER SET utf8 COLLATE ',collate_name,' ');
    select @s msg;
    
    SET foreign_key_checks = 1;


END //