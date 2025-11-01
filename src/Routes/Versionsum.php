<?php

namespace Tualo\Office\Basic\Routes;

use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;
use RegexIterator;
use Tualo\Office\Basic\TualoApplication;
use Tualo\Office\Basic\Route;
use Tualo\Office\Basic\IRoute;
use Tualo\Office\Basic\Version;
use Tualo\Office\PUG\PUG;


class Versionsum extends \Tualo\Office\Basic\RouteWrapper
{
    public static function scope(): string
    {
        return 'bsc.versionsum';
    }

    public static function register()
    {
        // usage: to find the test.zip file recursively
        // $result = rsearch($_SERVER['DOCUMENT_ROOT'], '/.*\/test\.zip/'));
        Route::add('/versionsum', function () {
            TualoApplication::contenttype('application/json');
            TualoApplication::result('f', Version::versionMD5());
            TualoApplication::result('success', true);
        }, ['get'], false, [], self::scope());
    }
}
