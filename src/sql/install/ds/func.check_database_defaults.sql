DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `check_database_defaults`()
    MODIFIES SQL DATA
BEGIN



    
    IF EXISTS(
        SELECT CCSA.character_set_name,T.table_name FROM information_schema.`TABLES` T,
        information_schema.`COLLATION_CHARACTER_SET_APPLICABILITY` CCSA
        WHERE CCSA.collation_name = T.table_collation
            AND T.table_schema = database()
            AND CCSA.character_set_name<>@@character_set_database
    ) THEN 

        SELECT CCSA.character_set_name,T.table_name FROM information_schema.`TABLES` T,
        information_schema.`COLLATION_CHARACTER_SET_APPLICABILITY` CCSA
        WHERE CCSA.collation_name = T.table_collation
            AND T.table_schema = database()
            AND CCSA.character_set_name<>@@character_set_database;
        
        SET @signal_message=concat('Diese Tabellen haben das falsche Encoding, erwartet wird ',@@character_set_database);
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = @signal_message;

    END IF;

END //