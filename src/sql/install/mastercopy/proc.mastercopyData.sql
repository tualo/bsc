DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `mastercopyData`(in from_db varchar(64), in to_db varchar(64) )
    MODIFIES SQL DATA
BEGIN

    DECLARE done INT DEFAULT FALSE;
    DECLARE loop_table_name VARCHAR(64);
    DECLARE loop_copy_data tinyint;
    DECLARE loop_ddl_type VARCHAR(64);
    DECLARE loop_copy_ds_config tinyint;
    DECLARE use_sql longtext;

    DECLARE cur CURSOR FOR SELECT lower(table_name) table_name,copy_data,ddl_type,copy_ds_config FROM ds_copy_master_config where copy_data=1 ORDER BY position ;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;




    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO loop_table_name,loop_copy_data,loop_ddl_type,loop_copy_ds_config;

        IF done THEN
            LEAVE read_loop;
        END IF;


         call debug_message(concat('tablename ',loop_table_name));

        SELECT 
            group_concat(
                concat('`',col.COLUMN_NAME,'`')
                ORDER BY ORDINAL_POSITION
                separator ','
            )
        INTO 
            @f
        FROM 
            information_schema.columns col
        WHERE col.table_schema = from_db and col.table_name = loop_table_name
        ;


        SELECT 
            group_concat(
                concat('`',col.COLUMN_NAME,'`=values(`',col.COLUMN_NAME,'`)')
                ORDER BY ORDINAL_POSITION
                separator ','
            )
        INTO 
            @updates
        FROM 
            information_schema.columns col
        WHERE col.table_schema = from_db and col.table_name = loop_table_name and col.COLUMN_KEY='PRI'
        ;



        SET @s= concat( '
        INSERT INTO `',to_db,'`.`',loop_table_name,'`
        (',@f,')
        SELECT 
            ',@f,' 
        FROM `',from_db,'`.`',loop_table_name,'`
        ON DUPLICATE KEY UPDATE ', @updates ,'
        ');
        PREPARE stmt1 FROM @s;
        execute stmt1;
        DEALLOCATE PREPARE stmt1;


        SET done=false;

    END LOOP;
    CLOSE cur;





END //