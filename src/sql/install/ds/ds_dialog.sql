DELIMITER //
CREATE TABLE IF NOT EXISTS `ds_dialog` (
  `dialog_id` varchar(32) NOT NULL,
  `table_name` varchar(128) NOT NULL,
  PRIMARY KEY (`dialog_id`),
  KEY `fk_ds_dialog_ds` (`table_name`),
  CONSTRAINT `fk_ds_dialog_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
) //


CREATE TRIGGER IF NOT EXISTS `trigger_ds_dialog_ai_addcard`
    AFTER INSERT
    ON `ds_dialog` FOR EACH ROW
BEGIN
    insert into ds_dialog_cards (dialog_id,card_id,name) values (NEW.dialog_id,'basic','') on duplicate key update dialog_id=values(dialog_id);
END //