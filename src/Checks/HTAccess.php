<?php

namespace Tualo\Office\BSC\Checks;

use Tualo\Office\Basic\Middleware\Session;
use Tualo\Office\Basic\PostCheck;
use Tualo\Office\Basic\TualoApplication as App;


class HTAccess  extends PostCheck
{



    public static function test(array $config)
    {

        $paths = ['configuration', 'vendor', 'ext-build', 'ext-cache', 'cache', 'temp'];
        foreach ($paths as $path) {
            if (!file_exists(App::get('basePath') . '/' . $path . '/.htaccess')) {
                self::formatPrintLn(['red'], "\t " . $path . "/.htaccess not found, please run `./tm install-htaccess` to create it");
            }
        }
        if (!file_exists(App::get('basePath') . '/.htaccess')) {
            self::formatPrintLn(['red'], "\t .htaccess not found, please run `./tm install-htaccess` to create it");
        } else {
            self::formatPrintLn(['green'], "\t .htaccess found");
            $data = file_get_contents(App::get('basePath') . '/.htaccess');
            if (strpos($data, 'composer.json') === false) {
                self::formatPrintLn(['red'], "\t .htaccess does not contain 'composer.json', please run `rm .htaccess && ./tm install-htaccess` to recreate it");
            } else {
                self::formatPrintLn(['green'], "\t .htaccess is ok");
            }
        }
    }
}
