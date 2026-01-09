<?php

namespace Tualo\Office\Basic;


class SessionRouteWrapper implements ISessionRoute
{
    public static function scope(): string
    {
        return 'basic';
    }

    public static function register()
    {
        // Register basic routes here
    }
}
