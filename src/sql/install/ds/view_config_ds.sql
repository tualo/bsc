DELIMITER;

CREATE
OR REPLACE VIEW `view_config_ds` AS
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
    ifnull(`ds`.`phpexporter`, 'XlsxWriter') AS `phpexporter`,
    substr(
        ifnull(
            `ds`.`phpexporterfilename`,
            concat(`itbl`.`TABLE_NAME`, ' {DATE} {TIME}')
        ),
        1,
        50
    ) AS `phpexporterfilename`,
    ifnull(`ds`.`combined`, 0) AS `combined`,
    ifnull(`ds`.`default_pagesize`, 1000) AS `default_pagesize`,
    ifnull(`ds`.`allowForm`, 1) AS `allowForm`,
    ifnull(
        `ds`.`listviewbaseclass`,
        'Tualo.DataSets.ListView'
    ) AS `listviewbaseclass`,
    ifnull(`ds`.`showactionbtn`, 1) AS `showactionbtn`
from
    (
        `information_schema`.`tables` `itbl`
        left join `ds` on(
            `ds`.`table_name` = `itbl`.`TABLE_NAME`
            and `itbl`.`TABLE_SCHEMA` = database()
        )
    )
where
    `itbl`.`TABLE_SCHEMA` = database() ;