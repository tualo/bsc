<?php

use Tualo\Office\Basic\TualoApplication;
use Tualo\Office\Basic\Session;

TualoApplication::use('TualoApplicationSession_Auth', function () {
    try {
        $session = TualoApplication::get('session');


        TualoApplication::logger('BSC')->debug('Testing Cookie: ' . @session_id());

        if ($session->getHeader('Authorization') !== false) {

            TualoApplication::logger('BSC')->debug('Authorization Header found: ' . $session->getHeader('Authorization'));
            $authToken = $session->getHeader('Authorization');
            TualoApplication::logger('BSC')->debug('headers: ' . print_r(getallheaders(), true));
            TualoApplication::logger('BSC')->debug('request: ' . print_r($_REQUEST, true));

            if (strpos($authToken, 'Bearer ') !== false) {
                $authToken = str_replace('Bearer ', '', $authToken);
            }


            if (trim($authToken) === '' || $authToken === 'Bearer') {
                // throw new \Exception("No Authorization Token");
                TualoApplication::logger('BSC')->warning("No Authorization Token, but bearer found");
            } else {
                TualoApplication::logger('BSC')->debug('Authorization using: ' . $authToken);

                if (($key = TualoApplication::configuration('oauth', 'key')) !== false) {
                    $data = base64_decode($authToken);
                    $authToken = \Tualo\Office\TualoPGP\TualoApplicationPGP::decrypt(file_get_contents($key), $data);
                }

                $session->loginByToken($authToken);
                header("Access-Control-Allow-Origin: " . TualoApplication::configuration('oauth', 'accessControlAllowOrigin', '*'));
                session_commit();
            }
        }


        TualoApplication::logger('BSC')->warning("Session: ");

        if (!isset($_SESSION['tualoapplication']['loggedInType'])) $_SESSION['tualoapplication']['loggedInType'] = 'none';
        TualoApplication::logger('BSC')->warning("Session: " . __FILE__ . ":" . __LINE__);

        if (
            isset($_SESSION['tualoapplication']['loggedIn'])
            &&  ($_SESSION['tualoapplication']['loggedIn'] === true)
            &&  (!is_null($session))
            &&  (isset($_SERVER['REQUEST_METHOD']))
        ) {
            TualoApplication::logger('BSC')->warning("Session: " . __FILE__ . ":" . __LINE__);
            $path = '';
            $parsed_url = parse_url($_SERVER['REQUEST_URI']); //Parse Uri
            if (isset($_SERVER['REDIRECT_URL'])) $parsed_url = parse_url($_SERVER['REDIRECT_URL']);
            if (isset($parsed_url['path'])) {
                $path = $parsed_url['path'];
            } else {
                $path = '/';
            }
            /*
            if(preg_match('#/~/(?P<oauth>[\w\-]+)/*#',$path,$matches)){
                if($_SESSION['tualoapplication']['loggedInType'] != 'oauth'){
                    Session::getInstance()->destroy();
                }
            }else{
                if($_SESSION['tualoapplication']['loggedInType'] != 'login'){
                    Session::getInstance()->destroy();
                }
            }
            */
        }


        TualoApplication::logger('BSC')->warning("Session: " . __FILE__ . ":" . __LINE__);
        if (

            isset($_SESSION['tualoapplication']['loggedIn'])
            &&  ($_SESSION['tualoapplication']['loggedIn'] === false)
            &&  (!is_null($session))
            &&  (isset($_SERVER['REQUEST_METHOD']))
            &&  (

                (TualoApplication::configuration('oauth', 'key') === false)
                || isset($_SERVER['REDIRECT_STATUS'])

            )


        ) {
            TualoApplication::logger('BSC')->warning("Session: " . __FILE__ . ":" . __LINE__);
            //if (is_null($session->db)) throw new \Exception("Session DB not loaded");
            $path = '';
            $method = $_SERVER['REQUEST_METHOD'];
            $parsed_url = parse_url($_SERVER['REQUEST_URI']); //Parse Uri
            if (isset($_SERVER['REDIRECT_URL'])) $parsed_url = parse_url($_SERVER['REDIRECT_URL']);
            if (isset($parsed_url['path'])) {
                $path = $parsed_url['path'];
            } else {
                $path = '/';
            }

            if (preg_match('#/~/(?P<oauth>[\w\-]+)/*#', $path, $matches)) {
                $_SESSION['tualoapplication']['oauth'] = $matches['oauth'];
                if (isset($_SERVER['REDIRECT_URL'])) {
                    $_SERVER['REQUEST_URI'] = str_replace('/~/' . $matches['oauth'] . '/', '/', $_SERVER['REDIRECT_URL']);
                    unset($_SERVER['REDIRECT_URL']);
                } else {
                    $_SERVER['REQUEST_URI'] = str_replace('/~/' . $matches['oauth'] . '/', '/', $_SERVER['REQUEST_URI']);
                }


                $session->inputToRequest();
                $token = $matches['oauth'];
                $session->loginByToken($token);
                TualoApplication::logger('BSC')->warning("Session: " . __FILE__ . ":" . __LINE__);

                session_commit();
                TualoApplication::logger('BSC')->warning("Session: " . print_r($_SESSION, true));
            }
        } elseif (
            isset($_SESSION['tualoapplication']['loggedIn'])
            &&  ($_SESSION['tualoapplication']['loggedIn'] === true)
            &&  isset($_SESSION['tualoapplication']['oauth'])
            &&  (!is_null($session))
        ) {

            if (isset($_SERVER['REDIRECT_URL'])) {
                $_SERVER['REQUEST_URI'] = str_replace('/~/' . $_SESSION['tualoapplication']['oauth'] . '/', '/', $_SERVER['REDIRECT_URL']);
                unset($_SERVER['REDIRECT_URL']);
            } else {
                $_SERVER['REQUEST_URI'] = str_replace('/~/' . $_SESSION['tualoapplication']['oauth'] . '/', '/', $_SERVER['REQUEST_URI']);
            }
        }


        $path = '';
        $method = $_SERVER['REQUEST_METHOD'];
        TualoApplication::logger('BSC')->warning("Session method: " . $method);
        $parsed_url = parse_url($_SERVER['REQUEST_URI']); //Parse Uri
        if (isset($_SERVER['REDIRECT_URL'])) $parsed_url = parse_url($_SERVER['REDIRECT_URL']);
        if (isset($parsed_url['path'])) {
            $path = $parsed_url['path'];
        } else {
            $path = '/';
        }


        if (
            isset($_SESSION['tualoapplication']['loggedIn'])
            &&  ($_SESSION['tualoapplication']['loggedIn'] === true)
        ) {

            if (preg_match('#/~/(?P<oauth>[\w\-]+)/*#', $path, $matches)) {
                $_SESSION['tualoapplication']['oauth'] = $matches['oauth'];
                if (isset($_SERVER['REDIRECT_URL'])) {
                    $_SERVER['REQUEST_URI'] = str_replace('/~/' . $_SESSION['tualoapplication']['oauth'] . '/', '/', $_SERVER['REDIRECT_URL']);
                    unset($_SERVER['REDIRECT_URL']);
                } else {
                    $_SERVER['REQUEST_URI'] = str_replace('/~/' . $_SESSION['tualoapplication']['oauth'] . '/', '/', $_SERVER['REQUEST_URI']);
                }
            }
        }
    } catch (\Exception $e) {
        TualoApplication::set('maintanceMode', 'on');
        TualoApplication::addError($e->getMessage());
    }
}, $middlewareOrder, [], true);
