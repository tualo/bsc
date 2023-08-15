
--
-- Table structure for table `loginnamen`
--

DROP TABLE IF EXISTS `loginnamen`;
CREATE TABLE `loginnamen` (
  `login` varchar(255) NOT NULL DEFAULT '',
  `vorname` varchar(255) NOT NULL,
  `nachname` varchar(255) NOT NULL,
  `fax` varchar(255) DEFAULT NULL,
  `telefon` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `kundenberater` varchar(255) DEFAULT NULL,
  `mobile` varchar(30) DEFAULT NULL,
  `aktiv` varchar(4) DEFAULT NULL,
  `zeichen` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`login`)
);

--
-- Dumping data for table `loginnamen`
--

LOCK TABLES `loginnamen` WRITE;
INSERT INTO `loginnamen` VALUES ('Neuer nutzer','Ronald','Nickel',NULL,NULL,'r.nickel@ronnic-arts.de',NULL,NULL,NULL,NULL),('r.nickel@ronnic-arts.de','Ronald','Nickel',NULL,NULL,'r.nickel@ronnic-arts.de',NULL,NULL,NULL,NULL),('thomas.hoffmann@tualo.de','Thomas','Hoffmann','','','thomas.hoffmann@tualo.de','','',NULL,NULL);
UNLOCK TABLES;

--
-- Table structure for table `logins`
--

DROP TABLE IF EXISTS `logins`;
CREATE TABLE `logins` (
  `id` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `passwordType` varchar(255) NOT NULL DEFAULT 'blowfish',
  `firstName` varchar(255) DEFAULT NULL,
  `lastName` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
);


--
-- Table structure for table `macc_clients`
--

DROP TABLE IF EXISTS `macc_clients`;
CREATE TABLE `macc_clients` (
  `id` varchar(255) NOT NULL,
  `username` varchar(255) DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  `host` varchar(255) DEFAULT 'localhost',
  `port` int(11) DEFAULT 3306,
  PRIMARY KEY (`id`)
);

--
-- Table structure for table `macc_component`
--

DROP TABLE IF EXISTS `macc_component`;
CREATE TABLE `macc_component` (
  `id` varchar(50) NOT NULL,
  `des` varchar(255) DEFAULT NULL,
  `version` varchar(15) DEFAULT '',
  PRIMARY KEY (`id`)
);

--
-- Dumping data for table `macc_component`
--

LOCK TABLES `macc_component` WRITE;
UNLOCK TABLES;

--
-- Table structure for table `macc_component_access`
--

DROP TABLE IF EXISTS `macc_component_access`;
CREATE TABLE `macc_component_access` (
  `komponente` varchar(255) NOT NULL DEFAULT '',
  `rolle` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`komponente`,`rolle`)
);


--
-- Table structure for table `macc_groups`
--

DROP TABLE IF EXISTS `macc_groups`;
CREATE TABLE `macc_groups` (
  `name` varchar(255) NOT NULL,
  `aktiv` tinyint(4) DEFAULT NULL,
  `beschreibung` varchar(4000) DEFAULT NULL,
  `kategorie` varchar(255) DEFAULT 'unkategorisiert',
  PRIMARY KEY (`name`)
);

--
-- Dumping data for table `macc_groups`
--

LOCK TABLES `macc_groups` WRITE;
INSERT INTO `macc_groups` VALUES ('administration',1,'','unkategorisiert'),('_default_',1,NULL,'unkategorisiert');
UNLOCK TABLES;

--
-- Table structure for table `macc_menu`
--

DROP TABLE IF EXISTS `macc_menu`;
CREATE TABLE `macc_menu` (
  `id` varchar(50) NOT NULL,
  `title` varchar(50) NOT NULL,
  `path` varchar(255) NOT NULL,
  `param` varchar(255) DEFAULT NULL,
  `component` varchar(50) NOT NULL,
  `priority` int(11) DEFAULT NULL,
  `target` varchar(10) DEFAULT NULL,
  `path2` varchar(255) DEFAULT NULL,
  `automenu` int(11) DEFAULT 0,
  `use_iframe` int(11) DEFAULT 1,
  `iconcls` varchar(255) DEFAULT 'x-fa fa-circle',
  `route_to` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
);

--
-- Dumping data for table `macc_menu`
--

LOCK TABLES `macc_menu` WRITE;
INSERT INTO `macc_menu` VALUES ('087743ec-3217-11ee-b860-002590c4e7c6','Benutzer','',NULL,'',1,NULL,'f30bc380-3216-11ee-ae05-002590c72640',0,1,'fa fa-users','#usereditor'),('1ace16ec-3217-11ee-ae05-002590c72640','Menü','',NULL,'',2,NULL,'f30bc380-3216-11ee-ae05-002590c72640',0,1,'fa fa-list','#menueditor'),('2392d8cd-3217-11ee-ae05-002590c72640','Gruppen','',NULL,'',0,NULL,'f30bc380-3216-11ee-ae05-002590c72640',0,1,'typcn typcn-group','#groupeditor'),('f30bc380-3216-11ee-ae05-002590c72640','Setup','',NULL,'',0,NULL,'',0,1,'fa fa-cogs','');
UNLOCK TABLES;

--
-- Table structure for table `macc_session`
--

DROP TABLE IF EXISTS `macc_session`;
CREATE TABLE `macc_session` (
  `sid` varchar(40) NOT NULL DEFAULT '',
  `cnt` varchar(4000) DEFAULT NULL,
  `datum` varchar(10) DEFAULT NULL,
  `zeit` varchar(10) DEFAULT NULL,
  `ip` varchar(50) DEFAULT NULL,
  `client` varchar(255) DEFAULT NULL,
  `username` varchar(255) DEFAULT NULL
);

--
-- Dumping data for table `macc_session`
--

LOCK TABLES `macc_session` WRITE;
UNLOCK TABLES;
DELIMITER ;;
        macc_session_bi
BEFORE INSERT
ON      macc_session
FOR EACH ROW
BEGIN
        IF NEW.sid = '' THEN
                SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = 'Blank value on macc_session.sid';
        END IF;
END */;;
DELIMITER ;

--
-- Table structure for table `macc_users`
--

DROP TABLE IF EXISTS `macc_users`;
CREATE TABLE `macc_users` (
  `login` varchar(255) NOT NULL DEFAULT '',
  `passwd` varchar(255) DEFAULT NULL,
  `groupname` varchar(32) DEFAULT NULL,
  `typ` varchar(20) DEFAULT NULL,
  `initial` int(11) DEFAULT 0,
  `tpin` varchar(50) DEFAULT NULL,
  `salt` varchar(255) DEFAULT NULL,
  `pwtype` varchar(255) DEFAULT 'md5',
  PRIMARY KEY (`login`)
);


--
-- Table structure for table `macc_users_clients`
--

DROP TABLE IF EXISTS `macc_users_clients`;
CREATE TABLE `macc_users_clients` (
  `login` varchar(255) NOT NULL,
  `client` varchar(255) NOT NULL,
  PRIMARY KEY (`login`,`client`),
  KEY `fk_macc_users_clients_macc_clients` (`client`),
  CONSTRAINT `fk_macc_users_clients_macc_clients` FOREIGN KEY (`client`) REFERENCES `macc_clients` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_macc_users_clients_macc_users` FOREIGN KEY (`login`) REFERENCES `macc_users` (`login`) ON DELETE CASCADE ON UPDATE CASCADE
);



--
-- Table structure for table `macc_users_groups`
--

DROP TABLE IF EXISTS `macc_users_groups`;
CREATE TABLE `macc_users_groups` (
  `id` varchar(100) NOT NULL DEFAULT '',
  `group` varchar(255) NOT NULL,
  `idx` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`,`group`)
);


--
-- Table structure for table `oauth`
--

DROP TABLE IF EXISTS `oauth`;
CREATE TABLE `oauth` (
  `id` varchar(36) NOT NULL,
  `client` varchar(255) NOT NULL,
  `username` varchar(255) NOT NULL,
  `create_time` datetime DEFAULT NULL,
  `lastcontact` datetime DEFAULT NULL,
  `validuntil` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
);

--
-- Dumping data for table `oauth`
--

LOCK TABLES `oauth` WRITE;
UNLOCK TABLES;

--
-- Table structure for table `oauth_path`
--

DROP TABLE IF EXISTS `oauth_path`;
CREATE TABLE `oauth_path` (
  `id` varchar(36) NOT NULL,
  `path` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_oauth_path_id` FOREIGN KEY (`id`) REFERENCES `oauth` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
);



--
-- Table structure for table `oauth_resources`
--

DROP TABLE IF EXISTS `oauth_resources`;
CREATE TABLE `oauth_resources` (
  `id` varchar(36) NOT NULL,
  `param` varchar(50) NOT NULL,
  PRIMARY KEY (`id`,`param`),
  CONSTRAINT `fk_oauth_resources_id` FOREIGN KEY (`id`) REFERENCES `oauth` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
);

--
-- Dumping data for table `oauth_resources`
--

LOCK TABLES `oauth_resources` WRITE;
UNLOCK TABLES;

--
-- Table structure for table `oauth_resources_property`
--

DROP TABLE IF EXISTS `oauth_resources_property`;
CREATE TABLE `oauth_resources_property` (
  `id` varchar(36) NOT NULL,
  `param` varchar(50) NOT NULL,
  `property` varchar(50) NOT NULL,
  PRIMARY KEY (`id`,`param`,`property`),
  CONSTRAINT `fk_oauth_resources_property_id` FOREIGN KEY (`id`) REFERENCES `oauth` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
);


--
-- Table structure for table `rolle_menu`
--

DROP TABLE IF EXISTS `rolle_menu`;
CREATE TABLE `rolle_menu` (
  `id` varchar(50) NOT NULL,
  `rolle` varchar(255) NOT NULL,
  `typ` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`,`rolle`)
);

--
-- Dumping data for table `rolle_menu`
--

LOCK TABLES `rolle_menu` WRITE;
INSERT INTO `rolle_menu` VALUES ('087743ec-3217-11ee-b860-002590c4e7c6','administration',NULL),('1ace16ec-3217-11ee-ae05-002590c72640','administration',NULL),('2392d8cd-3217-11ee-ae05-002590c72640','administration',NULL),('f30bc380-3216-11ee-ae05-002590c72640','administration',NULL);
UNLOCK TABLES;

--
-- Table structure for table `sessions`
--

DROP TABLE IF EXISTS `sessions`;
CREATE TABLE `sessions` (
  `id` varchar(255) NOT NULL,
  `createdate` timestamp NOT NULL DEFAULT current_timestamp(),
  `lastdate` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `databasename` varchar(255) DEFAULT NULL,
  `databasehost` varchar(255) DEFAULT NULL,
  `login` varchar(255) DEFAULT NULL,
  `data` longtext DEFAULT NULL,
  PRIMARY KEY (`id`)
);



--
-- Table structure for table `setup`
--

DROP TABLE IF EXISTS `setup`;
CREATE TABLE `setup` (
  `id` varchar(255) NOT NULL,
  `rolle` varchar(255) NOT NULL,
  `cmp` varchar(255) NOT NULL,
  `daten` longtext DEFAULT NULL,
  `vererbbar` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`,`rolle`,`cmp`)
);

--
-- Dumping data for table `setup`
--

LOCK TABLES `setup` WRITE;
UNLOCK TABLES;

--
-- Temporary table structure for view `view_macc_clients`
--

DROP TABLE IF EXISTS `view_macc_clients`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
 1 AS `id`,
  1 AS `username`,
  1 AS `password`,
  1 AS `host`,
  1 AS `port` */;
SET character_set_client = @saved_cs_client;

--
-- Routines 
--
DELIMITER ;;
CREATE  FUNCTION `canAccessComponent`(in_component varchar(255)) RETURNS tinyint(1)
    DETERMINISTIC
BEGIN
IF in_component='cmp_template_default' THEN
        RETURN TRUE;
END IF;

IF EXISTS( SELECT login FROM macc_users WHERE login=@sessionuser and typ='master' ) THEN
    RETURN TRUE;
END IF;

IF EXISTS( select komponente from macc_component_access where rolle in (select `group` from macc_users_groups where id=@sessionuser ) and komponente = in_component ) THEN
    RETURN TRUE;
END IF;

RETURN FALSE;

END ;;
DELIMITER ;
DELIMITER ;;
CREATE  FUNCTION `set_login_salt`(length integer) RETURNS varchar(255) CHARSET utf8mb4 COLLATE utf8mb4_general_ci
    DETERMINISTIC
BEGIN
  DECLARE count INT DEFAULT 0;
  DECLARE alphanum INT;
  DECLARE randomCharacter CHAR(1);
  DECLARE password VARCHAR(255) DEFAULT "";

  WHILE count<length DO
    SET count=count+1;
    SELECT ROUND(RAND()*10) INTO alphanum;
    IF alphanum<5 THEN
      SELECT CHAR(48+MOD(ROUND(RAND()*100),10)) INTO randomCharacter;
    ELSE
      SELECT CHAR(65+MOD(ROUND(RAND()*100),26)) INTO randomCharacter;
    END IF;
    SELECT CONCAT(password,randomCharacter) INTO password;
  END WHILE;
  RETURN password;
END ;;
DELIMITER ;
DELIMITER ;;
CREATE  FUNCTION `set_login_sha2`(username varchar(255),password varchar(255)) RETURNS bit(1)
    DETERMINISTIC
BEGIN
  DECLARE salt VARCHAR(255);
  SET @u = username;
  SET @p = password;
  IF EXISTS(select * from macc_users where login = @u)=1
  THEN
    select set_login_salt(100) into salt;
    SET @s = salt;
    update macc_users set salt=@s, passwd = sha2(concat(@s,@p),512),pwtype='saltedsha2' where login=@u;
    return 1;
  ELSE
    return 0;
  END IF;
END ;;
DELIMITER ;
DELIMITER ;;
CREATE  FUNCTION `test_login`(username varchar(255),password varchar(255)) RETURNS int(4)
    READS SQL DATA
BEGIN
  SET @u = username;
  SET @p = password;

  if EXISTS(select * from macc_users where login = @u)=1
  then
    SET @pwtype = (select pwtype from macc_users where login = @u);
    IF @pwtype='md5' THEN
      IF EXISTS(select * from macc_users where login = @u and passwd=md5(@p)) = 1
      THEN
        return 1;
      ELSE
        return 0;
      END IF;
    ELSE
      IF @pwtype='saltedsha2' THEN
        SET CHARACTER SET 'latin1';
        IF EXISTS(select * from macc_users where login = @u and cast(passwd as char CHARACTER set 'utf8')=sha2(concat(salt,@p),512)) = 1
        THEN
          return 1;
        ELSE
          return 0;
        END IF;
      ELSE
        return -2;
      END IF;
    END IF;

  ELSE
    return -3;
  END IF;
END ;;
DELIMITER ;
DELIMITER ;;
CREATE  PROCEDURE `ADD_TUALO_USER`(
  IN username varchar(50),
  IN password varchar(50),
  IN client varchar(50),
  IN groupname varchar(50)
)
    MODIFIES SQL DATA
BEGIN

  insert into macc_clients (
    `id`,
    `username`,
    `password`,
    `host`,
    `port`
  ) values (
    client,
    '',
    '',
    'localhost',
    3306
  )
  on duplicate key update id=values(id);

  IF ( select count(*) c from macc_users where `login` = username) = 0 THEN
    insert into macc_users (
      `login`,
      `passwd`,
      `groupname`,
      `typ`,
      `initial`,
      `tpin`,
      `salt`,
      `pwtype`
    ) values (
      username,
      '',
      NULL,
      NULL,
      0,
      NULL,
      NULL,
      'md5'
    );
    select set_login_sha2(username,password);
  END IF;

  insert into macc_users_clients (
    `login`,
    `client`
  ) values (username,client)
  on duplicate key update `login`=values(`login`);

  insert into loginnamen
  (
    `login`,
    `vorname`,
    `nachname`,
    `fax`,
    `telefon`,
    `email`,
    `kundenberater`,
    `mobile`
  )
  values (
    username,
    '',
    '',
    '',
    '',
    '',
    '',
    ''
  )
  on duplicate key update `login`=values(`login`);


  insert into macc_groups (
    `name`,
    `aktiv`,
    `beschreibung`,
    `kategorie`
  )
  values
  (
    groupname,
    1,
    '',
    'unkategorisiert'
  )
  on duplicate key update `name`=values(`name`);

  insert into macc_users_groups (
    `id`,
    `group`
  ) values (
    username,
    groupname
  )
  on duplicate key update `id`=values(`id`);

END ;;
DELIMITER ;

--
-- Final view structure for view `view_macc_clients`
--

CREATE VIEW `view_macc_clients` AS select `macc_clients`.`id` AS `id`,`macc_clients`.`username` AS `username`,`macc_clients`.`password` AS `password`,`macc_clients`.`host` AS `host`,`macc_clients`.`port` AS `port` from `macc_clients`;