<?php
namespace Tualo\Office\Basic;
use Garden\Cli\Cli;
use Garden\Cli\Args;
use phpseclib3\Math\BigInteger\Engines\PHP;
use Tualo\Office\Basic\ICommandline;
use Tualo\Office\ExtJSCompiler\Helper;
use Tualo\Office\Basic\TualoApplication as App;
use Tualo\Office\Basic\PostCheck;

class CreateTMShell implements ICommandline {

    public static $shortName  = '';
    public static $dir = '';
    public static $files = [];


    public static function getCommandName():string {  
        
        return 'create-tm-shell';
    }

    public static function getFiles():array {  
        if (count(static::$files)==0  ){
            throw new \Exception('files is not set');
        }
        return static::$files;
    }

    public static function setup(Cli $cli){
        $cli->command(static::getCommandName())
            ->description('create the cli shortcut for tm shell');
    }


    public static function run(Args $args){
        if (!file_exists(App::get('basePath') . '/tm')) {
            copy(App::get('basePath') . '/vendor/tualo/bsc/src/commandline/client-script', App::get('basePath') . '/tm');
            chmod(App::get('basePath') . '/tm', 0755);
        }
        if (!file_exists(App::get('basePath') . '/index.php')) {
            copy(App::get('basePath') . '/vendor/tualo/bsc/src/commandline/index.php', App::get('basePath') . '/index.php');
        }
    }
}
