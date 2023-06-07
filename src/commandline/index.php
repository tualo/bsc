<?php

require_once __DIR__ . '/vendor/autoload.php';

use Tualo\Office\Server\Server;

try{
    $server = new Server();
    $server->run();
}catch(\Exception $e){
    echo $e->getMessage();
}