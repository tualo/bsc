DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `fixPrimaryKey`(
    IN in_table_name VARCHAR(128), 
    IN in_primary_key VARCHAR(255)
)
    MODIFIES SQL DATA
BEGIN

select group_concat(column_name order by column_id separator ',') c from 
        (
        select tco.table_schema as database_name,
            tco.constraint_name as pk_name,
            kcu.ordinal_position as column_id,
            kcu.column_name,
            tco.table_name
        from information_schema.table_constraints tco
        join information_schema.key_column_usage kcu
            on tco.constraint_schema = kcu.constraint_schema
            and tco.constraint_name = kcu.constraint_name
            and tco.table_name = kcu.table_name
        where tco.constraint_type = 'PRIMARY KEY'
            and tco.table_schema = database()
            and tco.table_name = in_table_name
        ) x;
        

    IF EXISTS(
        select group_concat(column_name order by column_id separator ',') c from 
        (
        select tco.table_schema as database_name,
            tco.constraint_name as pk_name,
            kcu.ordinal_position as column_id,
            kcu.column_name,
            tco.table_name
        from information_schema.table_constraints tco
        join information_schema.key_column_usage kcu
            on tco.constraint_schema = kcu.constraint_schema
            and tco.constraint_name = kcu.constraint_name
            and tco.table_name = kcu.table_name
        where tco.constraint_type = 'PRIMARY KEY'
            and tco.table_schema = database()
            and tco.table_name = in_table_name
        ) x
        having c<>in_primary_key
    ) THEN
    select "OK";
        SET FOREIGN_KEY_CHECKS=0;
        SET @sql = concat('alter table `',in_table_name,'` drop primary key');
        PREPARE stmt1 FROM @sql;
        execute stmt1;
        DEALLOCATE PREPARE stmt1;
            
        SET @sql = concat('alter table `',in_table_name,'` add primary key(',in_primary_key,')');
        PREPARE stmt1 FROM @sql;
        execute stmt1;
        DEALLOCATE PREPARE stmt1;

        SET FOREIGN_KEY_CHECKS=1;
    END IF;
    
END //