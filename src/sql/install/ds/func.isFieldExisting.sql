DELIMITER //
CREATE FUNCTION IF NOT EXISTS `isFieldExisting`(table_name_IN VARCHAR(100), field_name_IN VARCHAR(100)) RETURNS int(11)
    DETERMINISTIC
RETURN (
    SELECT COUNT(COLUMN_NAME)
    FROM INFORMATION_SCHEMA.columns
    WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = table_name_IN
    AND COLUMN_NAME = field_name_IN
) //