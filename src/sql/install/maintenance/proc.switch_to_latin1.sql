DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `switch_to_latin1`(
  IN in_dbname varchar(150)
)
    MODIFIES SQL DATA
BEGIN
DECLARE done INT DEFAULT FALSE;
DECLARE loop_t_name VARCHAR(50);
DECLARE collate_name VARCHAR(150);
DECLARE cur CURSOR FOR select table_name from information_schema.tables where table_schema=in_dbname and TABLE_TYPE='BASE TABLE' and table_collation <>'latin1_swedish_ci';
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;



SET foreign_key_checks = 0;

OPEN cur;
read_loop: LOOP
  FETCH cur INTO loop_t_name;
  IF done THEN
    LEAVE read_loop;
  END IF;

  select loop_t_name msg;
  SET @s=concat('ALTER TABLE ',in_dbname,'.',loop_t_name, ' CONVERT TO CHARACTER SET latin1 COLLATE latin1_swedish_ci ');
  select @s msg;
  PREPARE stmt1 FROM @s;
  execute stmt1;
  DEALLOCATE PREPARE stmt1;

END LOOP;
CLOSE cur;

SET foreign_key_checks = 1;

END //