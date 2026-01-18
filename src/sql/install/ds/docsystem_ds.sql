DELIMITER;

CREATE TABLE IF NOT EXISTS `docsystem_ds` (
    `table_name` varchar(128) NOT NULL,
    `text` longtext DEFAULT NULL,
    PRIMARY KEY (`table_name`),
    CONSTRAINT `fk_docsystem_ds_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);


CREATE TABLE IF NOT EXISTS `custom_docsystem_ds` (
    `table_name` varchar(128) NOT NULL,
    `text` longtext DEFAULT NULL,
    PRIMARY KEY (`table_name`),
    CONSTRAINT `fk_custom_docsystem_ds_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);


CREATE OR REPLACE VIEW `view_readtable_docsystem_ds` AS
select
    `ds`.`table_name` AS `table_name`,
    `ds`.`title` AS `title`,
    `docsystem_ds`.`text` AS `text`,
    `ds`.`hint` AS `hint`,
    `docsystem_ds`.`text` AS `docsystem_ds_text`
from
    (
        `ds`
        left join `docsystem_ds` on(`ds`.`table_name` = `docsystem_ds`.`table_name`)
    )
where
    `ds`.`table_name` not like 'view_readtable%'
    and `ds`.`table_name` not like 'temp_pivot%'
    and `ds`.`title` <> '';