<?php

use Garden\Cli\Cli;
use Tualo\Office\Basic\TualoApplication;
use Tualo\Office\Basic\IPreCheck;
use Tualo\Office\Basic\ICommandline;

// Require composer's autoloader.
require_once 'vendor/autoload.php';

$is_web=http_response_code()!==FALSE;
if ($is_web) exit();


TualoApplication::set('basePath', getcwd() );
TualoApplication::set('cachePath', TualoApplication::get('basePath').'/cache/' );
if (!file_exists(TualoApplication::get('basePath').'/configuration')){
    mkdir(TualoApplication::get('basePath').'/configuration');
}
if (!file_exists(TualoApplication::get('basePath').'/configuration/.htconfig')){
    exec('which sencha', $sencha_command, $return_var);
    if (isset($sencha_command[0])){
        $sencha_command=$sencha_command[0];
    }else{
        $sencha_command='sencha';
    }
    exec('echo $HOME', $home_command, $return_var);
    if (isset($home_command[0])){
        $home_command=$home_command[0];
    }else{
        $home_command='~';
    }

    file_put_contents(TualoApplication::get('basePath').'/configuration/.htconfig',
    implode("\n",
        [
            '__DRIVER__          =MYSQL',
            '__SESSION_DSN__     =sessions',
            '__SESSION_USER__    =sessionuser',
            '__SESSION_PASSWORD__=',
            '__SESSION_HOST__    =127.0.0.1',
            '__SESSION_PORT__    =3306',
            '__COOKIE_PATH__     =/',
            '[ext-compiler]',
            "sencha_compiler_command=".$sencha_command[0],
            'sencha_compiler_sdk='.$home_command.'/sencha/ext-7.6.0',
            'sencha_compiler_toolkit=classic'
        ]
    )
    );
}
TualoApplication::set('configurationFile',TualoApplication::get('basePath').'/configuration/.htconfig');
$settings = parse_ini_file((string)TualoApplication::get('configurationFile'),true);
TualoApplication::set('configuration',$settings);

// Define the cli options.
$cli = new Cli();

($GLOBALS["argv"][0]='./tm');

//$cli->meta("filename", "tualo office commandline client.");
/*
$cli

    ->command('setup')
    ->description('tualo office - setup')
    ->opt('createsessiondb', 'new session db name', false)
    ->opt('createclientdb', 'new client db name', false)
    ->opt('sessiondbusername:su', 'session db username', false)
    ->opt('sessiondbpassword:sp', 'session db password', false)
    ->opt('clientdbusername:cu', 'client db username', false)
    ->opt('clientdbpassword:cp', 'client db password', false)

    
    ->command('maintaince')
    ->description('tualo office commandline client.')
    ->opt('on', 'enable maintaince mode.', false, 'boolean')
    ->opt('off', 'disable maintaince mode.', false, 'boolean')
 
    ->opt('host:h', 'Connect to host.', true)
    ->opt('port:P', 'Port number to use.', false, 'integer')
    ->opt('user:u', 'User for login if not current user.', true)
    ->opt('password:p', 'Password to use when connecting to server.')
    ->opt('database:d', 'The name of the database to dump.', true);
    */

    
$classes = get_declared_classes();
foreach($classes as $cls){
    $class = new \ReflectionClass($cls);
    if ( $class->implementsInterface('Tualo\Office\Basic\ICommandline') ) {
        $cls::setup($cli);
    }
}
$args = $cli->parse($argv, true);
foreach($classes as $cls){
    $class = new \ReflectionClass($cls);
    if ( $class->implementsInterface('Tualo\Office\Basic\ICommandline') ) {
        if($args->getCommand()==$cls::getCommandName()){
            $cls::run($args);
        }
    }
}