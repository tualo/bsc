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


class Index extends \Tualo\Office\Basic\RouteWrapper
{


    public static function register()
    {


        Route::add('/', function () {

            TualoApplication::contenttype('text/html');
            if (!file_exists((string)TualoApplication::get('cachePath') . '/pugcache')) {
                mkdir((string)TualoApplication::get('cachePath') . '/pugcache', 0777, true);
            }

            $pug = PUG::getPug([
                'pretty' => true,
                'cache' => (string)TualoApplication::get('cachePath') . '/pugcache'
            ]);

            //unload=self
            $pmp  = TualoApplication::configuration('tualo-backend', 'pmp', [
                "geolocation=()",
                "microphone=()",
                "sync-xhr=(self)",
                "camera=()",
                "usb=()",
                "unload=self"
            ]);
            header("Permissions-Policy: " . implode(',', $pmp));


            $csp = TualoApplication::configuration('tualo-backend', 'csp', ["base-uri 'self'; default-src 'self' data:; script-src 'self' 'unsafe-eval' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; form-action 'self'; img-src 'self' data:; worker-src 'self' 'unsafe-inline' * blob:; frame-src 'self';"]);
            header("Content-Security-Policy: " . implode(';', $csp));

            try {

                $pugfile =  TualoApplication::configuration(
                    'tualo-backend',
                    'pugfile',
                    dirname(__DIR__) . '/tpl/pages/basic/index.pug'
                );

                if (TualoApplication::get('maintanceMode') == 'on') {
                    $pugfile =  TualoApplication::configuration(
                        'tualo-backend',
                        'maintenance',
                        dirname(__DIR__) . '/tpl/pages/basic/maintance.pug'
                    );
                }

                $params = array(
                    'title'             =>  TualoApplication::get('htmltitle', 'tualo office'),
                    'message'           =>  TualoApplication::get('message', 'tualo office'),
                    'stylesheets'       =>  TualoApplication::stylesheet(),
                    'javascripts'       =>  TualoApplication::javascript(),
                    'modules'           =>  TualoApplication::module()

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
