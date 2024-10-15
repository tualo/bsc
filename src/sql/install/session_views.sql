DELIMITER ;

CREATE VIEW IF NOT EXISTS `view_session_groups` AS
    select '_default_' AS `group`
union
    select SESSIONDB.`macc_users_groups`.`group` AS `group`
    from SESSIONDB.`macc_users_groups`
    where SESSIONDB.`macc_users_groups`.`group` <> '_default_'
        and SESSIONDB.`macc_users_groups`.`id` = `getSessionUser`()
group by SESSIONDB.`macc_users_groups`.`group`
union  
    SELECT 
        SESSIONDB.macc_groups.name `group` 
    FROM SESSIONDB.`macc_groups` join SESSIONDB.macc_users 
    WHERE SESSIONDB.macc_users.`login`=DBNAME.getSessionUser() 
        and SESSIONDB.macc_users.typ = 'master'
    group by SESSIONDB.macc_groups.name 
;

CREATE VIEW IF NOT EXISTS `view_session_allowed_groups` AS
select '_default_' AS `group`
union
select SESSIONDB.`macc_users_groups`.`group` AS `group`
from SESSIONDB.`macc_users_groups`
where SESSIONDB.`macc_users_groups`.`group` <> '_default_'
    and SESSIONDB.`macc_users_groups`.`id` = `getSessionUser`()
group by SESSIONDB.`macc_users_groups`.`group`;


CREATE VIEW IF NOT EXISTS `view_session_loginnamen` AS
select `sln`.`login` AS `login`,
    `sln`.`vorname` AS `vorname`,
    `sln`.`nachname` AS `nachname`,
    `sln`.`telefon` AS `telefon`,
    `sln`.`fax` AS `fax`,
    `sln`.`email` AS `email`,
    `sln`.`zeichen` AS `zeichen`
from (
        SESSIONDB.`macc_users_clients`
        join SESSIONDB.`loginnamen` `sln` on(
            SESSIONDB.`macc_users_clients`.`login` = `sln`.`login`
        )
    )
where SESSIONDB.`macc_users_clients`.`client` = database();
CREATE VIEW IF NOT EXISTS `view_session_macccomponent` AS
select 1 AS `id`,
    1 AS `des`,
    1 AS `version`;
CREATE VIEW IF NOT EXISTS `view_session_role_menu` AS
select SESSIONDB.`rolle_menu`.`id` AS `id`,
    SESSIONDB.`rolle_menu`.`rolle` AS `rolle`,
    SESSIONDB.`rolle_menu`.`typ` AS `typ`
from (
        (
            SESSIONDB.`rolle_menu`
            join SESSIONDB.`macc_users_groups` on(
                SESSIONDB.`rolle_menu`.`rolle` = SESSIONDB.`macc_users_groups`.`group`
            )
        )
        join `view_session_groups` on(
            `view_session_groups`.`group` = SESSIONDB.`macc_users_groups`.`group`
        )
    );
CREATE VIEW IF NOT EXISTS `view_session_menu` AS
select SESSIONDB.`macc_menu`.`id` AS `id`,
    SESSIONDB.`macc_menu`.`title` AS `title`,
    SESSIONDB.`macc_menu`.`path` AS `path`,
    SESSIONDB.`macc_menu`.`param` AS `param`,
    SESSIONDB.`macc_menu`.`component` AS `component`,
    SESSIONDB.`macc_menu`.`priority` AS `priority`,
    SESSIONDB.`macc_menu`.`target` AS `target`,
    SESSIONDB.`macc_menu`.`path2` AS `path2`,
    SESSIONDB.`macc_menu`.`automenu` AS `automenu`,
    SESSIONDB.`macc_menu`.`use_iframe` AS `use_iframe`,
    SESSIONDB.`macc_menu`.`iconcls` AS `iconcls`
from SESSIONDB.`macc_menu`
where SESSIONDB.`macc_menu`.`id` in (
        select `view_session_role_menu`.`id`
        from `view_session_role_menu`
    );
CREATE VIEW IF NOT EXISTS `view_session_users` AS
select SESSIONDB.`macc_users_clients`.`login` AS `login`,
    concat(
        SESSIONDB.`macc_users_clients`.`login`,
        ': ',
        ifnull(SESSIONDB.`loginnamen`.`vorname`, ''),
        ' ',
        ifnull(SESSIONDB.`loginnamen`.`nachname`, '')
    ) AS `anzeigename`,
    concat(
        ifnull(SESSIONDB.`loginnamen`.`vorname`, ''),
        ' ',
        ifnull(SESSIONDB.`loginnamen`.`nachname`, '')
    ) AS `name`,
    SESSIONDB.`loginnamen`.`telefon` AS `telefon`,
    SESSIONDB.`loginnamen`.`zeichen` AS `zeichen`,
    SESSIONDB.`loginnamen`.`fax` AS `fax`
from (
        SESSIONDB.`macc_users_clients`
        left join SESSIONDB.`loginnamen` on(
            SESSIONDB.`macc_users_clients`.`login` = SESSIONDB.`loginnamen`.`login`
        )
    )
where SESSIONDB.`macc_users_clients`.`client` = database();