DELIMITER;

CREATE TABLE IF NOT EXISTS `docsystem_ds_column` (
    `table_name` varchar(128) NOT NULL,
    `column_name` varchar(100) NOT NULL,
    `text` longtext DEFAULT NULL,
    `id` varchar(36) NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_docsystem_ds_column_docsystem_ds` (`table_name`),
    KEY `fk_docsystem_ds_column_ds` (`table_name`, `column_name`),
    CONSTRAINT `fk_docsystem_ds_column_docsystem_ds` FOREIGN KEY (`table_name`) REFERENCES `docsystem_ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_docsystem_ds_column_ds` FOREIGN KEY (`table_name`, `column_name`) REFERENCES `ds_column` (`table_name`, `column_name`) ON DELETE CASCADE ON UPDATE CASCADE
);


CREATE TABLE IF NOT EXISTS `custom_docsystem_ds_column` (
    `table_name` varchar(128) NOT NULL,
    `column_name` varchar(100) NOT NULL,
    `text` longtext DEFAULT NULL,
    `id` varchar(36) NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_custom_docsystem_ds_column_docsystem_ds` (`table_name`),
    KEY `fk_custom_docsystem_ds_column_ds` (`table_name`, `column_name`),
    CONSTRAINT `fk_custom_docsystem_ds_column_docsystem_ds` FOREIGN KEY (`table_name`) REFERENCES `docsystem_ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_custom_docsystem_ds_column_ds` FOREIGN KEY (`table_name`, `column_name`) REFERENCES `ds_column` (`table_name`, `column_name`) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE OR REPLACE VIEW `view_readtable_docsystem_ds_column` AS
select
    ifnull(`docsystem_ds_column`.`id`, uuid()) AS `id`,
    `ds_column`.`table_name` AS `table_name`,
    `ds_column`.`column_name` AS `column_name`,
    `ds_column`.`default_value` AS `default_value`,
    `ds_column`.`is_nullable` AS `is_nullable`,
    `ds_column`.`character_maximum_length` AS `character_maximum_length`,
    `ds_column`.`data_type` AS `data_type`,
    `ds_column`.`hint` AS `hint`,
    ifnull(
        ifnull(
            `ds_column_form_label`.`label`,
            `ds_column_list_label`.`label`
        ),
        `ds_column`.`column_name`
    ) AS `label`,
    `docsystem_ds_column`.`text` AS `text`,
    `ds_column_list_label`.`active` AS `list_active`,
    `ds_column_list_label`.`hidden` AS `list_hidden`,
    `ds_column_form_label`.`active` AS `form_active`,
    `ds_column_list_export`.`active` AS `export_active`,
    `ds_column_form_label`.`field_path` AS `form_path`,
    `ds_column_form_label`.`allowempty` AS `allowempty`,
    `ds_column_form_label`.`label` AS `form_label`,
    `ds_column_form_label`.`position` AS `form_position`,
    `ds_column_list_label`.`label` AS `list_label`,
    `ds_column_list_label`.`position` AS `list_position`,
    `ds_column_list_export`.`label` AS `export_label`,
    `ds_column_list_export`.`position` AS `export_position`
from
    (
        (
            (
                (
                    `ds_column`
                    left join `docsystem_ds_column` on(
                        (
                            `ds_column`.`table_name`,
                            `ds_column`.`column_name`
                        ) = (
                            `docsystem_ds_column`.`table_name`,
                            `docsystem_ds_column`.`column_name`
                        )
                    )
                )
                left join `ds_column_list_label` on(
                    (
                        `ds_column`.`table_name`,
                        `ds_column`.`column_name`
                    ) = (
                        `ds_column_list_label`.`table_name`,
                        `ds_column_list_label`.`column_name`
                    )
                )
            )
            left join `ds_column_form_label` on(
                (
                    `ds_column`.`table_name`,
                    `ds_column`.`column_name`
                ) = (
                    `ds_column_form_label`.`table_name`,
                    `ds_column_form_label`.`column_name`
                )
            )
        )
        left join `ds_column_list_export` on(
            `ds_column_list_export`.`table_name` = `ds_column`.`table_name`
            and `ds_column`.`existsreal` = 1
            and `ds_column_list_export`.`column_name` = `ds_column`.`column_name`
        )
    )
where
    `ds_column`.`table_name` in (
        select
            `docsystem_ds`.`table_name`
        from
            `docsystem_ds`
    );