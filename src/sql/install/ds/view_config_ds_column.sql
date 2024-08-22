DELIMITER;

CREATE
OR REPLACE VIEW `view_config_ds_column` AS with icol as (
    select
        `information_schema`.`columns`.`TABLE_CATALOG` AS `TABLE_CATALOG`,
        `information_schema`.`columns`.`TABLE_SCHEMA` AS `TABLE_SCHEMA`,
        `information_schema`.`columns`.`TABLE_NAME` AS `TABLE_NAME`,
        `information_schema`.`columns`.`COLUMN_NAME` AS `COLUMN_NAME`,
        `information_schema`.`columns`.`ORDINAL_POSITION` AS `ORDINAL_POSITION`,
        `information_schema`.`columns`.`COLUMN_DEFAULT` AS `COLUMN_DEFAULT`,
        `information_schema`.`columns`.`IS_NULLABLE` AS `IS_NULLABLE`,
        `information_schema`.`columns`.`DATA_TYPE` AS `DATA_TYPE`,
        `information_schema`.`columns`.`CHARACTER_MAXIMUM_LENGTH` AS `CHARACTER_MAXIMUM_LENGTH`,
        `information_schema`.`columns`.`CHARACTER_OCTET_LENGTH` AS `CHARACTER_OCTET_LENGTH`,
        `information_schema`.`columns`.`NUMERIC_PRECISION` AS `NUMERIC_PRECISION`,
        `information_schema`.`columns`.`NUMERIC_SCALE` AS `NUMERIC_SCALE`,
        `information_schema`.`columns`.`DATETIME_PRECISION` AS `DATETIME_PRECISION`,
        `information_schema`.`columns`.`CHARACTER_SET_NAME` AS `CHARACTER_SET_NAME`,
        `information_schema`.`columns`.`COLLATION_NAME` AS `COLLATION_NAME`,
        `information_schema`.`columns`.`COLUMN_TYPE` AS `COLUMN_TYPE`,
        `information_schema`.`columns`.`COLUMN_KEY` AS `COLUMN_KEY`,
        `information_schema`.`columns`.`EXTRA` AS `EXTRA`,
        `information_schema`.`columns`.`PRIVILEGES` AS `PRIVILEGES`,
        `information_schema`.`columns`.`COLUMN_COMMENT` AS `COLUMN_COMMENT`,
        `information_schema`.`columns`.`IS_GENERATED` AS `IS_GENERATED`,
        `information_schema`.`columns`.`GENERATION_EXPRESSION` AS `GENERATION_EXPRESSION`
    from
        `information_schema`.`columns`
    where
        `information_schema`.`columns`.`TABLE_SCHEMA` = database()
)
select
    `icol`.`TABLE_NAME` AS `table_name`,
    `icol`.`COLUMN_NAME` AS `column_name`,
    `convertColumnType2DataType`(`icol`.`COLUMN_TYPE`) AS `data_type`,
    `icol`.`IS_NULLABLE` AS `is_nullable`,
    `icol`.`COLUMN_KEY` AS `column_key`,
    `icol`.`COLUMN_TYPE` AS `column_type`,
    `icol`.`CHARACTER_MAXIMUM_LENGTH` AS `character_maximum_length`,
    `icol`.`NUMERIC_PRECISION` AS `numeric_precision`,
    `icol`.`NUMERIC_SCALE` AS `numeric_scale`,
    `icol`.`IS_GENERATED` AS `is_generated`,
    1 AS `writeable`,
    1 AS `existsreal`,
    `icol`.`PRIVILEGES` AS `privileges`,
    `icol`.`CHARACTER_SET_NAME` AS `character_set_name`,
    `ds_column`.`default_value` AS `default_value`,
    `ds_column`.`default_max_value` AS `default_max_value`,
    `ds_column`.`default_min_value` AS `default_min_value`,
    `ds_column`.`update_value` AS `update_value`,
    if(
        `icol`.`COLUMN_KEY` like '%PRI%',
        1,
        `ds_column`.`is_primary`
    ) AS `is_primary`,
    `ds_column`.`syncable` AS `syncable`,
    `ds_column`.`referenced_table` AS `referenced_table`,
    `ds_column`.`referenced_column_name` AS `referenced_column_name`,
    `ds_column`.`is_referenced` AS `is_referenced`,
    `ds_column`.`note` AS `note`,
    `ds_column`.`deferedload` AS `deferedload`,
    `ds_column`.`hint` AS `hint`
from
    (
        `icol`
        left join `ds_column` on(
            `icol`.`TABLE_NAME` = `ds_column`.`table_name`
            and `icol`.`COLUMN_NAME` = `ds_column`.`column_name`
            and `icol`.`TABLE_SCHEMA` = database()
        )
    )
where
    `icol`.`TABLE_SCHEMA` = database();