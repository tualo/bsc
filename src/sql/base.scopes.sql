delimiter ;
insert ignore into route_scopes_permissions (scope,`group`,allowed)
select scope,'administration' `group`,1 allowed from route_scopes where scope not in (select scope from route_scopes_permissions where allowed=1);

