DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `ADD_OR_UPDATE_CLIENTDB`(
    in in_session_db varchar(64),
    in in_client_db varchar(64)
)
    MODIFIES SQL DATA
BEGIN



    SET @s=concat( 'CREATE DATABASE IF NOT EXISTS ',in_client_db,' ');
    PREPARE stmt1 FROM @s;
    execute stmt1;
    DEALLOCATE PREPARE stmt1;


    SET @s=concat( '
        CREATE OR REPLACE VIEW ',in_client_db,'.sessionsview_macc_groups as

        select
            macc_groups.*
        from
        ',in_session_db,'.macc_groups macc_groups
        join ',in_session_db,'.macc_users_groups macc_users_groups
            on macc_users_groups.group = macc_groups.name
        join ',in_session_db,'.macc_users macc_users
            on macc_users_groups.id = macc_users.login
        join ',in_session_db,'.macc_users_clients macc_users_clients
            on 
            macc_users_clients.client = ',quote(in_client_db),' and (
                macc_users_clients.login = macc_users.login
                or macc_users.typ=\'master\'
            )
    ');
    PREPARE stmt1 FROM @s;
    execute stmt1;
    DEALLOCATE PREPARE stmt1;

    SET @s=concat( '
        CREATE OR REPLACE VIEW ',in_client_db,'.sessionsview_macc_users_clients as
        select
            macc_users_clients.*
        from
            ',in_session_db,'.macc_users_clients macc_users_clients
        where macc_users_clients.client = database()
    ');

    PREPARE stmt1 FROM @s;
    execute stmt1;
    DEALLOCATE PREPARE stmt1;


END //