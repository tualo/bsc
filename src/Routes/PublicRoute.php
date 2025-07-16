<?php

namespace Tualo\Office\BSC\Routes;

use Tualo\Office\Basic\TualoApplication as App;
use Tualo\Office\Basic\Route as BasicRoute;
use Tualo\Office\Basic\IRoute;


class PublicRoute implements IRoute
{

    public static function register()
    {
        BasicRoute::add('/public/(?P<path>.*)', function ($matches) {


            $publicpath =  App::configuration(
                'tualo-backend',
                'public_path'
            );
            if ($publicpath !== false) {
                if (file_exists(
                    str_replace(
                        '//',
                        '/',
                        implode('/', [
                            $publicpath,
                            $matches['path']
                        ])
                    )
                )) {
                    App::etagFile(str_replace('//', '/', implode('/', [
                        $publicpath,
                        $matches['path']
                    ])), true);
                    BasicRoute::$finished = true;
                    http_response_code(200);
                }
            }
        }, ['get', 'post'], true);
    }
}
