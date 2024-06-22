
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `isDSOperationAllowed`(
    in_table_name varchar(64),
    in_type varchar(64)
)
BEGIN
    DECLARE signal_message longtext;

    IF  (in_type='read') 
    AND (!EXISTS( SELECT max(`read`) x FROM ds_access WHERE `role` in (SELECT `group` FROM VIEW_SESSION_GROUPS) and table_name=in_table_name HAVING x=1 ) ) THEN
        select ifnull(max(msg), 'Lesen von `{table_name}` ist nicht erlaubt.') INTO signal_message from view_lang_ds_dictionary where `key`='DS_READ_NOT_ALLOWED';
        SET signal_message=replace(signal_message,'{table_name}',in_table_name);
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = signal_message;
    END IF;

    IF  (in_type='write')
        AND (!EXISTS( SELECT max(`write`) x FROM ds_access WHERE `role` in (SELECT `group` FROM VIEW_SESSION_GROUPS) and table_name=in_table_name HAVING x=1 ) )
    THEN
        select ifnull(max(msg), 'Schreiben in `{table_name}` ist nicht erlaubt.') INTO signal_message from view_lang_ds_dictionary where `key`='DS_WRITE_NOT_ALLOWED';
        SET signal_message=replace(signal_message,'{table_name}',in_table_name);
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = signal_message;
    END IF;

    IF  (in_type='append')
        AND (!EXISTS( SELECT max(`append`) x FROM ds_access WHERE `role` in (SELECT `group` FROM VIEW_SESSION_GROUPS) and table_name=in_table_name HAVING x=1 ) )
    THEN
        select ifnull(max(msg), 'Anlegen in `{table_name}` ist nicht erlaubt.') INTO signal_message from view_lang_ds_dictionary where `key`='DS_APPEND_NOT_ALLOWED';
        SET signal_message=replace(signal_message,'{table_name}',in_table_name);
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = signal_message;
    END IF;

    IF  (in_type='delete')
        AND (!EXISTS( SELECT max(`delete`) x FROM ds_access WHERE `role` in (SELECT `group` FROM VIEW_SESSION_GROUPS) and table_name=in_table_name HAVING x=1 ) )
    THEN
        select ifnull(max(msg), 'Löschen in `{table_name}` ist nicht erlaubt.') INTO signal_message from view_lang_ds_dictionary where `key`='DS_DELETE_NOT_ALLOWED';
        SET signal_message=replace(signal_message,'{table_name}',in_table_name);
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = signal_message;
    END IF;

END //