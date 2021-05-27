CREATE
OR REPLACE VIEW testdb.VIEW_SESSION_USERS AS
SELECT
    sessions.macc_users_clients.login,
    concat(
        sessions.macc_users_clients.login,
        ': ',
        ifnull(sessions.loginnamen.vorname, ''),
        ' ',
        ifnull(sessions.loginnamen.nachname, '')
    ) anzeigename,
    concat(
        ifnull(sessions.loginnamen.vorname, ''),
        ' ',
        ifnull(sessions.loginnamen.nachname, '')
    ) name,
    loginnamen.telefon,
    loginnamen.zeichen,
    loginnamen.fax
from
    sessions.macc_users_clients
    left join sessions.loginnamen on sessions.macc_users_clients.login = sessions.loginnamen.login
where
    sessions.macc_users_clients.client = database();

CREATE
OR REPLACE VIEW testdb.VIEW_SESSION_LOGINNAMEN AS
SELECT
    sln.login,
    sln.vorname,
    sln.nachname,
    sln.telefon,
    sln.fax,
    sln.email,
    sln.zeichen
from
    sessions.macc_users_clients
    join sessions.loginnamen sln on sessions.macc_users_clients.login = sln.login
where
    sessions.macc_users_clients.client = database();

CREATE
OR REPLACE VIEW testdb.`VIEW_SESSION_GROUPS` AS
SELECT
    '_default_' `group`
UNION
SELECT
    `group`
FROM
    sessions.`macc_users_groups`
WHERE
    `group` <> '_default_'
    AND `id` = testdb.getSessionUser()
GROUP BY
    `group`;

CREATE
OR REPLACE VIEW testdb.VIEW_SESSION_ROLE_MENU AS
SELECT
    sessions.rolle_menu.*
from
    sessions.rolle_menu
    join sessions.macc_users_groups on sessions.rolle_menu.rolle = sessions.macc_users_groups.group
    join testdb.`VIEW_SESSION_GROUPS` on testdb.`VIEW_SESSION_GROUPS`.group = sessions.macc_users_groups.group;