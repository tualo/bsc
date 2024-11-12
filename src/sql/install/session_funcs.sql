DELIMITER //

CREATE FUNCTION IF NOT EXISTS `getSessionID`() RETURNS varchar(100)
    DETERMINISTIC
RETURN (
    SELECT @sessionid
)  //
CREATE FUNCTION IF NOT EXISTS `getSessionUser`() RETURNS varchar(100)
    DETERMINISTIC
RETURN (
    SELECT @sessionuser
) //

CREATE FUNCTION IF NOT EXISTS `getSessionUserFullName`() RETURNS varchar(255)
    DETERMINISTIC
RETURN (
    SELECT @sessionuserfullname
) //



CREATE or replace FUNCTION set_login_salt(length integer)
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
END //



create or replace function set_login_sha2(username varchar(255),password varchar(255))
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
END //



create or replace function test_login(username varchar(255),password varchar(255))
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
END //




CREATE or replace PROCEDURE `ADD_TUALO_USER`(
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

CREATE TRIGGER IF NOT EXISTS
        macc_session_bi
BEFORE INSERT
ON      macc_session
FOR EACH ROW
BEGIN
        IF NEW.sid = '' THEN
                SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = 'Blank value on macc_session.sid';
        END IF;
END //


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
