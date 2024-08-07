DELIMITER ;

CREATE OR REPLACE VIEW DBNAME.VIEW_SESSION_USERS AS SELECT  SESSIONDB.macc_users_clients.login,concat(SESSIONDB.macc_users_clients.login,': ',ifnull(SESSIONDB.loginnamen.vorname,''),' ',ifnull(SESSIONDB.loginnamen.nachname,'') ) anzeigename,concat( ifnull(SESSIONDB.loginnamen.vorname,''),' ',ifnull(SESSIONDB.loginnamen.nachname,'') ) name,loginnamen.telefon,loginnamen.zeichen,loginnamen.fax  from  SESSIONDB.macc_users_clients left join SESSIONDB.loginnamen on SESSIONDB.macc_users_clients.login = SESSIONDB.loginnamen.login where SESSIONDB.macc_users_clients.client=database();
CREATE OR REPLACE VIEW DBNAME.VIEW_SESSION_LOGINNAMEN AS SELECT  sln.login,sln.vorname,sln.nachname,sln.telefon,sln.fax,sln.email,sln.zeichen from  SESSIONDB.macc_users_clients join SESSIONDB.loginnamen sln on SESSIONDB.macc_users_clients.login = sln.login where SESSIONDB.macc_users_clients.client=database();
CREATE OR REPLACE VIEW DBNAME.VIEW_SESSION_CLIENTS AS SELECT SESSIONDB.macc_users_clients.client FROM SESSIONDB.macc_users_clients join SESSIONDB.view_macc_clients on SESSIONDB.macc_users_clients.client = SESSIONDB.view_macc_clients.id WHERE SESSIONDB.macc_users_clients.login = DBNAME.getSessionUser();
CREATE OR REPLACE VIEW DBNAME.`VIEW_SESSION_GROUPS` AS 
    SELECT '_default_' `group` 
    UNION  SELECT `group` FROM SESSIONDB.`macc_users_groups` WHERE  `group`<>'_default_' AND `id`=DBNAME.getSessionUser() GROUP BY `group`
    UNION  SELECT SESSIONDB.macc_groups.name `group` FROM SESSIONDB.`macc_groups` join SESSIONDB.macc_users WHERE  SESSIONDB.macc_users.`login`=DBNAME.getSessionUser() and SESSIONDB.macc_users.typ = 'master'
    GROUP BY SESSIONDB.macc_groups.name
    
;
CREATE OR REPLACE VIEW DBNAME.VIEW_SESSION_ROLE_MENU AS SELECT SESSIONDB.rolle_menu.* from  SESSIONDB.rolle_menu join SESSIONDB.macc_users_groups on SESSIONDB.rolle_menu.rolle = SESSIONDB.macc_users_groups.group join DBNAME.`VIEW_SESSION_GROUPS` on DBNAME.`VIEW_SESSION_GROUPS`.group = SESSIONDB.macc_users_groups.group;
CREATE OR REPLACE VIEW DBNAME.VIEW_SESSION_MENU AS SELECT SESSIONDB.macc_menu.* from SESSIONDB.macc_menu where id in (select id from DBNAME.VIEW_SESSION_ROLE_MENU);
