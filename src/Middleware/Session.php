<?php
namespace tualo\Office\Basic\Middleware;
use tualo\Office\Basic\TualoApplication;
use tualo\Office\Basic\IMiddleware;
class Session implements IMiddleware{
    public static function register(){
        $middlewareOrder=-9000000;
        include __DIR__.'/session/sessionhandler.php'; $middlewareOrder++;
        include __DIR__.'/session/instance.php'; $middlewareOrder++;
        include __DIR__.'/session/logout.php'; $middlewareOrder++;
        include __DIR__.'/session/login.php'; $middlewareOrder++;
        //include __DIR__.'/session/oauth.php'; $middlewareOrder++;
        include __DIR__.'/session/temp.php'; $middlewareOrder++;

    }
}
