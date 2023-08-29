<?php
namespace Tualo\Office\Basic\Routes;
use Tualo\Office\Basic\TualoApplication;
use Tualo\Office\Basic\Route;
use Tualo\Office\Basic\IRoute;


class Logout implements IRoute{
    public static function register(){
        Route::add('/logout',function(){
            $session = TualoApplication::get('session');
            if (
                isset($_SESSION['tualoapplication']['loggedIn'])
                
                &&  (!is_null($session))
            )
            {
                @session_start();
                $_SESSION['tualoapplication']['loggedIn']=false;
                session_destroy();

                TualoApplication::result('success',true);
                TualoApplication::result('msg','Bye');
                TualoApplication::contenttype('application/json');
                Route::$finished=true;
                // session_commit();
                // exit();
            }
            TualoApplication::logger('TualoApplication')->warning('logout',$_SESSION);
        },['post','get'],true);
    }
}