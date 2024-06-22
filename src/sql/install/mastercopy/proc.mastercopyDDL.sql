DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `mastercopyDDL`(in from_db varchar(64), in to_db varchar(64) )
    MODIFIES SQL DATA
BEGIN

    DECLARE done INT DEFAULT FALSE;
    DECLARE loop_table_name VARCHAR(64);
    DECLARE loop_copy_data tinyint;
    DECLARE loop_ddl_type VARCHAR(64);
    DECLARE loop_copy_ds_config tinyint;
    DECLARE use_sql longtext;

    DECLARE cur CURSOR FOR SELECT lower(table_name) table_name,copy_data,ddl_type,copy_ds_config FROM ds_copy_master_config ORDER BY position ;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;




    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO loop_table_name,loop_copy_data,loop_ddl_type,loop_copy_ds_config;

        IF done THEN
            LEAVE read_loop;
        END IF;
        


        call debug_message(concat('tablename ',loop_table_name));

        SET @s= concat('CREATE DATABASE IF NOT EXISTS ',to_db);
        PREPARE stmt1 FROM @s;
        execute stmt1;
        DEALLOCATE PREPARE stmt1;



        SET @s= getCreateTableDDL(from_db,loop_table_name,to_db);
        
        IF @s is null THEN
            select loop_table_name, 'return null';
             SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error';
        ELSE 
            


            PREPARE stmt1 FROM @s;
            execute stmt1;
            DEALLOCATE PREPARE stmt1;

        END IF;
        


        SET done=false;

    END LOOP;
    CLOSE cur;





END //