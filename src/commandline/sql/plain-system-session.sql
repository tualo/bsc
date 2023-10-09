



CREATE TABLE IF NOT EXISTS `macc_clients` (
  `id` varchar(255) NOT NULL,
  `username` varchar(255) DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  `host` varchar(255) DEFAULT 'localhost',
  `port` int(11) DEFAULT 3306,
  PRIMARY KEY (`id`)
);



--
-- Table structure for table `macc_groups`
--

CREATE TABLE IF NOT EXISTS `macc_groups` (
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
INSERT IGNORE INTO `macc_groups` VALUES ('administration',1,'','unkategorisiert'),('_default_',1,NULL,'unkategorisiert');
UNLOCK TABLES;

--
-- Table structure for table `macc_menu`
--

CREATE TABLE IF NOT EXISTS `macc_menu` (
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
INSERT IGNORE INTO `macc_menu` VALUES ('087743ec-3217-11ee-b860-002590c4e7c6','Benutzer','',NULL,'',1,NULL,'f30bc380-3216-11ee-ae05-002590c72640',0,1,'fa fa-users','#usereditor'),('1ace16ec-3217-11ee-ae05-002590c72640','Menü','',NULL,'',2,NULL,'f30bc380-3216-11ee-ae05-002590c72640',0,1,'fa fa-list','#menueditor'),('2392d8cd-3217-11ee-ae05-002590c72640','Gruppen','',NULL,'',0,NULL,'f30bc380-3216-11ee-ae05-002590c72640',0,1,'typcn typcn-group','#groupeditor'),('f30bc380-3216-11ee-ae05-002590c72640','Setup','',NULL,'',0,NULL,'',0,1,'fa fa-cogs','');
UNLOCK TABLES;



--
-- Table structure for table `macc_users`
--

CREATE TABLE IF NOT EXISTS `macc_users` (
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
-- Table structure for table `loginnamen`
--

CREATE TABLE IF NOT EXISTS `loginnamen` (
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
  PRIMARY KEY (`login`),
  constraint `fk_loginnamen_login` foreign key (`login`) references `macc_users` (`login`) on delete cascade on update cascade
);

DELIMITER ;;

CREATE OR REPLACE TRIGGER `macc_users_ai` AFTER INSERT ON `macc_users` FOR EACH ROW
BEGIN
  insert ignore into loginnamen (login,vorname,nachname,fax,telefon,email,kundenberater,mobile) values (new.login,'','','','','','','');
END ;;


DELIMITER ;

--
-- Table structure for table `macc_users_clients`
--

CREATE TABLE IF NOT EXISTS `macc_users_clients` (
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

CREATE TABLE IF NOT EXISTS `macc_users_groups` (
  `id` varchar(255) NOT NULL DEFAULT '',
  `group` varchar(255) NOT NULL,
  `idx` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`,`group`),
  CONSTRAINT `fk_macc_users_groups_macc_users` FOREIGN KEY (`id`) REFERENCES `macc_users` (`login`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_macc_users_groups_macc_groups` FOREIGN KEY (`group`) REFERENCES `macc_groups` (`name`) ON DELETE CASCADE ON UPDATE CASCADE
);



--
-- Table structure for table `oauth`
--

CREATE TABLE IF NOT EXISTS `oauth` (
  `id` varchar(36) NOT NULL,
  `client` varchar(255) NOT NULL,
  `username` varchar(255) NOT NULL,
  `create_time` datetime DEFAULT NULL,
  `lastcontact` datetime DEFAULT NULL,
  `validuntil` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_oauth_username` FOREIGN KEY (`username`) REFERENCES `macc_users` (`login`) ON DELETE CASCADE ON UPDATE CASCADE
);



--
-- Table structure for table `oauth_path`
--

CREATE TABLE IF NOT EXISTS `oauth_path` (
  `id` varchar(36) NOT NULL,
  `path` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_oauth_path_id` FOREIGN KEY (`id`) REFERENCES `oauth` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
);



--
-- Table structure for table `oauth_resources`
--

CREATE TABLE IF NOT EXISTS `oauth_resources` (
  `id` varchar(36) NOT NULL,
  `param` varchar(50) NOT NULL,
  PRIMARY KEY (`id`,`param`),
  CONSTRAINT `fk_oauth_resources_id` FOREIGN KEY (`id`) REFERENCES `oauth` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
);



--
-- Table structure for table `oauth_resources_property`
--

CREATE TABLE IF NOT EXISTS `oauth_resources_property` (
  `id` varchar(36) NOT NULL,
  `param` varchar(50) NOT NULL,
  `property` varchar(50) NOT NULL,
  PRIMARY KEY (`id`,`param`,`property`),
  CONSTRAINT `fk_oauth_resources_property_id` FOREIGN KEY (`id`) REFERENCES `oauth` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
);



--
-- Table structure for table `rolle_menu`
--

CREATE TABLE IF NOT EXISTS `rolle_menu` (
  `id` varchar(50) NOT NULL,
  `rolle` varchar(255) NOT NULL,
  `typ` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`,`rolle`),
  constraint `fk_rolle_menu_id` foreign key (`id`) references `macc_menu` (`id`) on delete cascade on update cascade,
  constraint `fk_rolle_menu_rolle` foreign key (`rolle`) references `macc_groups` (`name`) on delete cascade on update cascade
);



--

-- Dumping data for table `rolle_menu`
--

LOCK TABLES `rolle_menu` WRITE;
INSERT IGNORE INTO `rolle_menu` VALUES ('087743ec-3217-11ee-b860-002590c4e7c6','administration',NULL),('1ace16ec-3217-11ee-ae05-002590c72640','administration',NULL),('2392d8cd-3217-11ee-ae05-002590c72640','administration',NULL),('f30bc380-3216-11ee-ae05-002590c72640','administration',NULL);
UNLOCK TABLES;





--
-- Routines 
--
DELIMITER ;;
CREATE OR REPLACE FUNCTION `canAccessComponent`(in_component varchar(255)) RETURNS tinyint(1)
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
CREATE OR REPLACE FUNCTION `set_login_salt`(length integer) RETURNS varchar(255) CHARSET utf8mb4 COLLATE utf8mb4_general_ci
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
CREATE OR REPLACE FUNCTION `set_login_sha2`(username varchar(255),password varchar(255)) RETURNS bit(1)
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
CREATE OR REPLACE FUNCTION `test_login`(username varchar(255),password varchar(255)) RETURNS int(4)
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
CREATE OR REPLACE PROCEDURE `ADD_TUALO_USER`(
  IN username varchar(50),
  IN password varchar(50),
  IN client varchar(50),
  IN groupname varchar(50)
)
    MODIFIES SQL DATA
BEGIN

  INSERT IGNORE INTO macc_clients (
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
    INSERT IGNORE INTO macc_users (
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

  INSERT IGNORE INTO macc_users_clients (
    `login`,
    `client`
  ) values (username,client)
  on duplicate key update `login`=values(`login`);

  INSERT IGNORE INTO loginnamen
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


  INSERT IGNORE INTO macc_groups (
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

  INSERT IGNORE INTO macc_users_groups (
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

CREATE VIEW IF NOT EXISTS `view_macc_clients` AS 
select 
  './' `url`,
  `macc_clients`.`id` AS `id`,`macc_clients`.`username` AS `username`,
  `macc_clients`.`password` AS `password`,`macc_clients`.`host` AS `host`,`macc_clients`.`port` AS `port` from `macc_clients`
;