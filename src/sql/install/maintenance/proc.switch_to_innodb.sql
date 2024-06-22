DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `switch_to_innodb`(
  IN in_dbname varchar(150)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE loop_t_name VARCHAR(50);

    DECLARE cur CURSOR FOR select table_name from information_schema.tables where table_schema=in_dbname and engine<>'INNODB';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;


    OPEN cur;
    read_loop: LOOP
    FETCH cur INTO loop_t_name;
    IF done THEN
        LEAVE read_loop;
    END IF;
    select concat('switch ',in_dbname,'.',loop_t_name,' to innodb') msg;
    SET @s=concat('alter table ',in_dbname,'.',loop_t_name,' engine innodb');
    PREPARE stmt1 FROM @s;
    execute stmt1;
    DEALLOCATE PREPARE stmt1;

    END LOOP;
    CLOSE cur;

    select concat('tables not innodb on ',in_dbname) msg;
    select table_name from information_schema.tables where table_schema=in_dbname and engine<>'INNODB';

END //