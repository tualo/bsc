<?php
namespace tualo\Office\Basic\Middleware;
use tualo\Office\Basic\TualoApplication;
use tualo\Office\Basic\IMiddleware;
use tualo\Office\Basic\Route;

class Router implements IMiddleware{

    public static function load(){
        $classes = get_declared_classes();
        foreach($classes as $cls){
            $class = new \ReflectionClass($cls);
            if ( $class->implementsInterface('tualo\Office\Basic\IRoute') ) {
                $cls::register();
            }
        }
    }

    public static function register(){
        self::load();

        TualoApplication::use('TualoApplicationRouter',function(){
            try{
                Route::run(TualoApplication::get('requestPath'));
            }catch(\Exception $e){
                TualoApplication::set('maintanceMode','on');
                TualoApplication::addError($e->getMessage());
            }
        },9999999999,[],false);

    }
}