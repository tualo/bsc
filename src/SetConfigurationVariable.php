<?php
namespace Tualo\Office\Basic\Commandline;
use Garden\Cli\Cli;
use Garden\Cli\Args;
use phpseclib3\Math\BigInteger\Engines\PHP;
use Tualo\Office\Basic\ICommandline;
use Tualo\Office\ExtJSCompiler\Helper;
use Tualo\Office\Basic\TualoApplication as App;
use Tualo\Office\Basic\PostCheck;

class SetConfigurationVariable implements ICommandline{

    public static function write_ini_file($file, $array = []) {

        $config_default=[];
        $config_section=[];
        foreach($array as $k=>$v){
            if ($k=='client.mysql.connect_timeout') continue;
            if (is_array($v)) $config_section[$k]=$v;
            else $config_default[$k]=$v;
        }
        ksort($config_default);
        ksort($config_section);
        
        $array = array_merge($config_default,$config_section);

        // check first argument is string
        if (!is_string($file)) {
            throw new \InvalidArgumentException('Function argument 1 must be a string.');
        }

        // check second argument is array
        if (!is_array($array)) {
            throw new \InvalidArgumentException('Function argument 2 must be an array.');
        }

        // process array
        $data = array();
        foreach ($array as $key => $val) {
            if (is_array($val)) {
                $data[] = null;
                $data[] = "[$key]";
                foreach ($val as $skey => $sval) {
                    if (is_array($sval)) {
                        foreach ($sval as $_skey => $_sval) {
                            if (is_numeric($_skey)) {
                                $data[] = $skey.'[] = '.(is_numeric($_sval) ? $_sval : (ctype_upper($_sval) ? $_sval : '"'.$_sval.'"'));
                            } else {
                                $data[] = $skey.'['.$_skey.'] = '.(is_numeric($_sval) ? $_sval : (ctype_upper($_sval) ? $_sval : '"'.$_sval.'"'));
                            }
                        }
                    } else {
                        $data[] = $skey.' = '.(is_numeric($sval) ? $sval : (ctype_upper($sval) ? $sval : '"'.$sval.'"'));
                    }
                }
            } else {
                $data[] = $key.' = '.(is_numeric($val) ? $val : (ctype_upper($val) ? $val : '"'.$val.'"'));
            }
            // empty line
            // 
        }

        // open file pointer, init flock options
        $fp = fopen($file, 'w');
        $retries = 0;
        $max_retries = 100;

        if (!$fp) {
            return false;
        }

        // loop until get lock, or reach max retries
        do {
            if ($retries > 0) {
                usleep(rand(1, 5000));
            }
            $retries += 1;
        } while (!flock($fp, LOCK_EX) && $retries <= $max_retries);

        // couldn't get the lock
        if ($retries == $max_retries) {
            return false;
        }

        // got lock, write data
        fwrite($fp, implode(PHP_EOL, $data).PHP_EOL);

        // release lock
        flock($fp, LOCK_UN);
        fclose($fp);

        return true;
    }

    public static function getCommandName():string { return 'configuration';}

    public static function setup(Cli $cli){
        $cli->command(self::getCommandName())
            ->description('configuration variables')
            ->opt('section', 'the setion name', false, 'string')
            ->opt('key', 'key name', true, 'string')
            ->opt('value', 'value', true, 'string');

    }

   

    public static function run(Args $args){
        $config = App::get('configuration');
        $section = $args->getOpt('section',false);
        if ($section!==false){
            if (!isset($config[$section])) $config[$section]=[];
            $config[$section][$args->getOpt('key')]=$args->getOpt('value');
        }else{
            $config[$args->getOpt('key')]=$args->getOpt('value');
        }
        self::write_ini_file(App::get('configurationFile'),$config);
        PostCheck::formatPrintLn(['green'],"done".PHP_EOL);

    }
}
