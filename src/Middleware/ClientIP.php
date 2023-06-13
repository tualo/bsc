<?php
namespace Tualo\Office\Basic\Middleware;
use Tualo\Office\Basic\TualoApplication;
use Tualo\Office\Basic\IMiddleware;
class ClientIP implements IMiddleware{
    public static function register(){
        TualoApplication::use('TualoApplication_ClientIP',function(){
            try{
                $config = TualoApplication::get('configuration');
                $field = 'REMOTE_ADDR';
                if ((isset($config['__CMS_ALLOWED_IP_FIELD__']) && isset($_SERVER[$config['__CMS_ALLOWED_IP_FIELD__']]))){
                    $field = $config['__CMS_ALLOWED_IP_FIELD__'];
                }
                if (isset($_SERVER[$field])){
                    TualoApplication::set('clientIP',$_SERVER[$field]);
                }else{
                    TualoApplication::set('clientIP','not set');
                }
            }catch(\Exception $e){
                TualoApplication::set('maintanceMode','on');
                TualoApplication::addError($e->getMessage());
            }
        },-9999999999,[],false);
    }
}