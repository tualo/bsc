<?php
namespace Tualo\Office\Basic\Middleware;
use Tualo\Office\Basic\TualoApplication;
use Tualo\Office\Basic\IMiddleware;
class SettingsCheck implements IMiddleware{
    public static function register(){
        TualoApplication::use('TualoApplication_PHP_Settingscheck',function(){
            try{
                /*
                $pfname = TualoApplication::get('basePath').'/cache/pid';
                ini_set('html_errors', false);

                // Log only once
                if (!file_exists( $pfname )){
                    file_put_contents( $pfname, getmypid() );
                    $settings = ini_get_all();
                
                    if (@$settings['session.cookie_lifetime']['local_value']!=0){
                        error_log("session.cookie_lifetime should be 0");
                    }
                    if (@$settings['session.use_strict_mode']['local_value']!==true){
                        error_log("session.use_strict_mode should be on");
                    }
                    if (@$settings['session.cookie_httponly']['local_value']!==true){
                        error_log("session.cookie_httponly should be on");
                    }
                    if (@$settings['session.cookie_samesite']['local_value']!="Strict"){
                        error_log("session.cookie_samesite should be Strict");
                    }
                }
                */
        
            }catch(\Exception $e){
                TualoApplication::set('maintanceMode','on');
                TualoApplication::addError($e->getMessage());
            }
        },-9999999999,[],false);
    }
}