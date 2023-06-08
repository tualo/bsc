<?php
namespace Tualo\Office\Basic;
use Garden\Cli\Cli;
use Garden\Cli\Args;
use Tualo\Office\Basic\ICommandline;
use Tualo\Office\ExtJSCompiler\Helper;
use Tualo\Office\Basic\TualoApplication as App;
use Tualo\Office\Basic\PostCheck;

class MaintainceCommandline implements ICommandline{

    public static function getCommandName():string { return 'maintaince';}

    public static function setup(Cli $cli){
        $cli->command(self::getCommandName())
            ->description('set tualo office maintaince mode.')
            ->opt('on', 'enable maintaince mode.', false, 'boolean')
            ->opt('off', 'disable maintaince mode.', false, 'boolean');
    }
    public static function run(Args $args){
        //        PostCheck::loopClients(App::get('configuration'),$args->getOpt('client'));
    }
}
