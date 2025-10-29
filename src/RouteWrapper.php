<?php

namespace Tualo\Office\Basic;

class RouteWrapper implements IRoute
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
