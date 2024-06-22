DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `mastercopyDSConfig`(in from_db varchar(64), in to_db varchar(64) )
    MODIFIES SQL DATA
BEGIN

    DECLARE done INT DEFAULT FALSE;
    DECLARE loop_table_name VARCHAR(64);
    DECLARE loop_copy_data tinyint;
    DECLARE loop_ddl_type VARCHAR(64);
    DECLARE loop_copy_ds_config tinyint;
    DECLARE loop_ds_config_table VARCHAR(64);
    DECLARE use_sql longtext;

    DECLARE cur CURSOR FOR SELECT ds_config_table, lower(table_name) table_name,copy_data,ddl_type,copy_ds_config FROM ds_copy_master_config join (
        select 'ds' ds_config_table UNION 
        select 'ds_access' ds_config_table UNION 
        select 'ds_addcommands' ds_config_table UNION 
        select 'ds_additional_columns' ds_config_table UNION 
        select 'ds_column' ds_config_table UNION 
        select 'ds_column_form_label' ds_config_table UNION 
        select 'ds_column_list_label' ds_config_table UNION 
        select 'ds_column_tagfields' ds_config_table UNION 
        select 'ds_contextmenu' ds_config_table UNION 
        select 'ds_contextmenu_params' ds_config_table UNION 
        select 'ds_dropdownfields' ds_config_table UNION 
        select 'ds_nm_tables' ds_config_table UNION 
        select 'ds_pdf_reports_ds' ds_config_table UNION 
        select 'ds_preview_form_label' ds_config_table UNION 
        select 'ds_reference_tables' ds_config_table UNION 
        select 'ds_searchfields' ds_config_table UNION 
        select 'ds_trigger' ds_config_table 
    ) ds_config_tables where copy_ds_config=1 ORDER BY position ;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;




    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO loop_ds_config_table, loop_table_name,loop_copy_data,loop_ddl_type,loop_copy_ds_config;

        IF done THEN
            LEAVE read_loop;
        END IF;


         call debug_message(concat('tablename ',loop_ds_config_table,loop_table_name));

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
        WHERE col.table_schema = from_db and col.table_name = loop_ds_config_table
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
        WHERE col.table_schema = from_db and col.table_name = loop_ds_config_table and col.COLUMN_KEY='PRI'
        ;



        SET @s= concat( '
        INSERT INTO `',to_db,'`.`',loop_ds_config_table,'`
        (',@f,')
        SELECT 
            ',@f,' 
        FROM `',from_db,'`.`',loop_ds_config_table,'` WHERE TABLE_NAME = "',loop_table_name, '" ON DUPLICATE KEY UPDATE ', @updates ,'');
        

        PREPARE stmt1 FROM @s;
        execute stmt1;
        DEALLOCATE PREPARE stmt1;


        SET done=false;

    END LOOP;
    CLOSE cur;





END //