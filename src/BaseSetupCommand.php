<?php
namespace Tualo\Office\Basic;
use Garden\Cli\Cli;

class BaseSetupCommand {

    public static function performInstall(string $cmdString,string $clientName) {
        $cmd = explode(' ',$cmdString);
        $cmd[] = '--client='.$clientName;
        $classes = get_declared_classes();
        foreach($classes as $cls){
            $class = new \ReflectionClass($cls);
            if ( $class->implementsInterface('Tualo\Office\Basic\ICommandline') ) {
                if($cmd[0]==$cls::getCommandName()){
                    $cli = new Cli();
                    $cls::setup($cli);
                    $args = $cli->parse(['./tm',...$cmd], true);
                    $cls::run($args);
                }
            }
        }
    }
}
