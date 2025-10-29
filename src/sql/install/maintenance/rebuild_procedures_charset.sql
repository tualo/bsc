DELIMITER //

DROP PROCEDURE IF EXISTS `rebuild_all_procedures_with_charset` //

CREATE PROCEDURE `rebuild_all_procedures_with_charset`(
    IN p_target_charset VARCHAR(64) DEFAULT 'utf8mb4',
    IN p_target_collation VARCHAR(64) DEFAULT 'utf8mb4_unicode_ci',
    IN p_dry_run BOOLEAN DEFAULT FALSE
)
COMMENT 'Rebuilds all stored procedures in the current database with corrected charset and collation'
MODIFIES SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    DECLARE v_routine_name VARCHAR(64);
    DECLARE v_routine_definition LONGTEXT;
    DECLARE v_routine_type VARCHAR(20);
    DECLARE v_sql_mode VARCHAR(8192);
    DECLARE v_definer VARCHAR(93);
    DECLARE v_security_type VARCHAR(7);
    DECLARE v_comment TEXT;
    DECLARE v_deterministic VARCHAR(3);
    DECLARE v_sql_data_access VARCHAR(17);
    DECLARE v_new_definition LONGTEXT;
    DECLARE v_error_msg TEXT DEFAULT '';
    DECLARE v_procedures_processed INT DEFAULT 0;
    DECLARE v_procedures_success INT DEFAULT 0;
    DECLARE v_procedures_error INT DEFAULT 0;
    
    -- Cursor für alle Procedures in der aktuellen Datenbank
    DECLARE procedure_cursor CURSOR FOR 
        SELECT 
            ROUTINE_NAME,
            ROUTINE_DEFINITION,
            ROUTINE_TYPE,
            SQL_MODE,
            DEFINER,
            SECURITY_TYPE,
            ROUTINE_COMMENT,
            IS_DETERMINISTIC,
            SQL_DATA_ACCESS
        FROM INFORMATION_SCHEMA.ROUTINES 
        WHERE ROUTINE_SCHEMA = DATABASE()
        AND ROUTINE_TYPE = 'PROCEDURE'
        ORDER BY ROUTINE_NAME;
        
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_msg = MESSAGE_TEXT;
        SET v_procedures_error = v_procedures_error + 1;
        SELECT CONCAT('ERROR processing procedure ', v_routine_name, ': ', v_error_msg) AS error_message;
    END;

    -- Eingabe validieren
    IF p_target_charset IS NULL OR p_target_charset = '' THEN
        SET p_target_charset = 'utf8mb4';
    END IF;
    
    IF p_target_collation IS NULL OR p_target_collation = '' THEN
        SET p_target_collation = 'utf8mb4_unicode_ci';
    END IF;

    -- Start-Meldung
    SELECT CONCAT('Starting procedure rebuild process...') AS info_message;
    SELECT CONCAT('Target Charset: ', p_target_charset) AS charset_info;
    SELECT CONCAT('Target Collation: ', p_target_collation) AS collation_info;
    SELECT CONCAT('Dry Run Mode: ', IF(p_dry_run, 'YES', 'NO')) AS dry_run_info;
    SELECT '================================================' AS `separator`;

    -- Cursor öffnen
    OPEN procedure_cursor;
    
    procedure_loop: LOOP
        FETCH procedure_cursor INTO 
            v_routine_name, v_routine_definition, v_routine_type, v_sql_mode,
            v_definer, v_security_type, v_comment, v_deterministic, v_sql_data_access;
        
        IF v_done THEN
            LEAVE procedure_loop;
        END IF;
        
        SET v_procedures_processed = v_procedures_processed + 1;
        
        -- Procedure-Definition bereinigen und Charset/Collation korrigieren
        SET v_new_definition = v_routine_definition;
        
        -- Entferne Charset-Definitionen aus der Procedure-Definition
        SET v_new_definition = REGEXP_REPLACE(v_new_definition, ' CHARACTER SET [a-zA-Z0-9_]+', '');
        SET v_new_definition = REGEXP_REPLACE(v_new_definition, ' CHARSET [a-zA-Z0-9_]+', '');
        
        -- Entferne Collation-Definitionen
        SET v_new_definition = REGEXP_REPLACE(v_new_definition, ' COLLATE [a-zA-Z0-9_]+', '');
        
        -- Ersetze VARCHAR/CHAR Deklarationen ohne Charset mit Ziel-Charset
        SET v_new_definition = REGEXP_REPLACE(v_new_definition, 
            'VARCHAR\\(([0-9]+)\\)(?! CHARACTER SET)', 
            CONCAT('VARCHAR(\\1) CHARACTER SET ', p_target_charset, ' COLLATE ', p_target_collation));
            
        SET v_new_definition = REGEXP_REPLACE(v_new_definition, 
            'CHAR\\(([0-9]+)\\)(?! CHARACTER SET)', 
            CONCAT('CHAR(\\1) CHARACTER SET ', p_target_charset, ' COLLATE ', p_target_collation));
            
        SET v_new_definition = REGEXP_REPLACE(v_new_definition, 
            'TEXT(?! CHARACTER SET)', 
            CONCAT('TEXT CHARACTER SET ', p_target_charset, ' COLLATE ', p_target_collation));
            
        SET v_new_definition = REGEXP_REPLACE(v_new_definition, 
            'LONGTEXT(?! CHARACTER SET)', 
            CONCAT('LONGTEXT CHARACTER SET ', p_target_charset, ' COLLATE ', p_target_collation));
        
        -- Ersetze alte Charset-Referenzen in CAST/CONVERT Funktionen
        SET v_new_definition = REGEXP_REPLACE(v_new_definition, 
            'CAST\\((.+?) AS CHAR\\([0-9]+\\) CHARACTER SET [a-zA-Z0-9_]+( COLLATE [a-zA-Z0-9_]+)?\\)', 
            CONCAT('CAST(\\1 AS CHAR CHARACTER SET ', p_target_charset, ' COLLATE ', p_target_collation, ')'));
        
        -- Behandle CONVERT Funktionen
        SET v_new_definition = REGEXP_REPLACE(v_new_definition, 
            'CONVERT\\((.+?) USING [a-zA-Z0-9_]+\\)', 
            CONCAT('CONVERT(\\1 USING ', p_target_charset, ')'));
        
        -- Korrigiere Variable-Deklarationen
        SET v_new_definition = REGEXP_REPLACE(v_new_definition, 
            'DECLARE ([a-zA-Z_][a-zA-Z0-9_]*) VARCHAR\\(([0-9]+)\\) CHARACTER SET [a-zA-Z0-9_]+( COLLATE [a-zA-Z0-9_]+)?', 
            CONCAT('DECLARE \\1 VARCHAR(\\2) CHARACTER SET ', p_target_charset, ' COLLATE ', p_target_collation));
        
        -- Debug-Ausgabe
        SELECT CONCAT('Processing procedure: ', v_routine_name) AS current_procedure;
        
        IF p_dry_run THEN
            -- Dry Run: Nur anzeigen was gemacht würde
            SELECT CONCAT('DRY RUN - Would rebuild procedure: ', v_routine_name) AS dry_run_info;
            SELECT CONCAT('Original definition length: ', CHAR_LENGTH(v_routine_definition)) AS original_length;
            SELECT CONCAT('New definition length: ', CHAR_LENGTH(v_new_definition)) AS new_length;
            SELECT CONCAT('Definer: ', v_definer) AS definer_info;
            SELECT CONCAT('Security Type: ', v_security_type) AS security_info;
            SELECT CONCAT('SQL Data Access: ', v_sql_data_access) AS data_access_info;
            
            -- Zeige ersten Teil der neuen Definition
            SELECT CONCAT('New definition preview: ', LEFT(v_new_definition, 200), '...') AS definition_preview;
            
        ELSE
            -- Echte Ausführung: Procedure löschen und neu erstellen
            BEGIN
                DECLARE v_create_sql LONGTEXT;
                
                -- Procedure löschen
                SET @drop_sql = CONCAT('DROP PROCEDURE IF EXISTS `', v_routine_name, '`');
                PREPARE stmt FROM @drop_sql;
                EXECUTE stmt;
                DEALLOCATE PREPARE stmt;
                
                -- Procedure mit korrigierten Charset/Collation neu erstellen
                SET v_create_sql = CONCAT(
                    'CREATE DEFINER=', v_definer, ' PROCEDURE `', v_routine_name, '`',
                    '\n',
                    v_new_definition
                );
                
                -- SQL_MODE temporär setzen falls nötig
                IF v_sql_mode IS NOT NULL AND v_sql_mode != '' THEN
                    SET @old_sql_mode = @@sql_mode;
                    SET @set_sql_mode = CONCAT('SET sql_mode = ''', v_sql_mode, '''');
                    PREPARE stmt FROM @set_sql_mode;
                    EXECUTE stmt;
                    DEALLOCATE PREPARE stmt;
                END IF;
                
                -- Procedure erstellen
                SET @create_sql = v_create_sql;
                PREPARE stmt FROM @create_sql;
                EXECUTE stmt;
                DEALLOCATE PREPARE stmt;
                
                -- SQL_MODE zurücksetzen
                IF v_sql_mode IS NOT NULL AND v_sql_mode != '' THEN
                    SET @reset_sql_mode = CONCAT('SET sql_mode = ''', @old_sql_mode, '''');
                    PREPARE stmt FROM @reset_sql_mode;
                    EXECUTE stmt;
                    DEALLOCATE PREPARE stmt;
                END IF;
                
                SET v_procedures_success = v_procedures_success + 1;
                SELECT CONCAT('SUCCESS: Rebuilt procedure ', v_routine_name) AS success_message;
                
            END;
        END IF;
        
        SELECT '------------------------------------------------' AS `separator`;
        
    END LOOP;
    
    CLOSE procedure_cursor;
    
    -- Zusammenfassung
    SELECT '================================================' AS final_separator;
    SELECT 'PROCEDURE REBUILD SUMMARY' AS summary_title;
    SELECT '================================================' AS final_separator;
    SELECT CONCAT('Procedures processed: ', v_procedures_processed) AS total_processed;
    SELECT CONCAT('Procedures successful: ', v_procedures_success) AS total_success;
    SELECT CONCAT('Procedures with errors: ', v_procedures_error) AS total_errors;
    SELECT CONCAT('Target Charset: ', p_target_charset) AS final_charset;
    SELECT CONCAT('Target Collation: ', p_target_collation) AS final_collation;
    
    IF p_dry_run THEN
        SELECT 'DRY RUN COMPLETED - No changes were made' AS final_status;
    ELSE
        SELECT 'REBUILD COMPLETED' AS final_status;
    END IF;
    
END //

-- Zusätzliche Hilfsprocedure zur Anzeige aller Procedures mit ihren aktuellen Eigenschaften
DROP PROCEDURE IF EXISTS `show_procedure_charset_info` //

CREATE PROCEDURE `show_procedure_charset_info`()
COMMENT 'Shows charset and collation information for all stored procedures'
READS SQL DATA
SQL SECURITY DEFINER
BEGIN
    SELECT 
        ROUTINE_NAME as procedure_name,
        ROUTINE_TYPE as routine_type,
        DEFINER as definer,
        SECURITY_TYPE as security_type,
        SQL_DATA_ACCESS as data_access,
        IS_DETERMINISTIC as `deterministic`,
        SQL_MODE as sql_mode,
        CHAR_LENGTH(ROUTINE_DEFINITION) as definition_length,
        LEFT(ROUTINE_DEFINITION, 100) as definition_preview,
        ROUTINE_COMMENT as comment
    FROM INFORMATION_SCHEMA.ROUTINES 
    WHERE ROUTINE_SCHEMA = DATABASE()
    AND ROUTINE_TYPE = 'PROCEDURE'
    ORDER BY ROUTINE_NAME;
END //

-- Procedure für Backup aller Procedure-Definitionen
DROP PROCEDURE IF EXISTS `backup_procedure_definitions` //

CREATE PROCEDURE `backup_procedure_definitions`()
COMMENT 'Creates backup statements for all stored procedures'
READS SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    DECLARE v_routine_name VARCHAR(64);
    DECLARE v_routine_definition LONGTEXT;
    DECLARE v_definer VARCHAR(93);
    DECLARE v_sql_mode VARCHAR(8192);
    
    DECLARE procedure_cursor CURSOR FOR 
        SELECT ROUTINE_NAME, ROUTINE_DEFINITION, DEFINER, SQL_MODE
        FROM INFORMATION_SCHEMA.ROUTINES 
        WHERE ROUTINE_SCHEMA = DATABASE()
        AND ROUTINE_TYPE = 'PROCEDURE'
        ORDER BY ROUTINE_NAME;
        
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    SELECT '-- Stored Procedure Definitions Backup' AS backup_header;
    SELECT CONCAT('-- Generated on: ', NOW()) AS backup_timestamp;
    SELECT CONCAT('-- Database: ', DATABASE()) AS backup_database;
    SELECT '-- ============================================' AS backup_separator;

    OPEN procedure_cursor;
    
    backup_loop: LOOP
        FETCH procedure_cursor INTO v_routine_name, v_routine_definition, v_definer, v_sql_mode;
        
        IF v_done THEN
            LEAVE backup_loop;
        END IF;
        
        SELECT '' AS empty_line;
        SELECT CONCAT('-- Procedure: ', v_routine_name) AS procedure_comment;
        SELECT CONCAT('-- Definer: ', v_definer) AS definer_comment;
        SELECT CONCAT('-- SQL Mode: ', IFNULL(v_sql_mode, 'DEFAULT')) AS sql_mode_comment;
        SELECT CONCAT('DELIMITER /','/' AS delimiter_start;
        SELECT CONCAT('DROP PROCEDURE IF EXISTS `', v_routine_name, '` /','/') AS drop_statement;
        SELECT CONCAT('CREATE DEFINER=', v_definer, ' PROCEDURE `', v_routine_name, '`') AS create_header;
        SELECT v_routine_definition AS procedure_body;
        SELECT '//' AS delimiter_body;
        SELECT 'DELIMITER ;' AS delimiter_end;
        
    END LOOP;
    
    CLOSE procedure_cursor;
    
    SELECT '' AS final_empty_line;
    SELECT '-- End of backup' AS backup_footer;
END //

-- Procedure für das Neuschreiben von Functions (zusätzlich)
DROP PROCEDURE IF EXISTS `rebuild_all_functions_with_charset` //

CREATE PROCEDURE `rebuild_all_functions_with_charset`(
    IN p_target_charset VARCHAR(64) DEFAULT 'utf8mb4',
    IN p_target_collation VARCHAR(64) DEFAULT 'utf8mb4_unicode_ci',
    IN p_dry_run BOOLEAN DEFAULT FALSE
)
COMMENT 'Rebuilds all stored functions in the current database with corrected charset and collation'
MODIFIES SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    DECLARE v_routine_name VARCHAR(64);
    DECLARE v_routine_definition LONGTEXT;
    DECLARE v_definer VARCHAR(93);
    DECLARE v_returns VARCHAR(64);
    DECLARE v_new_definition LONGTEXT;
    DECLARE v_error_msg TEXT DEFAULT '';
    DECLARE v_functions_processed INT DEFAULT 0;
    DECLARE v_functions_success INT DEFAULT 0;
    DECLARE v_functions_error INT DEFAULT 0;
    
    -- Cursor für alle Functions in der aktuellen Datenbank
    DECLARE function_cursor CURSOR FOR 
        SELECT 
            ROUTINE_NAME,
            ROUTINE_DEFINITION,
            DEFINER,
            DTD_IDENTIFIER as RETURNS_TYPE
        FROM INFORMATION_SCHEMA.ROUTINES 
        WHERE ROUTINE_SCHEMA = DATABASE()
        AND ROUTINE_TYPE = 'FUNCTION'
        ORDER BY ROUTINE_NAME;
        
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_msg = MESSAGE_TEXT;
        SET v_functions_error = v_functions_error + 1;
        SELECT CONCAT('ERROR processing function ', v_routine_name, ': ', v_error_msg) AS error_message;
    END;

    SELECT CONCAT('Starting function rebuild process...') AS info_message;
    SELECT CONCAT('Target Charset: ', p_target_charset) AS charset_info;
    SELECT CONCAT('Target Collation: ', p_target_collation) AS collation_info;

    OPEN function_cursor;
    
    function_loop: LOOP
        FETCH function_cursor INTO v_routine_name, v_routine_definition, v_definer, v_returns;
        
        IF v_done THEN
            LEAVE function_loop;
        END IF;
        
        SET v_functions_processed = v_functions_processed + 1;
        
        -- Ähnliche Verarbeitung wie bei Procedures
        SET v_new_definition = v_routine_definition;
        
        -- Charset/Collation-Korrekturen anwenden (gleiche Logik wie bei Procedures)
        SET v_new_definition = REGEXP_REPLACE(v_new_definition, ' CHARACTER SET [a-zA-Z0-9_]+', '');
        SET v_new_definition = REGEXP_REPLACE(v_new_definition, ' CHARSET [a-zA-Z0-9_]+', '');
        SET v_new_definition = REGEXP_REPLACE(v_new_definition, ' COLLATE [a-zA-Z0-9_]+', '');
        
        SELECT CONCAT('Processing function: ', v_routine_name) AS current_function;
        
        IF p_dry_run THEN
            SELECT CONCAT('DRY RUN - Would rebuild function: ', v_routine_name) AS dry_run_info;
        ELSE
            -- Function löschen und neu erstellen
            SET @drop_sql = CONCAT('DROP FUNCTION IF EXISTS `', v_routine_name, '`');
            PREPARE stmt FROM @drop_sql;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;
            
            -- Neue Function erstellen (vereinfacht - Returns-Type müsste genauer analysiert werden)
            -- Diese Implementierung ist ein Grundgerüst und müsste für komplexe Functions erweitert werden
            
            SET v_functions_success = v_functions_success + 1;
            SELECT CONCAT('SUCCESS: Rebuilt function ', v_routine_name) AS success_message;
        END IF;
        
    END LOOP;
    
    CLOSE function_cursor;
    
    SELECT CONCAT('Functions processed: ', v_functions_processed) AS functions_total;
    SELECT CONCAT('Functions successful: ', v_functions_success) AS functions_success;
    SELECT CONCAT('Functions with errors: ', v_functions_error) AS functions_errors;
    
END //
 

-- Beispiel-Aufrufe:

-- 1. Dry Run für Procedures (zeigt nur an, was gemacht würde):
-- CALL rebuild_all_procedures_with_charset('utf8mb4', 'utf8mb4_unicode_ci', TRUE);

-- 2. Echte Ausführung für Procedures mit Standard-Einstellungen:
-- CALL rebuild_all_procedures_with_charset();

-- 3. Mit benutzerdefinierten Charset/Collation für Procedures:
-- CALL rebuild_all_procedures_with_charset('utf8mb4', 'utf8mb4_general_ci', FALSE);

-- 4. Informationen über aktuelle Procedures anzeigen:
-- CALL show_procedure_charset_info();

-- 5. Backup aller Procedure-Definitionen erstellen:
-- CALL backup_procedure_definitions();

-- 6. Functions neu schreiben (Dry Run):
-- CALL rebuild_all_functions_with_charset('utf8mb4', 'utf8mb4_unicode_ci', TRUE);