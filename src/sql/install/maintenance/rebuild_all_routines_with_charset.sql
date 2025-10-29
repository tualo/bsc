
DELIMITER //

CREATE OR REPLACE PROCEDURE `rebuild_all_routines_with_charset`(
    IN p_target_charset VARCHAR(64) DEFAULT 'utf8mb4',
    IN p_target_collation VARCHAR(64) DEFAULT 'utf8mb4_unicode_ci',
    IN p_dry_run BOOLEAN DEFAULT FALSE
)
COMMENT 'Rebuilds all routines in the current database with corrected charset and collation'
MODIFIES SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    DECLARE v_routine_name VARCHAR(64);
    DECLARE v_new_definition LONGTEXT;
    DECLARE v_error_msg TEXT DEFAULT '';
    DECLARE v_views_processed INT DEFAULT 0;
    DECLARE v_views_success INT DEFAULT 0;
    DECLARE v_views_error INT DEFAULT 0;
    



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
        SELECT *
        FROM INFORMATION_SCHEMA.ROUTINES 
        WHERE ROUTINE_SCHEMA = DATABASE()
    )
    DO

        -- Temporäre Tabelle für SHOW CREATE Ergebnis erstellen
        DROP TEMPORARY TABLE IF EXISTS temp_show_create;
        CREATE TEMPORARY TABLE temp_show_create (
            routine_type VARCHAR(20),
            routine_name VARCHAR(64),
            sql_mode TEXT,
            create_statement LONGTEXT,
            character_set_client VARCHAR(32),
            collation_connection VARCHAR(32),
            database_collation VARCHAR(32)
        );

        -- SHOW CREATE Ergebnis in temporäre Tabelle einfügen
        SET @create_sql = CONCAT(
            'INSERT INTO temp_show_create ',
            'SELECT * FROM (SHOW CREATE ', rec.routine_type, ' `', rec.routine_name, '`) AS t'
        );
        
        PREPARE stmt FROM @create_sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        
        -- Create Statement aus temporärer Tabelle in Variable lesen
        SELECT create_statement INTO @routine_create_statement 
        FROM temp_show_create 
        LIMIT 1;
        
        -- Alternative: CREATE Statement aus INFORMATION_SCHEMA aufbauen
        SET @full_create_statement = CONCAT(
            'CREATE ',
            IF(rec.security_type = 'DEFINER', CONCAT('DEFINER=`', rec.definer, '` '), ''),
            rec.routine_type, ' `', rec.routine_name, '`',
            '(', IFNULL(rec.routine_definition, ''), ')'
        );
        
        -- Jetzt hast du das vollständige CREATE Statement in @full_create_statement
        -- und das SHOW CREATE Ergebnis in @routine_create_statement
        
        -- Du kannst beide verwenden je nach Bedarf:
        SELECT 'Using SHOW CREATE result:' AS method1;
        SELECT LEFT(@routine_create_statement, 100) AS show_create_result;
        
        SELECT 'Using INFORMATION_SCHEMA result:' AS method2; 
        SELECT LEFT(@full_create_statement, 100) AS info_schema_result;

  
        SET v_views_processed = v_views_processed + 1;
        
        -- View-Definition bereinigen und Charset/Collation korrigieren
        SET v_new_definition = rec.routine_definition;
        
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
        SELECT CONCAT('Processing routine: ', rec.routine_name) AS current_routine;
        
        IF p_dry_run THEN
            -- Dry Run: Nur anzeigen was gemacht würde
            SELECT CONCAT('DRY RUN - Would rebuild routine: ', rec.routine_name) AS dry_run_info;
            SELECT CONCAT('Original definition length: ', CHAR_LENGTH(rec.routine_definition)) AS original_length;
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
                    'CREATE OR REPLACE ', rec.routine_type, ' `', rec.routine_name, '` AS ', 
                    v_new_definition
                );
                
                PREPARE stmt FROM @create_sql;
                EXECUTE stmt;
                DEALLOCATE PREPARE stmt;
                
                SET v_views_success = v_views_success + 1;
                SELECT CONCAT('SUCCESS: Rebuilt routine: ', rec.routine_name) AS success_message;
                
            END;
        END IF;
        
        SELECT '------------------------------------------------' AS `separator`;
        
    end for;
    
    
    -- Zusammenfassung
    SELECT '================================================' AS final_separator;
    SELECT 'Routine REBUILD SUMMARY' AS summary_title;
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

-- Hilfsprocedure um SHOW CREATE Ergebnis zu extrahieren
CREATE OR REPLACE PROCEDURE `get_routine_create_statement`(
    IN p_routine_type VARCHAR(20),
    IN p_routine_name VARCHAR(64),
    OUT p_create_statement LONGTEXT
)
READS SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE v_sql TEXT;
    
    -- Temporäre Tabelle erstellen
    DROP TEMPORARY TABLE IF EXISTS temp_routine_create;
    
    IF p_routine_type = 'PROCEDURE' THEN
        CREATE TEMPORARY TABLE temp_routine_create (
            `Procedure` VARCHAR(64),
            sql_mode TEXT,
            `Create Procedure` LONGTEXT,
            character_set_client VARCHAR(32),
            collation_connection VARCHAR(32),
            `Database Collation` VARCHAR(32)
        );
    ELSE
        CREATE TEMPORARY TABLE temp_routine_create (
            `Function` VARCHAR(64),
            sql_mode TEXT,
            `Create Function` LONGTEXT,
            character_set_client VARCHAR(32),
            collation_connection VARCHAR(32),
            `Database Collation` VARCHAR(32)
        );
    END IF;
    
    -- SHOW CREATE Statement ausführen und Ergebnis einfügen
    SET v_sql = CONCAT(
        'INSERT INTO temp_routine_create SELECT * FROM (SHOW CREATE ', 
        p_routine_type, ' `', p_routine_name, '`) AS t'
    );
    
    SET @sql = v_sql;
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    
    -- CREATE Statement extrahieren
    IF p_routine_type = 'PROCEDURE' THEN
        SELECT `Create Procedure` INTO p_create_statement 
        FROM temp_routine_create LIMIT 1;
    ELSE
        SELECT `Create Function` INTO p_create_statement 
        FROM temp_routine_create LIMIT 1;
    END IF;
    
    DROP TEMPORARY TABLE temp_routine_create;
END //

-- Verwendung in der Hauptprocedure
CREATE OR REPLACE PROCEDURE `rebuild_all_routines_with_charset_v2`(
    IN p_target_charset VARCHAR(64) DEFAULT 'utf8mb4',
    IN p_target_collation VARCHAR(64) DEFAULT 'utf8mb4_unicode_ci',
    IN p_dry_run BOOLEAN DEFAULT FALSE
)
COMMENT 'Rebuilds all routines with proper CREATE statement extraction'
MODIFIES SQL DATA
SQL SECURITY DEFINER
BEGIN
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    DECLARE v_routine_name VARCHAR(64);
    DECLARE v_routine_type VARCHAR(20);
    DECLARE v_create_statement LONGTEXT;
    
    for rec in (
        SELECT routine_name, routine_type
        FROM INFORMATION_SCHEMA.ROUTINES 
        WHERE ROUTINE_SCHEMA = DATABASE()
    )
    DO
        -- Vollständige CREATE Statement abrufen
        CALL get_routine_create_statement(rec.routine_type, rec.routine_name, v_create_statement);
        
        SELECT CONCAT('Processing ', rec.routine_type, ': ', rec.routine_name) AS processing_info;
        SELECT LEFT(v_create_statement, 200) AS create_statement_preview;
        
        -- Hier kannst du jetzt mit v_create_statement arbeiten
        -- Charset/Collation Korrekturen anwenden etc.
        
    end for;
    
END //

DELIMITER ;
