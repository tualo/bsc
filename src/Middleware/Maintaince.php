<?php
namespace tualo\Office\Basic\Middleware;
use tualo\Office\Basic\TualoApplication;
use tualo\Office\Basic\IMiddleware;
class Maintaince implements IMiddleware{
    public static function register(){
        TualoApplication::set('maintance', $maintance = function (){

            if ((TualoApplication::has('maintanceMode')) && (TualoApplication::get('maintanceMode')=='on')){
                TualoApplication::contenttype('text/html');
                TualoApplication::stopmiddlewares();
                TualoApplication::stopbuffering();

                $pug = new Pug([
                    'pretty' => true,
                ]);
                try{
                    $pugfile = TualoApplication::get('basePath').'/pages/custom/maintance.pug';
                    if (!file_exists( $pugfile )){
                        $pugfile = dirname(__FILE__).'/pages/basic/maintance.pug';
                    }
                    TualoApplication::body( $pug->renderFile($pugfile,array(
                            'title'=>'Wartungsarbeiten',
                            'message'=>'Das System ist vorübergehend nicht zu erreichen, versuchen Sie es in einigen Minuten nochmals'
                        ))
                    );
                }catch(\Exception $e){
                    echo $e->getMessage();
                }
            }
        });
    }
}
