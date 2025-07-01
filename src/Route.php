<?php

namespace Tualo\Office\Basic;

class Route
{

    private static $routes = array();
    private static $aliases = array();
    private static $basepath = '/';
    private static $pathNotFound = null;
    private static $methodNotAllowed = null;
    public static $finished = false;


    public static function alias($alias, $origialRoute)
    {
        self::$aliases[$alias] = $origialRoute;
    }

    public static function checkDoubleDots(array $arr, string $key, string $logMe): bool
    {
        if (!isset($arr[$key]) && (strpos($arr[$key], '..') !== false)) {
            TualoApplication::body('Path not found');
            TualoApplication::contenttype('text/plain');
            http_response_code(404);
            TualoApplication::logger('BSC')->error($logMe);
            return false;
        }
        return true;
    }

    public static function add($expression, $function, $method = ['get'], $needActiveSession = false)
    {
        if (!is_array($method)) {
            $method = array($method);
        }
        foreach ($method as $fn) {
            array_push(self::$routes, array(
                'expression'        => $expression,
                'function'          => $function,
                'method'            => $fn,
                'needActiveSession' => $needActiveSession,
                'cls' => $GLOBALS['current_cls']
            ));
        }
    }

    public static function pathNotFound($function)
    {
        self::$pathNotFound = $function;
    }

    public static function methodNotAllowed($function)
    {
        self::$methodNotAllowed = $function;
    }

    public static function run($basepath = '/')
    {
        // apend aliases to routes
        foreach (self::$aliases as $alias => $original) {
            $route = null;
            foreach (self::$routes as $r) {
                if ($r['expression'] == $original) {
                    // take care, run for all entries
                    // every method is one extra entry
                    $route = $r;
                }
            }
            if ($route != null) {
                $route['expression'] = $alias;
                array_push(self::$routes, $route);
            } else {
                TualoApplication::logger('BSC')->error("target route $original not found for $alias");
            }
        }

        self::$basepath = $basepath;
        $parsed_url = parse_url($_SERVER['REQUEST_URI']); //Parse Uri
        if (isset($parsed_url['path'])) {
            $path = $parsed_url['path'];
        } else {
            $path = '/';
        }
        $path = preg_replace('/\/\//', '/', $path);
        $method = $_SERVER['REQUEST_METHOD'];
        if ($method == 'OPTIONS') {
            header("HTTP/1.0 200 OK");
            header('Access-Control-Allow-Origin: *');
            header('Access-Control-Allow-Methods: ' . strtoupper(implode(', ', self::getAllowedMethods($path))));
            header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
            header('Access-Control-Max-Age: 86400');
            exit();
        }
        self::runpath($path, $method);
    }

    public static function getAllowedMethods($path)
    {
        $allowed = [];
        foreach (self::$routes as $route) {
            // If the method matches check the path
            // Add basepath to matching string
            if (self::$basepath != '' && self::$basepath != '/') {
                $route['expression'] = '(' . self::$basepath . ')' . $route['expression'];
            }
            // Add 'find string start' automatically
            $route['expression'] = '^' . $route['expression'];
            // Add 'find string end' automatically
            $route['expression'] = $route['expression'] . '$';
            // Check path match	

            if (preg_match('#' . $route['expression'] . '#', $path, $matches) && (!self::$finished)) {
                if (is_array($route['method'])) {
                    foreach ($route['method'] as $m) {
                        if (!in_array($m, $allowed)) {
                            array_push($allowed, $m);
                        }
                    }
                } else {
                    if (!in_array($route['method'], $allowed)) {
                        array_push($allowed, $route['method']);
                    }
                }
            }
        }
        return $allowed;
    }



    public static function getRoutes()
    {
        return self::$routes;
    }

    public static function runpath($path, $method)
    {
        $path_match_found = false;

        $route_method_found = false;

        TualoApplication::timing("start routes loop", '');


        //$session_is_active = !is_null(TualoApplication::get('session'))&&(TualoApplication::get('session')->getDB());
        $session_is_active = (isset($_SESSION['tualoapplication']['loggedIn'])  &&  ($_SESSION['tualoapplication']['loggedIn'] === true));


        foreach (self::$routes as $route) {
            TualoApplication::timing("route expression (" . $route['expression'] . " - " . $route['method'] . " request " . $path . " - " . $method . ")");


            if (($session_is_active === false) && ($route['needActiveSession'] === true)) {
                continue;
            }
            // If the method matches check the path
            // Add basepath to matching string
            if (self::$basepath != '' && self::$basepath != '/') {
                $route['expression'] = '(' . self::$basepath . ')' . $route['expression'];
            }
            // Add 'find string start' automatically
            $route['expression'] = '^' . $route['expression'];
            // Add 'find string end' automatically
            $route['expression'] = $route['expression'] . '$';
            // Check path match	

            if (preg_match('#' . $route['expression'] . '#', $path, $matches) && (!self::$finished)) {


                $path_match_found = true;
                // Check method match

                if (strtolower($method) == strtolower($route['method'])) {


                    array_shift($matches); // Always remove first element. This contains the whole string
                    TualoApplication::timing("route expression array_shift matches");
                    if (self::$basepath != '' && self::$basepath != '/') {
                        array_shift($matches); // Remove basepath
                    }
                    TualoApplication::timing("route before call_user_func_array");
                    //call_user_func_array($route['function'], array($matches));

                    $session_condition_allowed = true;


                    if (isset($_SESSION['session_condition']) && isset($_SESSION['session_condition']['path'])) {

                        if (TualoApplication::configuration('logger-options', 'ROUTERUN', '0') == '1')
                            TualoApplication::logger('ROUTERUN')->debug("use path " . $_SESSION['session_condition']['path'] . " for " . $path);

                        $session_condition_allowed = false;
                        $test_path = $_SESSION['session_condition']['path'];
                        if (substr($test_path, strlen($test_path) - 1, 1) == '*') {
                            $test_path = str_replace('*', '(\.)*', $test_path);
                        }
                        if (preg_match('#' . $test_path . '#', $path, $session_condition_matches)) {
                            if (TualoApplication::configuration('logger-options', 'ROUTERUN', '0') == '1')
                                TualoApplication::logger('ROUTERUN')->debug("path matches");
                            $session_condition_allowed = true;
                        } else {
                            header($_SERVER['SERVER_PROTOCOL'] . " 404 not found");
                            if (TualoApplication::configuration('logger-options', 'ROUTERUN', '0') == '1')
                                TualoApplication::logger('ROUTERUN')->error("try to reach a path that is not allowed");
                            exit();
                        }
                    }

                    if ($session_condition_allowed === true) {
                        $return = $route['function']($matches);
                        if ($return === true) {
                            break;
                        }
                    }

                    TualoApplication::timing("after call_user_func_array");
                    $route_method_found = true;
                    // Do not check other routes
                    if (self::$finished) {
                        break;
                    }
                }
            }
        }

        $is_web = http_response_code() !== FALSE;
        // No matching route was found
        if (!self::$finished)
            if (!$path_match_found) {

                // But a matching path exists
                if (!$route_method_found) {

                    if ($is_web) {
                        header("HTTP/1.0 405 Method Not Allowed");
                    }

                    TualoApplication::logger('TualoApplication')->warning("*$path* *$method* is not allowed ", [TualoApplication::get('clientIP')]);


                    if (self::$methodNotAllowed) {
                        call_user_func_array(self::$methodNotAllowed, array($path, $method));
                    }
                    if (self::$pathNotFound) {
                        call_user_func_array(self::$pathNotFound, array($path));
                    }
                } else {
                    if ($is_web) {
                        header("HTTP/1.0 404 Not Found");
                    }
                    if (self::$pathNotFound) {
                        call_user_func_array(self::$pathNotFound, array($path));
                    }
                }
            } else {
                if (self::$pathNotFound) {
                    call_user_func_array(self::$pathNotFound, array($path));
                }
            }
    }
}
