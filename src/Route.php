<?php
namespace Tualo\Office\Basic;

class Route{

    private static $routes = Array();
    private static $basepath = '/';
    private static $pathNotFound = null;
    private static $methodNotAllowed = null;
    public static $finished=false;

    public static function add($expression, $function, $method = 'get', $needActiveSession=false){
        if (!is_array($method)){
            $method=array($method);
        }
        foreach($method as $fn){
            array_push(self::$routes,Array(
                'expression'        => $expression,
                'function'          => $function,
                'method'            => $fn,
                'needActiveSession' => $needActiveSession
            ));
        }
    }

    public static function pathNotFound($function){
        self::$pathNotFound = $function;
    }

    public static function methodNotAllowed($function){
        self::$methodNotAllowed = $function;
    }

    public static function run($basepath = '/'){
        // Parse current url

        self::$basepath = $basepath;
        $parsed_url = parse_url($_SERVER['REQUEST_URI']);//Parse Uri
        if(isset($parsed_url['path'])){
            $path = $parsed_url['path'];
        }else{
            $path = '/';
        }
        $method = $_SERVER['REQUEST_METHOD'];
        self::runpath($path,$method);
    }

    public static function runpath($path,$method){
        $path_match_found = false;
        $route_match_found = false;
        $route_method_found = false;


        $session_is_active = !is_null(TualoApplication::get('session'))&&(TualoApplication::get('session')->getDB());
        foreach(self::$routes as $route){

            if (($session_is_active===false)&&($route['needActiveSession']===true)){
                continue; 
            }
            // If the method matches check the path
            // Add basepath to matching string
            if(self::$basepath!=''&&self::$basepath!='/'){
                $route['expression'] = '('.self::$basepath.')'.$route['expression'];
            }
            // Add 'find string start' automatically
            $route['expression'] = '^'.$route['expression'];
            // Add 'find string end' automatically
            $route['expression'] = $route['expression'].'$';

            // Check path match	
            if(preg_match('#'.$route['expression'].'#',$path,$matches) &&(!self::$finished) ){
                $path_match_found = true;
                // Check method match
                
                if(strtolower($method) == strtolower($route['method'])){
                    array_shift($matches);// Always remove first element. This contains the whole string
                    if(self::$basepath!=''&&self::$basepath!='/'){
                        array_shift($matches);// Remove basepath
                    }
                    call_user_func_array($route['function'], array($matches));
                    $route_method_found = true;
                    // Do not check other routes
                    if (self::$finished){
                        break;
                    }
                }
            }
        }

        // No matching route was found
        if(!$route_match_found){

            // But a matching path exists
            if(!$route_method_found){
                header("HTTP/1.0 405 Method Not Allowed");
                if(self::$methodNotAllowed){
                    call_user_func_array(self::$methodNotAllowed, Array($path,$method));
                }
            }else{
                /*
                header("HTTP/1.0 404 Not Found");
                if(self::$pathNotFound){
                    call_user_func_array(self::$pathNotFound, Array($path));
                }
                */
            }

        }
    }

}