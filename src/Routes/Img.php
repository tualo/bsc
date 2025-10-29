<?php

namespace Tualo\Office\Basic\Routes;

use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;
use RegexIterator;
use Tualo\Office\Basic\TualoApplication;
use Tualo\Office\Basic\Route;
use Tualo\Office\Basic\IRoute;
use Tualo\Office\Basic\RouteSecurityHelper;
use Tualo\Office\Basic\Version;
use Tualo\Office\PUG\PUG;


class Img extends \Tualo\Office\Basic\RouteWrapper
{


    public static function register()
    {



        Route::add('/bscimg/(?P<file>[\w.\/\-]+)', function ($matches) {
            RouteSecurityHelper::serveSecureStaticFile(
                $matches['file'] . '',
                dirname(__DIR__, 1) . '/img/',
                ['gif', 'png', 'jpg', 'jpeg'],
                [
                    'gif' => 'image/gif',
                    'png' => 'image/png',
                    'jpg' => 'image/jpeg',
                    'jpeg' => 'image/jpeg'
                ]
            );
        }, ['get'], false);
    }
}
