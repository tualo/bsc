<?php

namespace Tualo\Office\Basic;

use Garden\Cli\Cli;
use Garden\Cli\Args;
use Tualo\Office\Basic\ICommandline;
use Tualo\Office\ExtJSCompiler\Helper;
use Tualo\Office\Basic\TualoApplication as App;
use Tualo\Office\Basic\PostCheck;

class VersionsumCommandline implements ICommandline
{
    public static function getCommandName(): string
    {
        return 'versionsum';
    }

    public static function setup(Cli $cli)
    {
        $cli->command(self::getCommandName())
            ->description('calculate the .ht_version ****');
    }
    public static function run(Args $args)
    {
        Version::versionMD5(true);
    }
}
