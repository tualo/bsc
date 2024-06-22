DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `debug_message`( in msg LONGTEXT)
    MODIFIES SQL DATA
    COMMENT '\nPrint messages if the session variable @debug is set to 1.\n'
BEGIN
    IF @debug=1 THEN
        select msg debug_message;
    END IF;
END //