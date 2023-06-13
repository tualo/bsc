<?php
namespace Tualo\Office\Basic\Middleware;
use Tualo\Office\Basic\TualoApplication;
use Tualo\Office\Basic\IMiddleware;
class Timezone implements IMiddleware{
    public static function register(){
        TualoApplication::use('TualoApplication_Timezone',function(){
            try{
                $config = TualoApplication::get('configuration');
                if (isset($config['TIMEZONE'])){
                    date_default_timezone_set($config['TIMEZONE']);
                }else{
                    TualoApplication::logger('TualoApplication')->debug("using default timezone ".date_default_timezone_get(),[TualoApplication::get('clientIP')]);
                }
            }catch(\Exception $e){
                TualoApplication::set('maintanceMode','on');
                TualoApplication::addError($e->getMessage());
            }
        },-9999999777,[],false);
    }
}