<?php

namespace Tualo\Office\Basic\Middleware;

use Tualo\Office\Basic\TualoApplication;
use Tualo\Office\Basic\IMiddleware;
use Tualo\Office\Basic\Route;

class Router implements IMiddleware
{

    public static function load()
    {

        $classes = get_declared_classes();
        foreach ($classes as $cls) {
            $class = new \ReflectionClass($cls);
            if ($class->implementsInterface('Tualo\Office\Basic\IRoute')) {
                $GLOBALS['current_cls'] = $cls;
                $cls::register();
            }
        }
    }

    public static function register()
    {
        self::load();

        TualoApplication::use('TualoApplicationRouter', function () {
            try {
                Route::run(TualoApplication::get('requestPath'));
            } catch (\Exception $e) {
                TualoApplication::set('maintanceMode', 'on');
                TualoApplication::addError($e->getMessage());
            }
        }, 9999999999, [], false);
    }
}
