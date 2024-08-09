<?php
namespace Tualo\Office\BSC\Commands;
use Garden\Cli\Cli;
use Garden\Cli\Args;
use phpseclib3\Math\BigInteger\Engines\PHP;
use Tualo\Office\Basic\ICommandline;
use Tualo\Office\ExtJSCompiler\Helper;
use Tualo\Office\Basic\TualoApplication as App;
use Tualo\Office\Basic\PostCheck;

class SetupCommandline implements ICommandline{

    public static function getCommandName():string { return 'setup';}

    public static function setup(Cli $cli){

        $classes = get_declared_classes();
        foreach($classes as $cls){
            $class = new \ReflectionClass($cls);
            if ( $class->implementsInterface('Tualo\Office\Basic\ISetupCommandline') ) {
                $description = $cls::getCommandDescription();
                $cli->command(self::getCommandName().' '.$cls::getCommandName())
                    ->description($description)
                    ->opt('client', 'only use this client', false, 'string');
            }
        }

        $cli->command(self::getCommandName() )
            ->description('show all setups');

    }

    public static function run(Args $args){
        if( count($args->getArgs() )==0){
            $classes = get_declared_classes();
            foreach($classes as $cls){
                $class = new \ReflectionClass($cls);
                if ( $class->implementsInterface('Tualo\Office\Basic\ISetupCommandline') ) {
                    echo "./tm ".self::getCommandName().' '.$cls::getCommandName().PHP_EOL;
                }
            }
        }else{

            $classes = get_declared_classes();
            $argv = $GLOBALS["argv"];
            array_shift($argv);
            $argv[0]=$GLOBALS["argv"][0];
           
            foreach($classes as $cls){
                $class = new \ReflectionClass($cls);
                if ( $class->implementsInterface('Tualo\Office\Basic\ISetupCommandline') ) {
                    if($cls::getCommandName()==$argv[1]){
                        $cli = new Cli();
                        $cls::setup($cli);
                        $args = $cli->parse($argv, true);
                        $cls::run($args);
                    }
                }
            }
        }
    }
}