<?php
namespace Tualo\Office\Basic\Routes;
use Tualo\Office\Basic\TualoApplication;
use Tualo\Office\Basic\Route;
use Tualo\Office\Basic\IRoute;


class Index implements IRoute{
    public static function register(){


        Route::add('/',function(){

            TualoApplication::contenttype('text/html');
            if (!file_exists(TualoApplication::get('cachePath').'/pugcache')){
                mkdir(TualoApplication::get('cachePath').'/pugcache',0777,true);
            }
            
            $pug = new \Pug([
                'pretty' => true,
                'cache' => TualoApplication::get('cachePath').'/pugcache'
            ]);

            //'unsafe-eval'
            header("Content-Security-Policy: base-uri 'none', base-uri 'self'; default-src 'self' data:; script-src 'self' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; form-action 'self'; img-src 'self' data:");

            

            try{
                $pugfile = TualoApplication::get('basePath').'/pages/custom/index.pug';
                if (!file_exists( $pugfile )) $pugfile = dirname(__DIR__).'/tpl/pages/basic/index.pug';
                if ( defined( 'INDEX_PUG' ) && file_exists( INDEX_PUG ) ) $pugfile = INDEX_PUG;


                $params = array(
                    'title'             =>  TualoApplication::get('htmltitle','tualo office'),
                    'stylesheets'       =>  TualoApplication::stylesheet(),
                    'javascripts'       =>  TualoApplication::javascript(),
                    'modules'       =>  TualoApplication::module()

                );
                if (defined('SHORTCUT_ICONURL')) {
                    $params[ 'shortcut_iconurl' ] = SHORTCUT_ICONURL;
                }

                TualoApplication::body( $pug->renderFile($pugfile,$params));
                
            }catch(\Exception $e){
                echo $e->getMessage();
            }
        },['get','post']);

    }
}
