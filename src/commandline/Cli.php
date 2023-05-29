<?php

use Garden\Cli\Cli;
use Tualo\Office\Basic\TualoApplication;
use Tualo\Office\Basic\IPreCheck;
// Require composer's autoloader.
require_once 'vendor/autoload.php';


TualoApplication::set('basePath', getcwd() );
TualoApplication::set('cachePath', TualoApplication::get('basePath').'/cache/' );
TualoApplication::set('configurationFile',TualoApplication::get('basePath').'/configuration/.htconfig');
$settings = parse_ini_file((string)TualoApplication::get('configurationFile'),true);
TualoApplication::set('configuration',$settings);

// Define the cli options.
$cli = new Cli();

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
    /*
    ->opt('host:h', 'Connect to host.', true)
    ->opt('port:P', 'Port number to use.', false, 'integer')
    ->opt('user:u', 'User for login if not current user.', true)
    ->opt('password:p', 'Password to use when connecting to server.')
    ->opt('database:d', 'The name of the database to dump.', true);
    */

    ->command('postcheck')
    ->description('runs postcheck commands for all modules')
    ->opt('client', 'only use this client', false, 'string')
    ;

    
    $args = $cli->parse($argv, true);

if($args->getCommand()=='setup'){
    echo $args->getOpt('createsessiondb','session').PHP_EOL;
    echo $args->getOpt('createclientdb','sample').PHP_EOL;

    // mysql -A -e "create database sessions CHARACTER SET utf8 COLLATE utf8_general_ci" 
    // mysql -A sessions < module-dev/bsc/src/commandline/tpl/sessions.sql 

    // mysql -A -e "create database testdb CHARACTER SET utf8 COLLATE utf8_general_ci" 
    // mysql --force=true -A testdb < module-dev/bsc/src/commandline/tpl/db.sql 
    // mysql -A testdb < module-dev/bsc/src/commandline/tpl/sessionviews.sql 
}


if($args->getCommand()=='postcheck'){
    //echo $args->getOpt('client').' testing' .PHP_EOL;

    Tualo\Office\Basic\PostCheck::loopClients($settings,$args->getOpt('client'));
    /*

    $classes = get_declared_classes();
    $interfaces = get_declared_interfaces();
    foreach($classes as $cls){
        $class = new \ReflectionClass($cls);
        if ( $class->implementsInterface('Tualo\Office\Basic\IPostCheck') ) {
            $cls::test($settings);
        }
    }
    */
    
}
