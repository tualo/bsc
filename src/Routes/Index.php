<?php

namespace Tualo\Office\Basic\Routes;

use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;
use RegexIterator;
use Tualo\Office\Basic\TualoApplication;
use Tualo\Office\Basic\Route;
use Tualo\Office\Basic\IRoute;
use Tualo\Office\Basic\Version;
use Tualo\Office\PUG\PUG;


class Index implements IRoute
{


    public static function register()
    {



        // usage: to find the test.zip file recursively
        // $result = rsearch($_SERVER['DOCUMENT_ROOT'], '/.*\/test\.zip/'));

        Route::add('/versionsum', function () {
            TualoApplication::contenttype('application/json');
            TualoApplication::result('f', Version::versionMD5());
            TualoApplication::result('success', true);
        }, ['get'], false);

        Route::add('/', function () {

            TualoApplication::contenttype('text/html');
            if (!file_exists(TualoApplication::get('cachePath') . '/pugcache')) {
                mkdir(TualoApplication::get('cachePath') . '/pugcache', 0777, true);
            }

            $pug = PUG::getPug([
                'pretty' => true,
                'cache' => TualoApplication::get('cachePath') . '/pugcache'
            ]);

            $csp = TualoApplication::configuration('tualo-backend', 'csp', ["base-uri 'none', base-uri 'self'; default-src 'self' data:; script-src 'self' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; form-action 'self'; img-src 'self' data:; worker-src 'self' 'unsafe-inline' * blob:; frame-src 'self';"]);
            header("Content-Security-Policy: " . implode(' ', $csp));



            try {
                // $pugfile = TualoApplication::get('basePath').'/pages/custom/index.pug';

                $pugfile =  TualoApplication::configuration(
                    'tualo-backend',
                    'pugfile',
                    dirname(__DIR__) . '/tpl/pages/basic/index.pug'
                );

                // if (!file_exists( $pugfile )) $pugfile = dirname(__DIR__).'/tpl/pages/basic/index.pug';
                // if ( defined( 'INDEX_PUG' ) && file_exists( INDEX_PUG ) ) $pugfile = INDEX_PUG;


                $params = array(
                    'title'             =>  TualoApplication::get('htmltitle', 'tualo office'),
                    'stylesheets'       =>  TualoApplication::stylesheet(),
                    'javascripts'       =>  TualoApplication::javascript(),
                    'modules'       =>  TualoApplication::module()

                );

                $params['shortcut_iconurl'] =  TualoApplication::configuration(
                    'tualo-backend',
                    'shortcut_iconurl',
                    './bscimg/favicon-32x32.png'
                );

                $params['shortcut_iconurl_128'] =  TualoApplication::configuration(
                    'tualo-backend',
                    'shortcut_iconurl',
                    './bscimg/favicon-128x128.png'
                );

                $params['checksum'] = Version::versionMD5();


                TualoApplication::body($pug->renderFile($pugfile, $params));
            } catch (\Exception $e) {
                echo $e->getMessage();
            }
        }, ['get', 'post']);
    }
}
