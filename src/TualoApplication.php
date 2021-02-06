<?php
namespace Tualo\Office\Basic;

use Monolog\Logger;
use Monolog\Handler\StreamHandler;


/**
 * TualoApplication Class
 * 
 * @version 5.0.0
 */
class TualoApplication{
    /**
     * @var array $middlewares Array of all middlewares
     */
    private static $middlewares = array();
    /**
     * @var array $stylesheets Array of all stylesheets
     */
    private static $stylesheets = array();
    /**
     * @var array $javascripts Array of all javascripts
     */
    private static $javascripts = array();
    private static $javascriptsTree;

    /**
     * @var array $modules Array of all modules
     */
    private static $modules = array();
    private static $modulesTree;

    /**
     * @var bool $runmiddlewares flag indicating that the next middleware(s) can be executed
     */
    private static $runmiddlewares = true;
    /**
     * @var bool $output flag indicating that the the output of the middlewares will been send
     */
    private static $output = true;
    /**
     * @var array $request ....
     */
    private static $request = array();
    /**
     * @var array $vars hash of stored vars
     */
    private static $vars = array();

    private static $componentlist = [];

    /**
     * @var string $return_contenttype content type to return
     */
    private static $return_contenttype = 'text/plain';
    /**
     * @var string $resultbody body to return
     */
    private static $resultbody = '';
    /**
     * @var array $result result hash to be returned in case of json/text
     */
    private static $result = array('msg'=>'','success'=>false,'errors'=>array(),'warnings'=>array());
    /**
     * @var array $debug_result storing debug messaged
     */
    private static $debug_result = array();    
    private static $appendDebug = false;
    private static $returnField = '';
    private static $timing_result = array();
    private static $time_start = 0;
    private static $json_timing = false;
    private static $total_time_start = 0;
    private static $logger = [];


    private static function map_filename($item){ return $item['filename'];}
    private static function compare_position($a, $b){
        if ($a['position'] == $b['position']) {
            return 0;
        }
        return ($a['position'] < $b['position']) ? -1 : 1;
    }

    public static function logger($channel)
    {
        if (!isset(self::$logger[$channel])){

            $log = new Logger($channel);
            if (defined('__LOGGER_FILE__')){
                $log->pushHandler(new StreamHandler(__LOGGER_FILE__, Logger::WARNING));
            }
            self::$logger[$channel] = $log;
        }
        return self::$logger[$channel];
    }
    
    public static function showDebug($var){
        self::$appendDebug = $var;
    }
    
    public static function debug($data){
        self::$debug_result[] = $data;
    }

    public static function javascript_cmp($a, $b)
    {
        if ($a['pos']>$b['pos']) return 1;
        if ($a['pos']<$b['pos']) return -1;
        return 0;
    }
    
    public static function initComponents(){
        
        if(!is_null(TualoApplication::get('session')) && is_null(TualoApplication::get('session')->db)){
            
        }else{
            $sql = '
                select
                    macc_component.id,
                    macc_component.des,
                    macc_component.version,
                    group_concat(concat(database(),\'|\',macc_component_access.rolle) ORDER BY rolle DESC SEPARATOR \';\') groups
                from
                    macc_component left join macc_component_access on macc_component.id = macc_component_access.komponente
                where id<>\'\'
                group by des, id
            ';
            $componentlist=[];
            if(is_null(TualoApplication::get('session')->db)) throw new \Exception("Session DB not available");
            $_componentlist = TualoApplication::get('session')->db->direct( $sql );
            if ($_SESSION['tualoapplication']['loggedIn']==false){
                $_componentlist=explode(' ',BASIC_COMPONENTS);
                foreach($_componentlist as $item){
                    $componentlist[]=[
                        'includePath' => TualoApplication::get('basePath').'/cmp/'.$item,
                        'id'=>$item
                    ];
                }
            }else{
                foreach($_componentlist as $item){
                
                    if (is_dir(TualoApplication::get('basePath').'/cmp/'.$item['id'])){
                        $item['includePath'] = TualoApplication::get('basePath').'/cmp/'.$item['id'];
                    }
                    if ( is_dir( TualoApplication::get('basePath').'/packages/'.$item['version'].'/'.$item['id']) ){
                        $item['includePath'] = TualoApplication::get('basePath').'/packages/'.$item['version'].'/'.$item['id'];
                    }
                    $componentlist[]=$item;
                }
            }
            foreach($componentlist as $item){
                if (isset($item['includePath'] )){
                    self::$componentlist[]=$item;
                }else{
                    //syslog(LOG_WARNING,"Component ".$item['id']." - ".$item['version']." not found");
                }
            }
        }
        

    }
    public static function components($simple=false){
        $_componentlist=explode(' ',BASIC_COMPONENTS);
        foreach($_componentlist as $item){
            $componentlist[]=[
                'includePath' => TualoApplication::get('basePath').'/cmp/'.$item,
                'id'=>$item
            ];
        }

        if ($simple){
            $l=[];
            foreach(self::$componentlist as $elm) $l[]=$elm['id'];
            foreach($componentlist as $elm) $l[]=$elm['id'];
            return $l;
        }
        return self::$componentlist;
    }
/*

    }

    /** 
    * TualoApplication::getClientIP()
    */
    public static function getClientIP(){       
        if (array_key_exists('HTTP_X_FORWARDED_FOR', $_SERVER)){
            $i = explode(',',$_SERVER["HTTP_X_FORWARDED_FOR"]);
            return  trim( $i[0] );  
        }else if (array_key_exists('REMOTE_ADDR', $_SERVER)) { 
            return $_SERVER["REMOTE_ADDR"]; 
        }else if (array_key_exists('HTTP_CLIENT_IP', $_SERVER)) {
            return $_SERVER["HTTP_CLIENT_IP"]; 
        } 
   
        return '';
   }


    public static function timing($key='',$data=''){
        if (self::$time_start==0) self::$time_start=microtime(true); 
        if (self::$total_time_start==0) self::$total_time_start=microtime(true); 
        $time_end = microtime(true);
        self::$timing_result[] = array('key'=>$key,'total'=>$time_end-self::$total_time_start,'last'=>$time_end-self::$time_start,'data'=>$data);
        self::$time_start=$time_end;
    }


    public static function jsonReturnField($f){
        self::$returnField = $f;
    }
    /**
     * Declare middlewares
     * 
     * 
     * @param string $key middleware identifier
     * @param callable $middlewarefunction callable function
     * @param int $position ordered position
     * @return self::$middlewares
     */
    public static function use($key,$middlewarefunction,$position = 99999,$options=[],$isMain=false){
        array_push(self::$middlewares,
            [
                'cmp' => ' ',
                'position' => $position,
                'main' => $isMain,
                'expression' => '',
                'key' => $key,
                'function' => $middlewarefunction,
                'options' => $options
            ]
        );
        return self::$middlewares;
    }
    
    /**
     * Declare stylesheets
     * 
     * @param string $filename stylesheet file if not set only the list of allready declared files will be returned
     * @param int $position ordered position
     * @return array An Array of filenames
     */
    public static function stylesheet($filename='',$position=0, $key=NULL){
        if ($filename!=''){
            if (is_null($key)){ $key='ID'.count( self::$stylesheets ); }
            self::$stylesheets[] = array('position'=>$position,'filename'=>$filename,'key'=>$key);
        }
        usort(self::$stylesheets,     "self::compare_position");
        //return array_map("self::map_filename",self::$stylesheets);
        return self::$stylesheets;
    }
    
    /**
     * Declare javascripts
     * 
     * @param string $filename javascript file if not set only the list of allready declared files will be returned
     * @param int $position ordered position
     * @return array An Array of filenames
     */
    public static function javascript($key='',$filename='',$dependOn=array(),$pos=0){
        if ($filename!=''){
            self::$javascripts[$key] = array('key'=>$key,'filename'=>$filename,'pos'=>$pos);
            
            if (is_null(self::$javascriptsTree)){
                self::$javascriptsTree = new DependTree($key);
                self::$javascriptsTree->mergeChilds($dependOn);
            }else{
                self::$javascriptsTree = self::$javascriptsTree->append($key,$dependOn);
            }

        }else{
            usort( self::$javascripts, ["Tualo\Office\Basic\TualoApplication","javascript_cmp"]);
            return array_unique(array_map("self::map_filename", self::$javascripts));

        }
        //usort(self::$javascripts,   "self::compare_position"  );
        
        
        return array_map("self::map_filename", self::$javascripts);
    }

    public static function module($key='',$filename='',$dependOn=array(),$pos=0){
        if ($filename!=''){
            self::$modules[$key] = array('key'=>$key,'filename'=>$filename,'pos'=>$pos);
            
            if (is_null(self::$modulesTree)){
                self::$modulesTree = new DependTree($key);
                self::$modulesTree->mergeChilds($dependOn);
            }else{
                self::$modulesTree = self::$modulesTree->append($key,$dependOn);
            }

        }else{
            usort( self::$modules, ["Tualo\Office\Basic\TualoApplication","javascript_cmp"]);
            return array_unique(array_map("self::map_filename", self::$modules));

        }
        //usort(self::$javascripts,   "self::compare_position"  );
        
        
        return array_map("self::map_filename", self::$javascripts);
    }

    public static function javascriptLoader($filedata){
        //$filedata =  "Ext.define('TualoOffice.dashboard.controller.Application')";
        $matches=[];
        
        if (preg_match("#requires:\s*\[(?P<requires>[.\n]+)\]#m",$filedata,$matches)==1){
            print_r($matches);
        }

        if (preg_match("#define\(\'(?P<define>[\w.]+)\'#m",$filedata,$matches)==1){
            print_r($matches);
        }
        echo $filedata;

        //exit();
    }

    /**
     * Check if the variables is set
     * 
     * @param string $key Key of the variable
     * @return bool
     */
    public static function has($key){
        return isset(self::$vars[$key]);
    }


    /**
     * Get the variable value
     * 
     * @param string $key Key of the variable
     * @param any $default default value if the variable is not set
     * @return any
     */
    public static function get($key,$default=''){
        if (isset(self::$vars[$key])){
            return self::$vars[$key];
        }else{
            if ($default!=''){
                return $default;
            }else{
                //self::stopbuffering();
                self::$result['errors'][]='Variable *'.$key.'* wurde nicht gefunden';
            }
        }
    }

    /**
     * Set the variable value
     * 
     * @param string $key Key of the variable
     * @param any $value value
     * @return bool
     */
    public static function set($key,$value){
        self::$vars[$key] = $value;
        return true;
    }

    /**
     * set a value of result
     * 
     * @param string $key The key for the value
     * @param any $value The value
     * @return self::$result
     */
    public static function result($key='',$value=''){
        if ($key!=''){
            self::$result[$key]=$value;
        }
        return self::$result;
    }

    /**
     * set a value of result
     * 
     * @param string $key The key for the value
     * @param any $value The value
     * @return self::$result
     */
    public static function &resultDirect($key=''){
        return self::$result[$key];
    }

    /**
     * Add an error message
     * 
     * @param string $value The Message
     * @return self::$result['errors']
     */
    public static function addError($value){
        self::$result['errors'][]=$value;
        return self::$result['errors'];
    }

    /**
     * Add a warning.
     * 
     * @param string $value The Message
     * @return self::$result['warnings']
     */
    public static function addWarning($value){
        self::$result['warnings'][]=$value;
        return self::$result['warnings'];
    }


    /**
     * Add Data to the return body.
     * 
     * @param string $buffer The Data to be append
     * @return self::$resultbody
     */
    public static function body($buffer){

        self::$resultbody .= $buffer;
        return self::$resultbody;
    }


    
    /**
     * Send file, with ETag
     * 
     * @param string $buffer The Data to be append
     * @return self::$resultbody
     */
    public static function etagFile($file,$sendContentType=false){

        $last_modified_time = filemtime($file); 
        $etag = md5_file($file); 
        if ($sendContentType==true){

            $mime_types = [

                'txt' => 'text/plain',
                'htm' => 'text/html',
                'html' => 'text/html',
                'php' => 'text/html',
                'css' => 'text/css',
                'js' => 'application/javascript',
                'json' => 'application/json',
                'xml' => 'application/xml',
                'swf' => 'application/x-shockwave-flash',
                'flv' => 'video/x-flv',
    
                // images
                'png' => 'image/png',
                'jpe' => 'image/jpeg',
                'jpeg' => 'image/jpeg',
                'jpg' => 'image/jpeg',
                'gif' => 'image/gif',
                'bmp' => 'image/bmp',
                'ico' => 'image/vnd.microsoft.icon',
                'tiff' => 'image/tiff',
                'tif' => 'image/tiff',
                'svg' => 'image/svg+xml',
                'svgz' => 'image/svg+xml',
    
                // archives
                'zip' => 'application/zip',
                'rar' => 'application/x-rar-compressed',
                'exe' => 'application/x-msdownload',
                'msi' => 'application/x-msdownload',
                'cab' => 'application/vnd.ms-cab-compressed',
    
                // audio/video
                'mp3' => 'audio/mpeg',
                'qt' => 'video/quicktime',
                'mov' => 'video/quicktime',
    
                // adobe
                'pdf' => 'application/pdf',
                'psd' => 'image/vnd.adobe.photoshop',
                'ai' => 'application/postscript',
                'eps' => 'application/postscript',
                'ps' => 'application/postscript',
    
                // ms office
                'doc' => 'application/msword',
                'rtf' => 'application/rtf',
                'xls' => 'application/vnd.ms-excel',
                'ppt' => 'application/vnd.ms-powerpoint',
    
                // open office
                'odt' => 'application/vnd.oasis.opendocument.text',
                'ods' => 'application/vnd.oasis.opendocument.spreadsheet',

                'woff'=> 'application/font-woff',
                'woff2'=> 'application/font-woff',
                'eot'=> 'application/vnd.ms-fontobject',
                
            ];
            $fp = explode('.',$file);
            $ext = strtolower(array_pop($fp));
 
            if (array_key_exists($ext, $mime_types)){
                TualoApplication::contenttype( $mime_types[$ext] );
            }else{
                TualoApplication::contenttype( mime_content_type($file) );
            }
            
        }

        header("Last-Modified: ".gmdate("D, d M Y H:i:s", $last_modified_time)." GMT"); 
        header("Etag: $etag");  
        
        if (
            (isset($_SERVER['HTTP_IF_MODIFIED_SINCE']) && ( strtotime($_SERVER['HTTP_IF_MODIFIED_SINCE']) == $last_modified_time ))
            || 
            (isset($_SERVER['HTTP_IF_NONE_MATCH']) && ( trim($_SERVER['HTTP_IF_NONE_MATCH']) == $etag ) )
        ) { 
            header("HTTP/1.1 304 Not Modified"); 
            exit; 
        } 
        
        return TualoApplication::body( file_get_contents( $file ) );
    }
    

    

    /**
     * Run all Middlewares
     * 
     * @return $this
     */
    public static function run(){
        self::timing('run');
        
        $classes = get_declared_classes();
        
        foreach($classes as $cls){
            $class = new \ReflectionClass($cls);
            if ( $class->implementsInterface('Tualo\Office\Basic\IMiddleware') ) {
                $cls::register();
            }
        }

        
        usort(self::$middlewares,     "self::compare_position");

        foreach(self::$middlewares as $middleware){
            if (self::$runmiddlewares===true) self::callMiddlewareIntern($middleware);
            self::timing($middleware['key']);
        }
        if (self::$runmiddlewares===true){
            self::end();
        }
        
    }

    public static function runMiddleware($name){
        foreach(self::$middlewares as $middleware){
            if($middleware['key']==$name){
                self::callMiddlewareIntern($middleware);
            }
        }
    }

    private static function callMiddlewareIntern($middleware){
        $components = self::components(true);
        $run=self::canRunMiddleWare($middleware);
        if(isset(self::$called_middlewares[$middleware['key']])) $run =false;
        // if(!in_array($middleware['cmp'],$components)) $run=false;
        // echo (($run)?'OK':'Nope')." ".$middleware['key']."\n";

        if ($run===true){
            $parsed_url = parse_url($_SERVER['REQUEST_URI']);//Parse Uri
            if(isset($_SERVER['REDIRECT_URL'])) $parsed_url = parse_url($_SERVER['REDIRECT_URL']);
            if(isset($parsed_url['path'])){
                $path = $parsed_url['path'];
            }else{
                $path = '/';
            }
                
            self::$called_middlewares[$middleware['key']]=1;
            try{
                call_user_func_array($middleware['function'],[$path]);
                if (self::$output===true){ }
            }catch(\Exception $e){
                self::$result['errors'][]=$e->getMessage();
            }
        }

    }

    private static $called_middlewares=[];
    private static function canRunMiddleWare($middleware){
        $headers = getallheaders();
        $result = true;
        if(isset(self::$called_middlewares[$middleware['key']])) return false;
        if (isset($middleware['options'])){
            if (isset($middleware['options']['headers'])){
                if (isset($middleware['options']['headers']['X-Requested-With'])  && (isset($headers['X-Requested-With'])) ){
                    $result = $result && ($headers['X-Requested-With']==$middleware['options']['headers']['X-Requested-With']);
                }
                if (isset($middleware['options']['headers']['Accept']) && (isset($headers['Accept'])) ){
                    $result = self::matchesAccept(self::splitAcceptHeader($headers['Accept']), self::splitAcceptHeader($middleware['options']['headers']['Accept']));
                }
            }
        }

        return $result;
    }

    private static function matchesAccept($request_accepts,$allowed){
        foreach($allowed as $allowed_key=>$allowed_subs){
            if (isset($request_accepts[$allowed_key])){
                if (in_array('*',$allowed_subs)) return true;
                foreach($allowed_subs as $subs){
                    if (in_array($subs,$request_accepts[$allowed_key])){
                        return true;
                    }
                }
            }
            if (isset($request_accepts['*'])){
                if (in_array('*',$allowed_subs)) return true;
                foreach($allowed_subs as $subs){
                    if (in_array($subs,$request_accepts['*'])){
                        return true;
                    }
                }
            }
        }
        return false;
    }

    private static function splitAcceptHeader($txt){
        $accepts = explode(',',$txt);
        $hash = array();
        foreach($accepts as $k){
            $p = explode(';',$k);
            $x = explode('/',$p[0]);
            if (count($x)==2){
                if (!isset($hash[$x[0]])){
                    $hash[$x[0]]=array();
                }
                $hash[$x[0]][]=$x[1];
            }
        }
        return $hash;
    }
    public static function appendTiming($val){
        self::$json_timing=$val;
    }
    public static function stopbuffering(){
        if (ob_get_length()) ob_end_clean();
        self::$output=false;
    }

    /**
     * read or set the contenttype
     */
    public static function contenttype($value=''){
        if ($value!=''){
            self::$return_contenttype=$value;
        }
        return self::$return_contenttype;
    }

    /**
     * stopps all remaining middlewares
     */
    public static function stopmiddlewares(){
        self::$runmiddlewares = false;
    }

    /**
     * output 
     */
    public static function end(){
        self::timing('end');
        //echo json_encode(self::$timing_result,JSON_PRETTY_PRINT); exit();
        //file_put_contents(self::get('basePath').'timing.txt',json_encode(self::$timing_result,JSON_PRETTY_PRINT));
        try{

            if (self::$output===true){
                
                if (self::contenttype()=='application/json'){

                    
                    
                    $data = '{}';
                    if (self::$returnField!=''){
                        $data =  json_encode(self::$result[self::$returnField],JSON_PRETTY_PRINT);
                    }else{
                        if (self::$json_timing) self::$result['__timing'] = self::$timing_result;
                        if (self::$appendDebug) self::$result['__debug'] = self::$debug_result;
                        $data =   json_encode(self::$result,JSON_PRETTY_PRINT);
                    }
 
                    header('Content-Type: '.self::contenttype());
                    echo $data;
                }else{
                    header('Content-Type: '.self::contenttype());
                    echo  self::$resultbody;
                }
            }else{
            }
        }catch(\Exception $e){
            echo $e->getMessage();
        }
    }

}