DELIMITER //
CREATE FUNCTION IF NOT EXISTS `standardize_version`(version VARCHAR(255)) RETURNS varchar(255) CHARSET latin1 COLLATE latin1_swedish_ci
    NO SQL
    DETERMINISTIC
BEGIN
  DECLARE tail VARCHAR(255);
  DECLARE head, ret VARCHAR(255) DEFAULT NULL;

  SET tail = SUBSTRING_INDEX (version,'-',1);

  WHILE tail IS NOT NULL DO 
    SET head = SUBSTRING_INDEX(tail, '.', 1);
    SET tail = NULLIF(SUBSTRING(tail, LOCATE('.', tail) + 1), tail);
    SET ret = CONCAT_WS('.', ret, CONCAT(REPEAT('0', 3 - LENGTH(CAST(head AS UNSIGNED))), head));
  END WHILE;

  RETURN ret;
END //