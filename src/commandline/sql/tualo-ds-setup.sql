


-- SOURCE FILE: ./src//000-FILL_DS.sql 
DELIMITER //
alter table ds modify phpexporterfilename varchar(255) //

CREATE OR REPLACE PROCEDURE `FILL_DS`( in use_table_name varchar(128) )
    MODIFIES SQL DATA
BEGIN


update ds set existsreal = 0 where (use_table_name=''  or table_name = use_table_name);

FOR record IN (select * from view_config_ds where (use_table_name=''  or table_name = use_table_name)  ) DO
    if @debug=1 then select record.table_name; end if;
    insert into ds (
        table_name,
        title,
        reorderfield,
        use_history,
        searchfield,
        displayfield,
        sortfield,
        searchany,
        hint,
        overview_tpl,
        sync_table,
        writetable,
        globalsearch,
        listselectionmodel,
        sync_view,
        syncable,
        cssstyle,
        alternativeformxtype,
        read_table,
        class_name,
        special_add_panel,
        existsreal,
        character_set_name,
        read_filter,
        listxtypeprefix,
        phpexporter,
        phpexporterfilename,
        combined,
        default_pagesize,
        allowForm,
        listviewbaseclass,
        showactionbtn
    )
    values
    (
        record.table_name,
        record.title,
        record.reorderfield,
        record.use_history,
        record.searchfield,
        record.displayfield,
        record.sortfield,
        record.searchany,
        record.hint,
        record.overview_tpl,
        record.sync_table,
        record.writetable,
        record.globalsearch,
        record.listselectionmodel,
        record.sync_view,
        record.syncable,
        record.cssstyle,
        record.alternativeformxtype,
        record.read_table,
        record.class_name,
        record.special_add_panel,
        1 ,
        record.character_set_name,
        record.read_filter,
        record.listxtypeprefix,
        record.phpexporter,
        record.phpexporterfilename,
        record.combined,
        record.default_pagesize,
        record.allowForm,
        record.listviewbaseclass,
        record.showactionbtn
    ) on duplicate key update table_name=values(table_name),existsreal=values(existsreal)
    ;

END FOR;

END //

-- SOURCE FILE: ./src//010-FILL_DS_COLUMN.sql 
DELIMITER //


CREATE OR REPLACE PROCEDURE `FILL_DS_COLUMN`( in use_table_name varchar(128) )
    MODIFIES SQL DATA
BEGIN

update ds_column set existsreal = 0 where (use_table_name=''  or table_name = use_table_name);
update ds_column set writeable = 0 where (use_table_name=''  or table_name = use_table_name);



FOR record IN ( with cte_ds (table_name,read_table,real_table_name) as (select table_name,read_table,table_name real_table_name from ds where ds.read_table<>ds.table_name and ds.read_table<>'' and ds.read_table is not null )
select 
        cte_ds.table_name,
        cte_ds.read_table,
        ds_column.column_name,
        ds_column.default_value,
        ds_column.default_max_value,
        ds_column.default_min_value,
        ds_column.update_value,
        ds_column.is_primary,
        ds_column.syncable,
        ds_column.referenced_table,
        ds_column.referenced_column_name,
        ds_column.is_nullable,
        ds_column.is_referenced,
        0 writeable,
        ds_column.note,
        ds_column.data_type,
        ds_column.column_key,
        ds_column.column_type,
        ds_column.character_maximum_length,
        ds_column.numeric_precision,
        ds_column.numeric_scale,
        ds_column.character_set_name,
        ds_column.privileges,
        1 existsreal,
        ds_column.deferedload,
        ds_column.hint
from 
cte_ds

join ds_column
        on cte_ds.read_table = ds_column.table_name 
--         and (cte_ds.table_name,ds_column.column_name) not in (select table_name,column_name from ds_column)
and (use_table_name=''  or cte_ds.table_name = use_table_name)
 ) DO

insert into ds_column (
        table_name,
        column_name,
        default_value,
        default_max_value,
        default_min_value,
        update_value,
        is_primary,
        syncable,
        referenced_table,
        referenced_column_name,
        is_nullable,
        is_referenced,
        writeable,
        note,
        data_type,
        column_key,
        column_type,
        character_maximum_length,
        numeric_precision,
        numeric_scale,
        character_set_name,
        privileges,
        existsreal,
        deferedload,
        hint
    )
    values
    (
        record.table_name,
        record.column_name,
        record.default_value,
        record.default_max_value,
        record.default_min_value,
        record.update_value,
        record.is_primary,
        record.syncable,
        record.referenced_table,
        record.referenced_column_name,
        record.is_nullable,
        record.is_referenced,
        record.writeable,
        record.note,
        record.data_type,
        record.column_key,
        record.column_type,
        record.character_maximum_length,
        record.numeric_precision,
        record.numeric_scale,
        record.character_set_name,
        record.privileges,
        record.existsreal,
        record.deferedload,
        record.hint
    )
    on duplicate key 
    update 
        `table_name`=values(`table_name`),
        `column_name`=values(`column_name`),
        `default_value`=values(`default_value`),
        `default_max_value`=values(`default_max_value`),
        `default_min_value`=values(`default_min_value`),
        `update_value`=values(`update_value`),
        `is_primary`=values(`is_primary`),
        `syncable`=values(`syncable`),
        `referenced_table`=values(`referenced_table`),
        `referenced_column_name`=values(`referenced_column_name`),
        `is_nullable`=values(`is_nullable`),
        `is_referenced`=values(`is_referenced`),
        `writeable`=values(`writeable`),
        `note`=values(`note`),
        `data_type`=values(`data_type`),
        `column_key`=values(`column_key`),
        `column_type`=values(`column_type`),
        `character_maximum_length`=values(`character_maximum_length`),
        `numeric_precision`=values(`numeric_precision`),
        `numeric_scale`=values(`numeric_scale`),
        `character_set_name`=values(`character_set_name`),
        `privileges`=values(`privileges`),
        `existsreal`=values(`existsreal`),
        `deferedload`=values(`deferedload`),
        `hint`=values(`hint`)
;


 END FOR;
 
FOR record IN (
    select * from view_config_ds_column where (use_table_name=''  or table_name = use_table_name) ) DO
    if @debug=1 then select record.table_name,record.column_name; end if;

    insert into ds_column (
        table_name,
        column_name,
        default_value,
        default_max_value,
        default_min_value,
        update_value,
        is_primary,
        syncable,
        referenced_table,
        referenced_column_name,
        is_nullable,
        is_referenced,
        writeable,
        note,
        data_type,
        column_key,
        column_type,
        character_maximum_length,
        numeric_precision,
        numeric_scale,
        character_set_name,
        privileges,
        existsreal,
        deferedload,
        hint
    )
    values
    (
        record.table_name,
        record.column_name,
        record.default_value,
        record.default_max_value,
        record.default_min_value,
        record.update_value,
        record.is_primary,
        record.syncable,
        record.referenced_table,
        record.referenced_column_name,
        record.is_nullable,
        record.is_referenced,
        record.writeable,
        record.note,
        record.data_type,
        record.column_key,
        record.column_type,
        record.character_maximum_length,
        record.numeric_precision,
        record.numeric_scale,
        record.character_set_name,
        record.privileges,
        record.existsreal,
        record.deferedload,
        record.hint
    )
    on duplicate key 
    update 
        `table_name`=values(`table_name`),
        `column_name`=values(`column_name`),
        `default_value`=values(`default_value`),
        `default_max_value`=values(`default_max_value`),
        `default_min_value`=values(`default_min_value`),
        `update_value`=values(`update_value`),
        `is_primary`=values(`is_primary`),
        `syncable`=values(`syncable`),
        `referenced_table`=values(`referenced_table`),
        `referenced_column_name`=values(`referenced_column_name`),
        `is_nullable`=values(`is_nullable`),
        `is_referenced`=values(`is_referenced`),
        `writeable`=values(`writeable`),
        `note`=values(`note`),
        `data_type`=values(`data_type`),
        `column_key`=values(`column_key`),
        `column_type`=values(`column_type`),
        `character_maximum_length`=values(`character_maximum_length`),
        `numeric_precision`=values(`numeric_precision`),
        `numeric_scale`=values(`numeric_scale`),
        `character_set_name`=values(`character_set_name`),
        `privileges`=values(`privileges`),
        `existsreal`=values(`existsreal`),
        `deferedload`=values(`deferedload`),
        `hint`=values(`hint`);

END FOR;

-- Fehler beseitigen
update ds_column_list_label set listfiltertype='' where listfiltertype="''";

END //

-- SOURCE FILE: ./src//020-FILL_DS_REFERENCE_TABLES.sql 
DELIMITER //


-- alter table ds_reference_tables add existsreal tinyint default 1 //

CREATE OR REPLACE PROCEDURE `FILL_DS_REFERENCE_TABLES`( in use_table_name varchar(128) )
    MODIFIES SQL DATA
BEGIN

-- alter table ds_reference_tables add existsreal integer default 1;

update ds_reference_tables set existsreal = 0 where (use_table_name=''  or table_name = use_table_name);

FOR record IN (select * from view_config_ds_reference_tables where (use_table_name=''  or table_name = use_table_name) ) DO
    if @debug=1 then select record.table_name,record.constraint_name; end if;

    INSERT INTO ds_reference_tables (
        table_name,
        reference_table_name,
        constraint_name,
        columnsdef,

        active,
        searchable,
        autosync,
        position,
        path,
        existsreal

    ) values (
        record.table_name,
        record.referenced_table_name,
        record.constraint_name,
        record.reference_column_names,

        0,
        0,
        0,
        999,
        '',
        1
    )
    on duplicate key 
    update 
        columnsdef=values(columnsdef),
        existsreal=values(existsreal);


END FOR;

END //



-- SOURCE FILE: ./src//040-UPDATE_DS_SETUP.sql 
DELIMITER //

CREATE OR REPLACE PROCEDURE `UPDATE_DS_SETUP`(  )
    MODIFIES SQL DATA
BEGIN
    CALL FILL_DS('');
    CALL FILL_DS_COLUMN('');
    CALL FILL_DS_REFERENCE_TABLES('');
END //

-- SOURCE FILE: ./src//090-create_or_upgrade_hstr_table.sql 
DELIMITER //
CREATE OR REPLACE PROCEDURE `create_or_upgrade_hstr_table`( IN tablename varchar(128))
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
            -- select record.column_name rec;
            set @cmd = concat('alter table `',tablename,'_hstr` add column `',record.column_name ,'` ',record.column_type,'');
            -- concat('call addFieldIfNotExists("',concat('',tablename,'_hstr'),'","', '`',record.column_name ,'` ","',record.column_type,'")');
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

call create_or_upgrade_hstr_table('cron_queries') //
-- SOURCE FILE: ./src//901-view_config_ds_column.sql 
DELIMITER //
CREATE OR REPLACE VIEW `view_config_ds_column` AS

with icol as ( select *  from information_schema.columns where table_schema=database( ) )
select
    `icol`.`table_name` AS `table_name`,
    `icol`.`column_name` AS `column_name`,
    convertColumnType2DataType(icol.column_type) AS `data_type`,
    `icol`.`is_nullable` AS `is_nullable`,
    `icol`.`column_key` AS `column_key`,
    `icol`.`column_type` AS `column_type`,
    `icol`.`character_maximum_length` AS `character_maximum_length`,
    `icol`.`numeric_precision` AS `numeric_precision`,
    `icol`.`numeric_scale` AS `numeric_scale`,
    1 AS `writeable`,
    1 AS `existsreal`,
    `icol`.`privileges` AS `privileges`,
    `icol`.`character_set_name` AS `character_set_name`, 


    `ds_column`.`default_value` AS `default_value`,
    `ds_column`.`default_max_value` AS `default_max_value`,
    `ds_column`.`default_min_value` AS `default_min_value`,
    `ds_column`.`update_value` AS `update_value`,


    if(`icol`.`column_key` like '%PRI%',1, `ds_column`.`is_primary`) AS `is_primary`,
    `ds_column`.`syncable` AS `syncable`,

    `ds_column`.`referenced_table` AS `referenced_table`,
    `ds_column`.`referenced_column_name` AS `referenced_column_name`,
    `ds_column`.`is_referenced` AS `is_referenced`,
    `ds_column`.`note` AS `note`,
    `ds_column`.`deferedload` AS `deferedload`,
    `ds_column`.`hint` AS `hint`


from
    icol
    left join `ds_column` 
        on icol.table_name = ds_column.table_name
        and icol.column_name = ds_column.column_name
        and icol.table_schema=database( )
where icol.table_schema=database( )

//
-- SOURCE FILE: ./src//902-view_config_ds_reference_tables.sql 
DELIMITER //
create or replace view view_config_ds_reference_tables as



select
    referential_constraints.table_name,
    referential_constraints.referenced_table_name,
    referential_constraints.constraint_name,
    concat(
        '{',
        group_concat(
            concat(
                '"',
                /*
                lower(key_column_usage.table_name),
                '__',
                */
                lower(key_column_usage.column_name),
                '"',
                ':',
                '"',
                /*
                lower(key_column_usage.referenced_table_name),
                '__',
                */
                lower(key_column_usage.referenced_column_name),
                '"'
            ) separator ','
        ),
        '}'
    ) reference_column_names
from
    (
        select
            *
        from
            information_schema.referential_constraints
        where
            constraint_schema = database()
    ) referential_constraints
    join (
        select
            *
        from
            information_schema.key_column_usage
        where
            information_schema.key_column_usage.constraint_schema = database()
    ) key_column_usage on key_column_usage.table_name = referential_constraints.table_name
    and key_column_usage.constraint_name = referential_constraints.constraint_name
    and key_column_usage.constraint_schema = database()
group by
    referential_constraints.constraint_name,
    referential_constraints.referenced_table_name,
    referential_constraints.table_name
union
select
    ds_referenced_manual.table_name,
    ds_referenced_manual.referenced_table_name,
    concat(
        'manual_',
        md5(
            concat(
                ds_referenced_manual.table_name,
                '_',
                ds_referenced_manual.referenced_table_name
            )
        )
    ) constraint_name,
    concat(
        '{',
        group_concat(
            concat(
                '"',
                /*
                lower(
                    ds_referenced_manual_columns.referenced_table_name
                ),
                '__',
                */
                lower(
                    ds_referenced_manual_columns.referenced_column_name
                ),
                '"',
                ':',
                '"',
                /*
                lower(ds_referenced_manual_columns.table_name),
                '__',
                */
                lower(ds_referenced_manual_columns.column_name),
                '"'
            ) separator ','
        ),
        '}'
    ) reference_column_names
from
    ds_referenced_manual
    join ds_referenced_manual_columns on (
        ds_referenced_manual.table_name,
        ds_referenced_manual.referenced_table_name
    ) = (
        ds_referenced_manual_columns.table_name,
        ds_referenced_manual_columns.referenced_table_name
    )
group by
    ds_referenced_manual.referenced_table_name,
    ds_referenced_manual.table_name 

 
 // 



-- SOURCE FILE: ./src//903-view_config_ds.sql 
DELIMITER //
CREATE OR REPLACE VIEW `view_config_ds` AS
select
    `itbl`.`TABLE_NAME` AS `table_name`,
    `itbl`.`TABLE_SCHEMA` AS `table_schema`,
    if(`ds`.`table_name` is null, 0, 1) AS `configured`,
    `ds`.`title` AS `title`,
    `ds`.`reorderfield` AS `reorderfield`,
    `ds`.`use_history` AS `use_history`,
    `ds`.`searchfield` AS `searchfield`,
    `ds`.`displayfield` AS `displayfield`,
    `ds`.`sortfield` AS `sortfield`,
    `ds`.`searchany` AS `searchany`,
    `ds`.`hint` AS `hint`,
    `ds`.`overview_tpl` AS `overview_tpl`,
    `ds`.`sync_table` AS `sync_table`,
    `ds`.`writetable` AS `writetable`,
    `ds`.`globalsearch` AS `globalsearch`,
    `ds`.`listselectionmodel` AS `listselectionmodel`,
    `ds`.`sync_view` AS `sync_view`,
    `ds`.`syncable` AS `syncable`,
    `ds`.`cssstyle` AS `cssstyle`,
    `ds`.`alternativeformxtype` AS `alternativeformxtype`,
    `ds`.`read_table` AS `read_table`,
    `ds`.`class_name` AS `class_name`,
    `ds`.`special_add_panel` AS `special_add_panel`,
    1 AS `existsreal`,
    `ds`.`character_set_name` AS `character_set_name`,
    `ds`.`read_filter` AS `read_filter`,
    `ds`.`listxtypeprefix` AS `listxtypeprefix`,
    ifnull(`ds`.`phpexporter`,'XlsxWriter') AS `phpexporter`,
    substring(ifnull(`ds`.`phpexporterfilename`,concat(`itbl`.`TABLE_NAME`,' {DATE} {TIME}')),1,50) AS `phpexporterfilename`,
    ifnull(`ds`.`combined`,0) AS `combined`,
    ifnull(`ds`.`default_pagesize`,1000) AS `default_pagesize`,
    ifnull(`ds`.`allowForm`,1) AS `allowForm`,
    ifnull(`ds`.`listviewbaseclass`,'Tualo.DataSets.ListView') AS `listviewbaseclass`,
    ifnull(`ds`.`showactionbtn`,1) AS `showactionbtn`
from
    (
        `information_schema`.`tables` `itbl`
        left join `ds` on(
            `ds`.`table_name` = `itbl`.`TABLE_NAME`
            and `itbl`.`TABLE_SCHEMA` = database()
        )
    )
where
    `itbl`.`TABLE_SCHEMA` = database()
//
