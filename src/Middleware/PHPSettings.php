<?php
namespace Tualo\Office\Basic\Middleware;
use Tualo\Office\Basic\TualoApplication;
use Tualo\Office\Basic\IMiddleware;
class PHPSettings implements IMiddleware{
    public static function register(){
        TualoApplication::use('TualoApplication_PHPSettings',function(){
                $cnf = TualoApplication::get('configuration');
                $key='php-settings';
                foreach($cnf as $section=>$settings){
                    if ($section=='php-settings'){
                        foreach($settings as $key=>$value){
                            ini_set($key,$value);
                        }
                    }
                }
        },-199999999,[],false);
    }
}