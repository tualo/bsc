DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `mastercopy`(in from_db varchar(64), in to_db varchar(64) )
    MODIFIES SQL DATA
BEGIN

    SET FOREIGN_KEY_CHECKS=0;

    call mastercopyDDL ( from_db, to_db);
    call mastercopyData ( from_db, to_db);
    call mastercopyDSConfig (  from_db, to_db );
    call createNewClient('sessions',to_db,'127.0.0.1',3306);

    SET FOREIGN_KEY_CHECKS=1;

END //