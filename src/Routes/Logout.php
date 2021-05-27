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
                // &&  ($_SESSION['tualoapplication']['loggedIn']===true)
                &&  (isset($_REQUEST['logout']))
                &&  ($_REQUEST['logout']==1)
                &&  (!is_null($session))
            ){
                TualoApplication::result('success',true);
                TualoApplication::result('msg','Bye');
                TualoApplication::contenttype('application/json');
                TualoApplication::end();
                $session->destroy();
                session_commit();
                exit();
            }
            TualoApplication::logger('TualoApplication')->warning('logout',$_SESSION);
        },['post','get'],false);
    }
}