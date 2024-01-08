<?php
namespace Tualo\Office\Basic;
use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;
use RegexIterator;
use Tualo\Office\Basic\TualoApplication;

class Version {
    public static function rsearch($folder, $regPattern) {
        $dir = new RecursiveDirectoryIterator($folder);
        $ite = new RecursiveIteratorIterator($dir);
        $files = new RegexIterator($ite, $regPattern, RegexIterator::GET_MATCH);
        $fileList = array();
        foreach($files as $file) {
            $fileList = array_merge($fileList, $file);
        }
        return $fileList;
    }

    public static function versionMD5($forced=false){
        if (
            file_exists(TualoApplication::get('basePath').'/.ht_version')
        ){
            if (($forced) && (filemtime(TualoApplication::get('basePath').'/.ht_version')<time()-60*60*24*1)){
                unlink(TualoApplication::get('basePath').'/.ht_version');
                return Version::versionMD5();
            }
            return md5_file(TualoApplication::get('basePath').'/.ht_version');
        }
        $result = Version::rsearch(TualoApplication::get('basePath').'/vendor/', '/.*/');
        $result = array_merge(Version::rsearch(TualoApplication::get('basePath').'/configuration/', '/.*/'),$result);
        $md5s = [];
        foreach($result as $key=>$value){
            if (is_file($value)) $md5s[] = md5_file($value);
        }
        file_put_contents(TualoApplication::get('basePath').'/.ht_version',md5(implode('',$md5s)));
        return md5(implode('',$md5s));
    }
}