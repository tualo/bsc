DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `create_or_upgrade_hstr_table`( IN tablename varchar(128))
BEGIN 
    SET @cmd = concat('create table if not exists `',tablename,'_hstr`(
           hstr_sessionuser VARCHAR(150) DEFAULT "",
           hstr_action varchar(8) NOT NULL default "insert",
           hstr_revision varchar(36) NOT NULL PRIMARY KEY,
           hstr_datetime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )');
    call fill_ds(concat('',tablename,'_hstr'));
    call fill_ds_column(concat('',tablename,'_hstr'));
    PREPARE stmt FROM @cmd;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @fldColumns = (
        select group_concat( concat('`',column_name,'`') order by column_name separator ',')
        from ds_column where ds_column.table_name = tablename and existsreal=1 
        and writeable=1
    );
    
    SET @priColumns = (
        select group_concat( concat('`',column_name,'`') order by column_name separator ',')
        from ds_column where ds_column.table_name = tablename and existsreal=1 and is_primary=1
        and writeable=1
    );

    SET @where = (
        select group_concat( concat('`',column_name,'` = NEW.`',column_name,'`') order by column_name separator ' and ')
        from ds_column where ds_column.table_name = tablename and existsreal=1 and is_primary=1
        and writeable=1
    );

    for record in (select ds_column.* from ds_column where ds_column.table_name = tablename and existsreal=1 ) do
        if not exists(select column_name from ds_column where ds_column.table_name = concat('',tablename,'_hstr') and column_name=record.column_name) then

            set @cmd = concat('alter table `',tablename,'_hstr` add column `',record.column_name ,'` ',record.column_type,'');

            select @cmd;

            PREPARE stmt FROM @cmd;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;

        end if;
    end for;


    
    SET @cmd_template = concat('CREATE OR REPLACE TRIGGER `',tablename,'#KEYNAME#` #TRIGGER_ORDER# ON `',tablename,'` FOR EACH ROW
        BEGIN
        DECLARE uu_id varchar(36);
        SET uu_id = ifnull(@useuuid,uuid());

        if ( (@use_hstr_trigger=1) or (@use_hstr_trigger is null) ) THEN

          INSERT INTO `',tablename,'_hstr`
          (
            hstr_sessionuser,
            hstr_action,
            hstr_revision,
            ',@fldColumns,'
          )
           SELECT
            ifnull(@sessionuser,"not set"),
            "#KEYWORD#",
            uu_id,
            ',@fldColumns,'
          FROM
            `',tablename,'`
          WHERE
            ',@where,'
          on duplicate key update hstr_action=values(hstr_action),hstr_revision=values(hstr_revision),hstr_datetime=values(hstr_datetime)
          ;
          END IF;
          END
        ');


    SET @cmd =  replace(@cmd_template,'#KEYNAME#','__ai');
    SET @cmd =  replace(@cmd,'#TRIGGER_ORDER#','after insert');
    SET @cmd =  replace(@cmd,'#KEYWORD#','insert');
    PREPARE stmt FROM @cmd;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @cmd =  replace(@cmd_template,'#KEYNAME#','__au');
    SET @cmd =  replace(@cmd,'#TRIGGER_ORDER#','after update');
    SET @cmd =  replace(@cmd,'#KEYWORD#','update');
    select @cmd;
    PREPARE stmt FROM @cmd;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @cmd =  replace(@cmd_template,'#KEYNAME#','__bd');
    SET @cmd =  replace(@cmd,'#TRIGGER_ORDER#','before delete');
    SET @cmd =  replace(@cmd,'#KEYWORD#','delete');
    SET @cmd =  replace(@cmd,' = NEW.',' = OLD.');
    PREPARE stmt FROM @cmd;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;



    SET @cmd = concat('call create_index(database(),"',tablename,'_hstr","idx_pri_',tablename,'_hstr","',@priColumns,'")');
    PREPARE stmt FROM @cmd;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;


END //