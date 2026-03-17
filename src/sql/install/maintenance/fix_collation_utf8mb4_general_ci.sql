DELIMITER //

CREATE OR REPLACE PROCEDURE `fix_collation_utf8mb4`(
    IN new_collation varchar(255) default 'utf8mb4_uca1400_ai_ci',
    IN p_dry_run BOOLEAN DEFAULT FALSE
)
COMMENT 'Rebuilds all tables in the current database with corrected charset and collation'
MODIFIES SQL DATA
SQL SECURITY DEFINER
BEGIN


    SET FOREIGN_KEY_CHECKS=0;

    create table if not exists `fix_collation_foreign_key` (
        `constraint_name` varchar(255) not null,
        `table_name` varchar(255) not null,
        `definition` text not null,
        `exists_real` tinyint(1) not null default 1,
        `last_updated` timestamp not null default current_timestamp on update current_timestamp,
        primary key (`constraint_name`,`table_name`)
    );


    update `fix_collation_foreign_key` set `exists_real`=0 where not exists (
        select 1 from information_schema.table_constraints fk
        where fk.constraint_type = 'FOREIGN KEY'
        and fk.constraint_name = fix_collation_foreign_key.constraint_name
        and fk.table_schema = database()
        and fk.table_name = fix_collation_foreign_key.table_name
    );

    for record in (
        with a as (
            select
            lower(fk.constraint_name) as constraint_name, 
            c.ordinal_position,
            c.table_schema,
            lower(c.table_name) as table_name,
            lower(c.column_name ) as column_name,
            c.referenced_table_schema,
            lower(c.referenced_table_name ) as referenced_table_name,
            lower(c.referenced_column_name ) as referenced_column_name,
            rk.delete_rule,
            rk.update_rule
        from information_schema.table_constraints fk
        join information_schema.key_column_usage c 
            on c.constraint_name = fk.constraint_name
            and c.table_schema = database()
        join information_schema.referential_constraints rk
            on 
                c.table_schema = rk.constraint_schema
                and fk.constraint_name = rk.constraint_name
        where fk.constraint_type = 'FOREIGN KEY'
        )
        select 
            table_name,
            constraint_name,
            concat(
                'alter table `',table_name,'` add foreign key `',constraint_name,'` ',
                '(',group_concat(concat('`',column_name,'`') order by ordinal_position separator ',' ) ,') ',
                'references `',referenced_table_name,'` (',group_concat(concat('`',referenced_column_name,'`') order by ordinal_position separator ',' ),')',
                    ' on delete ',delete_rule,
                    ' on update ',update_rule
            ) x
        from a
        group by 
            table_name,
            constraint_name
    ) do

        insert into `fix_collation_foreign_key` (`constraint_name`,`table_name`,`definition`) 
        values (record.constraint_name, record.table_name, record.x) on duplicate key update `definition`=values(`definition`);

  
    end for;




    for record in (
        select table_name, constraint_name, concat('alter table `',table_name,'` drop foreign key `',constraint_name,'`') x from fix_collation_foreign_key
        where exists_real=1
    ) do

        if p_dry_run then
            select record.x;
        else
            PREPARE stmt FROM record.x;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;
        end if;
    end for;


    for record in (
        select table_name,
        concat('ALTER TABLE ',database(),'.',table_name, ' CONVERT TO CHARACTER SET utf8mb4 COLLATE ', new_collation, ' ',char(59)) x
        from  information_schema.tables where table_schema=database()  
        and TABLE_TYPE='BASE TABLE' 
        -- and table_collation <>'utf8mb4_general_ci'
    ) do

        if p_dry_run then
            select record.x;
        else
            select  record.x;
            PREPARE stmt FROM  record.x;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;
        end if;


    end for;


    -- Foreign Keys nach den updates wieder anlegen
    for record in (
        select table_name, constraint_name, `definition` x from fix_collation_foreign_key
    ) do
        if p_dry_run then
            select record.x;
        else
            set @create_sql = record.x;
            PREPARE stmt FROM @create_sql;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;
        end if;
    end for;

SET FOREIGN_KEY_CHECKS=1;

END //