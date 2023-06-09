
--
-- Table structure for table `loginnamen`
--

CREATE TABLE IF NOT EXISTS `loginnamen` (
  `login` varchar(255)  NOT NULL DEFAULT '',
  `vorname` varchar(255)  NOT NULL,
  `nachname` varchar(255)  NOT NULL,
  `fax` varchar(255)  DEFAULT NULL,
  `telefon` varchar(255)  DEFAULT NULL,
  `email` varchar(255)  DEFAULT NULL,
  `kundenberater` varchar(255)  DEFAULT NULL,
  `mobile` varchar(30)  DEFAULT NULL,
  `aktiv` varchar(4)  DEFAULT NULL,
  `zeichen` varchar(255)  DEFAULT NULL,
  PRIMARY KEY (`login`)
) ;

--
-- Table structure for table `logins`
--

CREATE TABLE IF NOT EXISTS `logins` (
  `id` varchar(255)  NOT NULL,
  `password` varchar(255)  NOT NULL,
  `passwordType` varchar(255)  NOT NULL DEFAULT 'blowfish',
  `firstName` varchar(255)  DEFAULT NULL,
  `lastName` varchar(255)  DEFAULT NULL,
  PRIMARY KEY (`id`)
) ;

--
-- Table structure for table `macc_clients`
--

CREATE TABLE IF NOT EXISTS `macc_clients` (
  `id` varchar(255)  NOT NULL,
  `username` varchar(255)  DEFAULT NULL,
  `password` varchar(255)  DEFAULT NULL,
  `host` varchar(255)  DEFAULT 'localhost',
  `port` int(11) DEFAULT '3306',
  PRIMARY KEY (`id`)
) ;

--
-- Table structure for table `macc_component`
--

CREATE TABLE IF NOT EXISTS `macc_component` (
  `id` varchar(50)  NOT NULL,
  `des` varchar(255)  DEFAULT NULL,
  `version` varchar(15)  DEFAULT '',
  PRIMARY KEY (`id`)
) ;

--
-- Table structure for table `macc_component_access`
--


CREATE TABLE IF NOT EXISTS `macc_component_access` (
  `komponente` varchar(255)  NOT NULL DEFAULT '',
  `rolle` varchar(255)  NOT NULL DEFAULT '',
  PRIMARY KEY (`komponente`,`rolle`)
) ;
 
--
-- Table structure for table `macc_groups`
--


CREATE TABLE IF NOT EXISTS `macc_groups` (
  `name` varchar(255)  NOT NULL,
  `aktiv` tinyint(4) DEFAULT NULL,
  `beschreibung` varchar(4000)  DEFAULT NULL,
  `kategorie` varchar(255)  DEFAULT 'unkategorisiert',
  PRIMARY KEY (`name`)
) ;
 
--
-- Table structure for table `macc_menu`
--

CREATE TABLE IF NOT EXISTS `macc_menu` (
  `id` varchar(50)  NOT NULL,
  `title` varchar(50)  NOT NULL,
  `path` varchar(255)  NOT NULL,
  `param` varchar(255)  DEFAULT NULL,
  `component` varchar(50)  NOT NULL,
  `priority` int(11) DEFAULT NULL,
  `target` varchar(10)  DEFAULT NULL,
  `path2` varchar(255)  DEFAULT NULL,
  `automenu` int(11) DEFAULT '0',
  `use_iframe` int(11) DEFAULT '1',
  `iconcls` varchar(255)  DEFAULT 'x-fa fa-circle',
  PRIMARY KEY (`id`)
) ;

--
-- Table structure for table `macc_session`
--


CREATE TABLE IF NOT EXISTS `macc_session` (
  `sid` varchar(40)  NOT NULL DEFAULT '',
  `cnt` varchar(4000)  DEFAULT NULL,
  `datum` varchar(10)  DEFAULT NULL,
  `zeit` varchar(10)  DEFAULT NULL,
  `ip` varchar(50)  DEFAULT NULL,
  `client` varchar(255)  DEFAULT NULL,
  `username` varchar(255)  DEFAULT NULL
) ;

--
-- Table structure for table `macc_users`
--


CREATE TABLE IF NOT EXISTS `macc_users` (
  `login` varchar(255)  NOT NULL DEFAULT '',
  `passwd` varchar(255)  DEFAULT NULL,
  `groupname` varchar(32)  DEFAULT NULL,
  `typ` varchar(20)  DEFAULT NULL,
  `initial` int(11) DEFAULT '0',
  `tpin` varchar(50)  DEFAULT NULL,
  `salt` varchar(255)  DEFAULT NULL,
  `pwtype` varchar(255)  DEFAULT 'md5',
  PRIMARY KEY (`login`)
) ;


--
-- Table structure for table `macc_users_clients`
--

CREATE TABLE IF NOT EXISTS `macc_users_clients` (
  `login` varchar(255)  NOT NULL,
  `client` varchar(255)  NOT NULL,
  PRIMARY KEY (`login`,`client`),
  KEY `fk_macc_users_clients_macc_clients` (`client`),
  CONSTRAINT `fk_macc_users_clients_macc_clients` FOREIGN KEY (`client`) REFERENCES `macc_clients` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_macc_users_clients_macc_users` FOREIGN KEY (`login`) REFERENCES `macc_users` (`login`) ON DELETE CASCADE ON UPDATE CASCADE
) ;

--
-- Table structure for table `macc_users_groups`
--
CREATE TABLE IF NOT EXISTS `macc_users_groups` (
  `id` varchar(100)  NOT NULL DEFAULT '',
  `group` varchar(255)  NOT NULL,
  `idx` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`,`group`)
) ;


--
-- Table structure for table `rolle_menu`
--

CREATE TABLE IF NOT EXISTS `rolle_menu` (
  `id` varchar(50)  NOT NULL,
  `rolle` varchar(255)  NOT NULL,
  `typ` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`,`rolle`)
) ;

--
-- Table structure for table `sessions`
--

CREATE TABLE IF NOT EXISTS `sessions` (
  `id` varchar(255)  NOT NULL,
  `createdate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `lastdate` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `databasename` varchar(255)  DEFAULT NULL,
  `databasehost` varchar(255)  DEFAULT NULL,
  `login` varchar(255)  DEFAULT NULL,
  `data` longtext ,
  PRIMARY KEY (`id`)
) ;

--
-- Table structure for table `setup`
--
CREATE TABLE IF NOT EXISTS `setup` (
  `id` varchar(255)  NOT NULL,
  `rolle` varchar(255)  NOT NULL,
  `cmp` varchar(255)  NOT NULL,
  `daten` longtext ,
  `vererbbar` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`,`rolle`,`cmp`)
) ;

-- Dump completed on 2017-03-16  8:30:18

CREATE TABLE IF NOT EXISTS `macc_users_groups` (
  `id` varchar(100) NOT NULL DEFAULT '',
  `group` varchar(255) NOT NULL,
  `idx` int(11) DEFAULT NULL,
  primary key (`id`,`group`)
);

DELIMITER $$

drop function if EXISTS set_login_salt$$
CREATE FUNCTION set_login_salt(length integer)
  RETURNS VARCHAR(255)
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
END $$
DELIMITER ;



DELIMITER $$
drop function if EXISTS set_login_sha2$$
create function set_login_sha2(username varchar(255),password varchar(255))
RETURNS bit
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
END $$
DELIMITER ;


DELIMITER $$
drop function if EXISTS test_login$$
create function test_login(username varchar(255),password varchar(255))
RETURNS int(4)
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
END $$
DELIMITER ;




DELIMITER //
DROP PROCEDURE IF EXISTS `ADD_TUALO_USER` //

CREATE PROCEDURE `ADD_TUALO_USER`(
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

END //
DELIMITER ;


DELIMITER $$
CREATE TRIGGER IF NOT EXISTS
        macc_session_bi
BEFORE INSERT
ON      macc_session
FOR EACH ROW
BEGIN
        IF NEW.sid = '' THEN
                SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = 'Blank value on macc_session.sid';
        END IF;
END $$

DELIMITER //


DROP FUNCTION IF EXISTS `canAccessComponent` //
CREATE FUNCTION `canAccessComponent`(in_component varchar(255))
RETURNS boolean
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

END //
DELIMITER ;


CREATE VIEW IF NOT EXISTS `view_macc_clients` as SELECT * from `macc_clients`;



create table if not exists oauth (
  id varchar(32) not null primary key,
  client varchar(255) not null,
  username varchar(255) not null,
  create_time datetime,
  lastcontact datetime default null,
  validuntil datetime default null
);


create table if not exists oauth_resources(
  id varchar(32) not null,
  param varchar(50),
  primary key (id,param),
  constraint `fk_oauth_resources_id` foreign key (id) references oauth (id) on delete cascade on update cascade
);



create table if not exists oauth_resources_property(
  id varchar(32) not null,
  param varchar(50),
  property varchar(50),
  primary key (id,param,property),
 constraint `fk_oauth_resources_property_id` foreign key (id) references oauth (id) on delete cascade on update cascade
);

CREATE TABLE if not exists `oauth_path` (
  `id` varchar(32) NOT NULL,
  `path` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_oauth_path_id` FOREIGN KEY (`id`) REFERENCES `oauth` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
);