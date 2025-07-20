<?php

namespace Tualo\Office\BSC\Commands;

use Garden\Cli\Cli;
use Garden\Cli\Args;
use phpseclib3\Math\BigInteger\Engines\PHP;
use Tualo\Office\Basic\ICommandline;
use Tualo\Office\ExtJSCompiler\Helper;
use Tualo\Office\Basic\TualoApplication as App;
use Tualo\Office\Basic\PostCheck;

class InstallHTAccessCommandline implements ICommandline
{

    public static function getCommandName(): string
    {
        return 'install-htaccess';
    }

    public static function setup(Cli $cli)
    {
        $cli->command(self::getCommandName())
            ->description('installs .htaccess ');
    }


    public static function run(Args $args)
    {
        if (!file_exists(App::get('basePath') . '/.htaccess')) {
            copy(App::get('basePath') . '/vendor/tualo/bsc/src/commandline/tpl/tpl.htaccess', App::get('basePath') . '/.htaccess');
            PostCheck::formatPrintLn(['green'], "\t done");
        }

        $paths = ['configuration', 'vendor', 'ext-build', 'ext-cache', 'cache', 'temp'];
        foreach ($paths as $path) {

            if (!file_exists(App::get('basePath') . '/' . $path)) {
                mkdir(App::get('basePath') . '/' . $path, 0777, true);
                PostCheck::formatPrintLn(['green'], "\t " . $path . " created");
            } else {
                PostCheck::formatPrintLn(['green'], "\t " . $path . " already exists");
            }

            if (!file_exists(App::get('basePath') . '/' . $path . '/.htaccess')) {
                file_put_contents(App::get('basePath') . '/' . $path . '/.htaccess', implode("\n", [
                    'Order Allow,Deny',
                    'Deny from all'
                ]));
                PostCheck::formatPrintLn(['green'], "\t " . $path . "/.htaccess created");
            } else {
                PostCheck::formatPrintLn(['green'], "\t " . $path . "/.htaccess already exists");
            }
        }
    }
}
