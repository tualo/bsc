<?php

namespace Tualo\Office\Basic;

use Garden\Cli\Cli;
use Garden\Cli\Args;
use Tualo\Office\Basic\ICommandline;
use Tualo\Office\ExtJSCompiler\Helper;
use Tualo\Office\Basic\TualoApplication as App;
use Tualo\Office\Basic\PostCheck;
use Tualo\Office\Basic\Version;

class PostCheckCommandline implements ICommandline
{

    public static function getCommandName(): string
    {
        return 'postcheck';
    }

    public static function setup(Cli $cli)
    {
        $cli->command(self::getCommandName())
            ->description('runs postcheck commands for all modules')
            ->opt('client', 'only use this client', false, 'string');
    }
    public static function run(Args $args)
    {
        PostCheck::loopClients((array)App::get('configuration'), $args->getOpt('client'));
        // Version::versionMD5(true);
        if (!file_exists(App::get('basePath') . '/cache')) {
            mkdir(App::get('basePath') . '/cache');
        }
        if (!file_exists(App::get('basePath') . '/temp')) {
            mkdir(App::get('basePath') . '/temp');
        }
    }
}
