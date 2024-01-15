<?php
namespace Tualo\Office\Basic;
use Garden\Cli\Cli;
use Garden\Cli\Args;
use Tualo\Office\Basic\ICommandline;
use Tualo\Office\ExtJSCompiler\Helper;
use Tualo\Office\Basic\TualoApplication as App;
use Tualo\Office\Basic\PreCheck;
;
use Tualo\Office\Basic\Version;
class PreCheckCommandline implements ICommandline{

    public static function getCommandName():string { return 'precheck';}

    public static function setup(Cli $cli){
        $cli->command(self::getCommandName())
            ->description('runs precheck commands for all modules')
            ->opt('client', 'only use this client', false, 'string');
            
    }
    public static function run(Args $args){
        PreCheck::loopClients((array)App::get('configuration'),$args->getOpt('client'));
        
    }

    
}
