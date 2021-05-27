<?php

use Garden\Cli\Cli;

// Require composer's autoloader.
require_once 'vendor/autoload.php';

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
    ->opt('off', 'disable maintaince mode.', false, 'boolean');
    /*
    ->opt('host:h', 'Connect to host.', true)
    ->opt('port:P', 'Port number to use.', false, 'integer')
    ->opt('user:u', 'User for login if not current user.', true)
    ->opt('password:p', 'Password to use when connecting to server.')
    ->opt('database:d', 'The name of the database to dump.', true);
    */
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
