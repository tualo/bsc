delimiter ;

-- insert into bsc_route_log (expression, method, ip, user_agent, username, access_result,last_access) 
create table if not exists bsc_route_log (
    expression varchar(255) not null,
    method varchar(10) not null,
    access_scope varchar(255) not null,
    ip varchar(45) not null,
    user_agent varchar(512) not null,
    username varchar(128) not null,
    access_result integer not null,
    last_access timestamp not null default current_timestamp on update current_timestamp,
    primary key (access_scope, method, username)
) ;

create table if not exists route_scopes (
    scope varchar(255) not null,
    primary key (scope)
) ;

create table if not exists route_scopes_permissions (
    scope varchar(255) not null,
    `group` varchar(255) not null,
    allowed tinyint(1) default 0,
    constraint fk_route_scopes_permissions_scope foreign key (scope) 
    references route_scopes(scope) on delete cascade on update cascade,
    primary key (scope, `group`)
) ;


create or replace view view_readtable_route_scopes_permissions as 

select  
    route_scopes.scope,
    view_session_groups.`group` ,
    ifnull( route_scopes_permissions.allowed, 0) allowed

from 
    route_scopes
    join view_session_groups
        on 1=1

    left join route_scopes_permissions
        on route_scopes_permissions.`group` = view_session_groups.`group`
        and route_scopes.scope = route_scopes_permissions.scope
;