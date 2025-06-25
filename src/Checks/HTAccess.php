<?php

namespace Tualo\Office\BSC\Checks;

use Tualo\Office\Basic\Middleware\Session;
use Tualo\Office\Basic\PostCheck;
use Tualo\Office\Basic\TualoApplication as App;


class HTAccess  extends PostCheck
{



    public static function test(array $config)
    {
        if (!file_exists(App::get('basePath') . '/vendor/.htaccess')) {
            self::formatPrintLn(['red'], "\t vendor/.htaccess not found, please run `./tm install-htaccess` to create it");
        }
    }
}
