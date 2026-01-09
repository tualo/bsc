<?php

namespace Tualo\Office\Basic\Middleware;

use Tualo\Office\Basic\TualoApplication;
use Tualo\Office\Basic\IMiddleware;
use Tualo\Office\Basic\Route;

class ActiveSessionRouter implements IMiddleware
{

    public static function load()
    {

        $classes = get_declared_classes();
        foreach ($classes as $cls) {
            $class = new \ReflectionClass($cls);
            if ($class->implementsInterface('Tualo\Office\Basic\ISessionRoute')) {
                $GLOBALS['current_cls'] = $cls;
                $cls::register();
            }
        }
    }

    public static function register()
    {



        TualoApplication::use('TualoApplicationActiveSessionRouter', function () {
            try {
                Router::load();
            } catch (\Exception $e) {
                TualoApplication::set('maintanceMode', 'on');
                TualoApplication::addError($e->getMessage());
            }
        }, 9999999998, [
            'needActiveSession' => true
        ], false);
    }
}
