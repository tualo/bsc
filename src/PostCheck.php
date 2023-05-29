<?php
namespace Tualo\Office\Basic;

use Tualo\Office\Basic\TualoApplication as App;

class PostCheck implements IPostCheck{

    public static function loopClients(array $config,string $clientName=null){

          $_SERVER['REQUEST_URI']='';
          $_SERVER['REQUEST_METHOD']='none';
          App::run();
          $session = App::get('session');
          $sessiondb = $session->db;
          $dbs = $sessiondb->direct('select username dbuser, password dbpass, id dbname, host dbhost, port dbport from macc_clients ');
          foreach($dbs as $db){
            if (!is_null($clientName) && $clientName!=$db['dbname']){ 
                continue;
            }else{
                App::set('clientDB',$session->newDBByRow($db));
                self::formatPrintLn(['blue'],'checks on '.$db['dbname'].':  ');
                $classes = get_declared_classes();
                foreach($classes as $cls){
                    $class = new \ReflectionClass($cls);
                    if ( $class->implementsInterface('Tualo\Office\Basic\IPostCheck') ) {
                        $cls::test($config);
                    }
                }
            }
          }
    }

    public static function test(array $config){
    }

    public static function formatPrint(array $format=[],string $text = '') {
    $codes=[
      'bold'=>1,
      'italic'=>3, 'underline'=>4, 'strikethrough'=>9,
      'black'=>30, 'red'=>31, 'green'=>32, 'yellow'=>33,'blue'=>34, 'magenta'=>35, 'cyan'=>36, 'white'=>37,
      'blackbg'=>40, 'redbg'=>41, 'greenbg'=>42, 'yellowbg'=>44,'bluebg'=>44, 'magentabg'=>45, 'cyanbg'=>46, 'lightgreybg'=>47
    ];
    $formatMap = array_map(function ($v) use ($codes) { return $codes[$v]; }, $format);
    echo "\e[".implode(';',$formatMap).'m'.$text."\e[0m";
  }
  public static function formatPrintLn(array $format=[], string $text='') {
    echo self::formatPrint($format, $text).PHP_EOL;
  }

  public static function tableCheck(array $tables)
  {
    $clientdb = App::get('clientDB');
    foreach( $tables as $tablename => $tabledef){
        $columns = [];
        try{ 
            $columns = $clientdb->direct('explain `'.$tablename.'`'); 
            $columnnames = array_map(function($v){ return $v['field']; },$columns);
            self::formatPrintLn(['green'],"\ttest table".$clientdb->dbname.'.'.$tablename.' exists  ');
        }catch(\Exception $e){ 
            self::formatPrintLn(['red'],"\ttest table ".$clientdb->dbname.'.'.$tablename.' failed  ');
            continue; 
        }
    }

  }

  public static function procedureCheck(array $procedures){
    $clientdb = App::get('clientDB');
    foreach( $procedures as $procedurename => $procedure_md5){
        $columns = [];
        try{ 
            $columns = $clientdb->singleValue('select md5(routine_definition) md5 from information_schema.routines WHERE routine_name like {procedurename}',['procedurename'=>$procedurename],'md5'); 
            if ($columns===false){
                self::formatPrintLn(['red'],"\ttest stored procedure ".$clientdb->dbname.'.'.$procedurename.' does not exist');
            }else if ($columns==$procedure_md5){
                self::formatPrintLn(['green'],"\ttest stored procedure ".$clientdb->dbname.'.'.$procedurename.' done  ');
            }else{
                self::formatPrintLn(['yellow'],"\ttest stored procedure ".$clientdb->dbname.'.'.$procedurename.' other version ');
            }

        }catch(\Exception $e){ 
            self::formatPrintLn(['red'],"\t".$e->getMessage());
            continue; 
        }
    }
  }
}