DELIMITER //

CREATE TABLE IF NOT EXISTS `ds_dialog_cards` (
  `dialog_id` varchar(32) NOT NULL,
  `card_id` varchar(32) NOT NULL,
  `name` varchar(255) NOT NULL,
  `active` tinyint(4) DEFAULT 0,
  `position` int(11) DEFAULT 0,
  PRIMARY KEY (`dialog_id`,`card_id`),
  CONSTRAINT `fk_ds_dialog_cards_dialog_id` FOREIGN KEY (`dialog_id`) REFERENCES `ds_dialog` (`dialog_id`) ON DELETE CASCADE ON UPDATE CASCADE
) //


CREATE TRIGGER IF NOT EXISTS `trigger_ds_dialog_ai_addcolumns`
    AFTER INSERT
    ON `ds_dialog_cards` FOR EACH ROW
BEGIN
    insert into ds_dialog_card_fields 
        (dialog_id,card_id,table_name,column_name) 
    select 
        NEW.dialog_id,NEW.card_id,table_name,column_name
    from 
        ds_column
    where 
        existsreal=1 and table_name in (select table_name from ds_dialog where dialog_id=NEW.dialog_id)
        
    on duplicate key update dialog_id=values(dialog_id);
END  //


CREATE TRIGGER IF NOT EXISTS `trigger_ds_dialog_cards_bu_basic`
    BEFORE UPDATE
    ON `ds_dialog_cards` FOR EACH ROW
BEGIN
    IF OLD.card_id = 'basic' THEN
        IF NEW.card_id <> 'basic' THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 31999, MESSAGE_TEXT = 'basic card cannot be changed';
        END IF;
        IF NEW.active <> 0 THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 31999, MESSAGE_TEXT = 'basic card cannot be active';
        END IF;
    END IF;
END //