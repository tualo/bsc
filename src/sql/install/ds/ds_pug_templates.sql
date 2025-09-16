DELIMITER //

CREATE TABLE IF NOT EXISTS `ds_pug_templates` (
  `id` varchar(50) NOT NULL,
  `name` varchar(255) NOT NULL,
  `note` longtext DEFAULT NULL,
  `template` longtext NOT NULL,
  PRIMARY KEY (`id`)
)//



alter table ds_pug_templates add constraint `chk_ds_pug_templates_allowed_chars`  check( (id rlike '[^a-z0-9_\.\-]')=0 ) //

CREATE OR REPLACE TRIGGER `trigger_ds_pug_templates_bi_name`
    BEFORE INSERT
    ON `ds_pug_templates` FOR EACH ROW
BEGIN
    SET NEW.name = new.id;
END //  

CREATE OR REPLACE TRIGGER `trigger_ds_pug_templates_bu_name`
    BEFORE UPDATE
    ON `ds_pug_templates` FOR EACH ROW
BEGIN
    SET NEW.name = new.id;
END //  
