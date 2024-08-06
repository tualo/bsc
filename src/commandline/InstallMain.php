<?php
namespace Tualo\Office\BSC\Commandline;
use Tualo\Office\Basic\ICommandline;
use Tualo\Office\Basic\CommandLineInstallSQL;

class InstallMain extends CommandLineInstallSessionSQL  implements ICommandline{
    public static function getDir():string {   return dirname(__DIR__,1); }
    public static $shortName  = 'bsc-main';
    public static $files = [
        'install/doublequote' => 'setup doublequote ',
        'install/session_funcs' => 'setup session_funcs ',
        'install/session_views' => 'setup session_views ',
        
    ];
}


class InstallMainDS extends CommandLineInstallSQL  implements ICommandline{
    public static function getDir():string {   return dirname(__DIR__,1); }
    public static $shortName  = 'bsc-main-ds';
    public static $files = [
        'install/doublequote' => 'setup doublequote ',
    ];
    public static function exitOnError():bool {  
        return true;
    }
    public static function getFiles():array {  
        $res = json_decode(file_get_contents(static::getDir().'/sql/install/files.json'),true);
        $list = [];
        foreach($res as $row){
            $list["install/".str_replace('.sql','',$row['file'])] = $row['text'];
        }
        return $list;
        
    }
    
}