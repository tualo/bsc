<?php
namespace Tualo\Office\Basic\Middleware;
use Tualo\Office\Basic\TualoApplication;
use Tualo\Office\Basic\IMiddleware;
class Session implements IMiddleware{
    public static function register(){
        $middlewareOrder=-9000000;
        include __DIR__.'/session/instance.php'; $middlewareOrder++;
        include __DIR__.'/session/logout.php'; $middlewareOrder++;
        include __DIR__.'/session/login.php'; $middlewareOrder++;
        include __DIR__.'/session/auth.php'; $middlewareOrder++;
        include __DIR__.'/session/temp.php'; $middlewareOrder++;

    }
}
