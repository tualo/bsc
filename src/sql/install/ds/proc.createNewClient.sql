DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `createNewClient`(in session_db varchar(64), in new_client varchar(64) ,in host varchar(64), in port integer)
    MODIFIES SQL DATA
BEGIN
    DECLARE RANDOMPW varchar(64);
    DECLARE USERNAME varchar(64);

    SET USERNAME = concat('U',new_client);
    SET RANDOMPW = uuid();

    SET @id = null;
    SET @s = concat("select id into @id from ",session_db,".macc_clients where id =  '",new_client,"'");

        PREPARE stmt1 FROM @s;
        execute stmt1   ; 
        DEALLOCATE PREPARE stmt1;
    IF @id is null THEN
        
        SET @s = concat("INSERT INTO ",session_db,".macc_clients 
        (`id`,`username`,`password`,`host`,`port`)
        VALUES ('",new_client,"','",USERNAME,"','",RANDOMPW,"','",host,"','",port,"')");
        PREPARE stmt1 FROM @s;
        execute stmt1 ;
        DEALLOCATE PREPARE stmt1;



        SET @s = concat("CREATE USER ",USERNAME,"@'%' IDENTIFIED BY  '",RANDOMPW,"'");
        PREPARE stmt1 FROM @s;
        execute stmt1;
        DEALLOCATE PREPARE stmt1;

        SET @s = concat("GRANT ALL ON ",new_client,".* TO ",USERNAME,"@'%'");
        PREPARE stmt1 FROM @s;
        execute stmt1;
        DEALLOCATE PREPARE stmt1;

        


    END IF;



END //