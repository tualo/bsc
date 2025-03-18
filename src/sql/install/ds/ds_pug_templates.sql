DELIMITER //

CREATE TABLE IF NOT EXISTS `ds_pug_templates` (
  `id` varchar(50) NOT NULL,
  `name` varchar(255) NOT NULL,
  `note` longtext DEFAULT NULL,
  `template` longtext NOT NULL,
  PRIMARY KEY (`id`)
)//


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
