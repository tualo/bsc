DELIMITER ;;
CREATE FUNCTION IF NOT EXISTS `FIELDQUOTE`(in_str varchar(255)) RETURNS varchar(100) CHARSET utf8mb4 COLLATE utf8mb4_general_ci
    NO SQL
    DETERMINISTIC
BEGIN
	RETURN concat('`',in_str,'`');
END ;;