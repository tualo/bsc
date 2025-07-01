<?php

namespace Tualo\Office\BSC\Routes;

use Exception;
use Tualo\Office\Basic\TualoApplication as App;
use Tualo\Office\Basic\Route;
use Tualo\Office\Basic\IRoute;


class RegisterClient implements IRoute
{
    public static function register()
    {
        Route::add('/registerclient', function ($matches) {

            //$tablename = $matches['tablename'];
            $session = App::get('session');
            App::logger('BSC')->error("^__^ RegisterClient called with params: " . json_encode($_REQUEST));
            $db = $session->getDB();
            try {
                if (($key = App::configuration('oauth', 'key')) !== false) {
                    if (class_exists("\Tualo\Office\TualoPGP\TualoApplicationPGP") == false) throw new Exception('TualoPGP not installed');
                }

                if (!isset($_REQUEST['path'])) throw new Exception('path not set');
                $token = $session->registerOAuth(
                    $params = ['cmp' => 'cmp_ds'],
                    $force = true,
                    $anyclient = false,
                    $path = $_REQUEST['path'],
                    $name = isset($_REQUEST['name']) ? $_REQUEST['name'] : '',
                    $device = isset($_REQUEST['device']) ? $_REQUEST['device'] : '',
                );
                $session->oauthValidDays($token, 7);

                if ($key !== false) {

                    App::result('token_clean', $token);
                    $token = base64_encode(\Tualo\Office\TualoPGP\TualoApplicationPGP::encrypt(file_get_contents($key), $token));
                }


                App::result('token', $token);
                App::result('success', true);
            } catch (Exception $e) {
                App::result('msg', $e->getMessage());
            }
            App::contenttype('application/json');
        }, ['get', 'post'], true);
    }
};
