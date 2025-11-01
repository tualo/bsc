# bsc


## CSP


```

    [tualo-backend]
    csp[]="base-uri 'none' 'self'"
    csp[]="default-src 'none' 'self'"
    csp[]="script-src 'self' 'unsafe-eval'"
    csp[]="style-src 'self' 'unsafe-inline'"
    csp[]="form-action 'self'"
    csp[]="img-src 'self' data:"
    csp[]="worker-src 'self' 'unsafe-inline' * blob:"
    csp[]="frame-src 'self'

``` 


## scopes

```
insert ignore into route_scopes_permissions (scope,`group`,allowed)
select scope,'administration' `group`,1 allowed from route_scopes where scope not in (select scope from route_scopes_permissions where allowed=1)
``` 