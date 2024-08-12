<?php
namespace Tualo\Office\Basic\Middleware;
use Tualo\Office\Basic\TualoApplication;
use Tualo\Office\Basic\IMiddleware;
class UserDevice implements IMiddleware{
    public static function register(){
       TualoApplication::use('TualoApplication_userdevice',function(){
            $session = TualoApplication::get('session');
            if ($session->getHeader('userdevice')){
                $db = TualoApplication::get('session')->getDB();
                $db->direct('set @userdevice = {userdevice}',[
                    'userdevice'=>$session->getHeader('userdevice')
                ]);
            }

            if ($session->getHeader('userid')){
                $db = TualoApplication::get('session')->getDB();
                $db->direct('set @userid = {userid}',[
                    'userid'=>$session->getHeader('userid')
                ]);
            }
        },0,[],true);
    }
}
