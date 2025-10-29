DELIMITER //


CREATE OR REPLACE PROCEDURE `rebuild_all_views_with_charset`(
    IN p_target_charset VARCHAR(64) DEFAULT 'utf8mb4',
    IN p_target_collation VARCHAR(64) DEFAULT 'utf8mb4_unicode_ci',
    IN p_dry_run BOOLEAN DEFAULT FALSE
)
COMMENT 'Rebuilds all views in the current database with corrected charset and collation'
MODIFIES SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    DECLARE v_view_name VARCHAR(64);
    DECLARE v_view_definition LONGTEXT;
    DECLARE v_new_definition LONGTEXT;
    DECLARE v_error_msg TEXT DEFAULT '';
    DECLARE v_views_processed INT DEFAULT 0;
    DECLARE v_views_success INT DEFAULT 0;
    DECLARE v_views_error INT DEFAULT 0;
    

        
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_msg = MESSAGE_TEXT;
        SET v_views_error = v_views_error + 1;
        SELECT CONCAT('ERROR processing view ', v_view_name, ': ', v_error_msg) AS error_message;
    END;

    -- Eingabe validieren
    IF p_target_charset IS NULL OR p_target_charset = '' THEN
        SET p_target_charset = 'utf8mb4';
    END IF;
    
    IF p_target_collation IS NULL OR p_target_collation = '' THEN
        SET p_target_collation = 'utf8mb4_unicode_ci';
    END IF;

    -- Start-Meldung
    SELECT CONCAT('Starting view rebuild process...') AS info_message;
    SELECT CONCAT('Target Charset: ', p_target_charset) AS charset_info;
    SELECT CONCAT('Target Collation: ', p_target_collation) AS collation_info;
    SELECT CONCAT('Dry Run Mode: ', IF(p_dry_run, 'YES', 'NO')) AS dry_run_info;
    SELECT '================================================' AS `separator`;

    for rec in (
        SELECT TABLE_NAME, VIEW_DEFINITION
        FROM INFORMATION_SCHEMA.VIEWS 
        WHERE TABLE_SCHEMA = DATABASE()
        ORDER BY TABLE_NAME
    )
    DO
        set v_view_name = rec.TABLE_NAME;
        set v_view_definition = rec.VIEW_DEFINITION;
        SET v_views_processed = v_views_processed + 1;
        
        -- View-Definition bereinigen und Charset/Collation korrigieren
        SET v_new_definition = v_view_definition;
        
        -- Entferne Charset-Definitionen aus der View-Definition
        SET v_new_definition = REGEXP_REPLACE(v_new_definition, ' CHARACTER SET [a-zA-Z0-9_]+', '');
        SET v_new_definition = REGEXP_REPLACE(v_new_definition, ' CHARSET [a-zA-Z0-9_]+', '');
        
        -- Entferne Collation-Definitionen
        SET v_new_definition = REGEXP_REPLACE(v_new_definition, ' COLLATE [a-zA-Z0-9_]+', '');
        
        -- Ersetze alte Charset-Referenzen in CAST/CONVERT Funktionen
        SET v_new_definition = REGEXP_REPLACE(v_new_definition, 'CAST\\((.+?) AS CHAR\\([0-9]+\\) CHARACTER SET [a-zA-Z0-9_]+\\)', 
                                            CONCAT('CAST(\\1 AS CHAR CHARACTER SET ', p_target_charset, ')'));
        
        -- Behandle CONVERT Funktionen
        SET v_new_definition = REGEXP_REPLACE(v_new_definition, 'CONVERT\\((.+?) USING [a-zA-Z0-9_]+\\)', 
                                            CONCAT('CONVERT(\\1 USING ', p_target_charset, ')'));
        
        -- Debug-Ausgabe
        SELECT CONCAT('Processing view: ', v_view_name) AS current_view;
        
        IF p_dry_run THEN
            -- Dry Run: Nur anzeigen was gemacht würde
            SELECT CONCAT('DRY RUN - Would rebuild view: ', v_view_name) AS dry_run_info;
            SELECT CONCAT('Original definition length: ', CHAR_LENGTH(v_view_definition)) AS original_length;
            SELECT CONCAT('New definition length: ', CHAR_LENGTH(v_new_definition)) AS new_length;
            
            -- Zeige ersten Teil der neuen Definition
            SELECT CONCAT('New definition preview: ', LEFT(v_new_definition, 200), '...') AS definition_preview;
            
        ELSE
            -- Echte Ausführung: View löschen und neu erstellen
            BEGIN
                DECLARE v_sql TEXT;
                
                -- View löschen
                
                
                -- View mit korrigierten Charset/Collation neu erstellen
                SET @create_sql = CONCAT(
                    'CREATE OR REPLACE VIEW `', v_view_name, '` AS ', 
                    v_new_definition
                );
                
                PREPARE stmt FROM @create_sql;
                EXECUTE stmt;
                DEALLOCATE PREPARE stmt;
                
                SET v_views_success = v_views_success + 1;
                SELECT CONCAT('SUCCESS: Rebuilt view ', v_view_name) AS success_message;
                
            END;
        END IF;
        
        SELECT '------------------------------------------------' AS `separator`;
        
    end for;
    
    
    -- Zusammenfassung
    SELECT '================================================' AS final_separator;
    SELECT 'VIEW REBUILD SUMMARY' AS summary_title;
    SELECT '================================================' AS final_separator;
    SELECT CONCAT('Views processed: ', v_views_processed) AS total_processed;
    SELECT CONCAT('Views successful: ', v_views_success) AS total_success;
    SELECT CONCAT('Views with errors: ', v_views_error) AS total_errors;
    SELECT CONCAT('Target Charset: ', p_target_charset) AS final_charset;
    SELECT CONCAT('Target Collation: ', p_target_collation) AS final_collation;
    
    IF p_dry_run THEN
        SELECT 'DRY RUN COMPLETED - No changes were made' AS final_status;
    ELSE
        SELECT 'REBUILD COMPLETED' AS final_status;
    END IF;
    
END //

-- Zusätzliche Hilfsprocedure zur Anzeige aller Views mit ihren aktuellen Charset-Einstellungen

CREATE PROCEDURE `show_view_charset_info`()
COMMENT 'Shows charset and collation information for all views'
READS SQL DATA
SQL SECURITY DEFINER
BEGIN
    SELECT 
        TABLE_NAME as view_name,
        CHARACTER_SET_NAME as charset_name,
        COLLATION_NAME as collation_name,
        CHAR_LENGTH(VIEW_DEFINITION) as definition_length,
        LEFT(VIEW_DEFINITION, 100) as definition_preview
    FROM INFORMATION_SCHEMA.VIEWS v
    LEFT JOIN INFORMATION_SCHEMA.COLLATIONS c ON c.COLLATION_NAME = 'utf8mb4_unicode_ci'
    WHERE v.TABLE_SCHEMA = DATABASE()
    ORDER BY v.TABLE_NAME;
END //

-- Procedure für Backup aller View-Definitionen

CREATE OR REPLACE PROCEDURE `backup_view_definitions`()
COMMENT 'Creates backup statements for all views'
READS SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    DECLARE v_view_name VARCHAR(64);
    DECLARE v_view_definition LONGTEXT;
    
    DECLARE view_cursor CURSOR FOR 
        SELECT TABLE_NAME, VIEW_DEFINITION
        FROM INFORMATION_SCHEMA.VIEWS 
        WHERE TABLE_SCHEMA = DATABASE()
        ORDER BY TABLE_NAME;
        
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    SELECT '-- View Definitions Backup' AS backup_header;
    SELECT CONCAT('-- Generated on: ', NOW()) AS backup_timestamp;
    SELECT CONCAT('-- Database: ', DATABASE()) AS backup_database;
    SELECT '-- ============================================' AS backup_separator;

    OPEN view_cursor;
    
    backup_loop: LOOP
        FETCH view_cursor INTO v_view_name, v_view_definition;
        
        IF v_done THEN
            LEAVE backup_loop;
        END IF;
        
        SELECT '' AS empty_line;
        SELECT CONCAT('-- View: ', v_view_name) AS view_comment;
        SELECT CONCAT('CREATE OR REPLACE VIEW `', v_view_name, '` AS ', v_view_definition, ';') AS create_statement;
        
    END LOOP;
    
    CLOSE view_cursor;
    
    SELECT '' AS final_empty_line;
    SELECT '-- End of backup' AS backup_footer;
END //

DELIMITER ;

-- Beispiel-Aufrufe:

-- 1. Dry Run (zeigt nur an, was gemacht würde):
-- CALL rebuild_all_views_with_charset('utf8mb4', 'utf8mb4_unicode_ci', TRUE);

-- 2. Echte Ausführung mit Standard-Einstellungen:
-- CALL rebuild_all_views_with_charset();

-- 3. Mit benutzerdefinierten Charset/Collation:
-- CALL rebuild_all_views_with_charset('utf8mb4', 'utf8mb4_general_ci', FALSE);

-- 4. Informationen über aktuelle Views anzeigen:
-- CALL show_view_charset_info();

-- 5. Backup aller View-Definitionen erstellen:
-- CALL backup_view_definitions();