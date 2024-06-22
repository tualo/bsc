DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `correctViewDefiner`( in test_only boolean)
    MODIFIES SQL DATA
    COMMENT '\nProcedure correctViewDefiner find views with none existing definer an recreate them.\nThe new definer will be the current logged in user. If the given parameter test_only \nis true no changes will be made, only all matching view will be listed.\n'
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE use_table_schema VARCHAR(64);
    DECLARE use_table_name VARCHAR(64);
    DECLARE use_view_definition longtext;

    DECLARE cur CURSOR FOR select table_schema,table_name,view_definition from information_schema.views where definer not in (select concat(user,'@',host) from mysql.user ) and table_schema= database();
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    set global table_definition_cache = 4000;

    SET @debug=1;
    IF test_only=true THEN
        call `debug_message`('Test only: No changes will be made');
    END IF;


    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO use_table_schema,use_table_name,use_view_definition;
        IF done THEN
            LEAVE read_loop;
        END IF;
        SET @d=concat('DROP VIEW `',use_table_schema,'`.`',use_table_name,'`');
        SET @s=concat('CREATE VIEW `',use_table_schema,'`.`',use_table_name,'` AS  ',use_view_definition);

        call `debug_message`(substring(@s,1,100));

        IF test_only=false THEN
        select @s;
            call `debug_message`('prepare');
            PREPARE stmt1 FROM @d;
            execute stmt1;
            DEALLOCATE PREPARE stmt1;

            PREPARE stmt1 FROM @s;
            execute stmt1;
            DEALLOCATE PREPARE stmt1;
            call `debug_message`('OK');
        END IF;

    END LOOP;
    CLOSE cur;
END //