<?php

namespace Tualo\Office\Basic\BASIC;

class  Database_basic{
    public  $version;
    public  $state = false;

    public  $dbname='';
    public  $dbuser='';
    public  $dbhost='';



    /**
     * Konstruktor des Datenbank-Objektes
     * @param {String} Datenbankbenutzer
     * @param {String} Datenbankbenutzer-Passwort
     * @param {String} Datenbank-Name
     * @param {String} Datenbankhost, IP oder Name
     * @return {database_basic}
     */
    function __construct($user,$pass,$db,$host,$port=3306,$ssl_key='',$ssl_cert='',$ssl_ca='') {
        $this->dbname=$db;
        $this->dbuser=$user;
        $this->dbhost=$host;
    }

    public $dbTypes=false;

    function useDBTypes($val){
      $this->dbTypes=$val;
    }
    /**
     * Gibt die letzte Fehlermeldung, des Datenbanksystems, als Text zur�ck
     * @return {String}
     */
    public function GetError() {
        return "";
    }

    /**
     * Gibt die letzte Fehlermeldung, des Datenbanksystems, als Fehlernummer zur�ck
     * @return {Integer}
     */
    public function GetErrorNum() {
        return 0;
    }


    public function direct($statement,$hash=array(),$key='',$byName=false) {
      $res = array();
      $rs = $this->execute_with_hash($statement,$hash);
      if (is_object($rs)&& (method_exists($rs,'toArray')) ){
        $rs->useDBTypes($this->dbTypes);
        $utf8=false;$start=0;$limit=999999999;
        if (is_array($key)){
          
          $res = $rs->toHash($key, $utf8, $start, $limit, $byName);
        }else{
          $res = $rs->toArray($key, $utf8, $start, $limit, $byName);
        }
        $rs->unload();
        return $res;
      }else{
        return $rs;
      }
    }

    public function directMap($statement,$hash=array(),$key='',$value='') {
      $res = [];
      $vals = $this->direct($statement,$hash,$key);
      foreach($vals as $key=>$v){
        $res[$key]=$v[$value];
      }
      return $res;
    }


    public function directArray($statement,$hash=array(),$value='') {
      $res = [];
      $vals = $this->direct($statement,$hash);
      //print_r($vals );
      foreach($vals as $key=>$v){
        $res[]=$v[$value];
      }
      return $res;
    }

    public function directHash($statement,$hash=array(),$key='') {
      $res = array();
      $rs = $this->execute_with_hash($statement,$hash);
      $utf8=false;$start=0;$limit=999999999;$byName=false;
      if (is_object($rs)){
        $res = $rs->toHash($key, $utf8, $start, $limit, $byName);
        $rs->unload();
        return $res;
      }else{
        return $rs;
      }
    }

    public function directSingleHash($statement,$hash=[]) {
      $row = $this->singleRow($statement,$hash,'');
      if ($row===false) return false;
      $res = [];
      foreach($row as $key=>$v){
        $res[$key]=$v;
      }
      return $res;
    }

    public function singleRow($statement,$hash=array(),$key=''){
      $rs = $this->execute_with_hash($statement,$hash);
      $res = $rs->toArray($key);
      $rs->unload();
  		if (count($res)==1){
  			return $res[0];
  		}
  		return false;
  	}

    public function singleValue($statement,$hash=array(),$key=''){
      $rs = $this->singleRow($statement,$hash,'');
      if ($rs!==false){
        if (isset($rs[$key])){
          return $rs[$key];
        }
      }
  		return false;
  	}

    /**
     * F�hrt ein SQL-Statement aus und gibt bei SELECT Statements ein Recordset-Objekt zur�ck.
     * Bei INSERT, UPDATE, DROP, CREATE oder ALTER Statements gibt es true bei Erfolg zur�ck.
     * @param {String} SQL Statement
     * @return {recordset_basic|Boolean}
     */
    public function execute($statement) {
        return false;
    }


    /**
     * F�hrt ein SQL-Statement mit Parametern aus und gibt bei SELECT Statements ein Recordset-Objekt zur�ck.
     * Bei INSERT, UPDATE, DROP, CREATE oder ALTER Statements gibt es true bei Erfolg zur�ck.
     * Das Array Params muss genau so viele Elemente enthalten, wie "?" im Statement platziert sind.
     *
     * @param {String} $statement
     * @param {String[]} $params
     * @return {recordset_basic|Boolean}
     */
    public function execute_with_params($statement,$params) {
        return false;
    }


    /**
     * Setzt bzw. �ndert das Commit-Status der Datenbank. $bool_state true (Standard) bedeutet,
     * dass jedes Statement sofort in die DB geschrieben wird. Ist $bool_state false m�ssen die
     * Anweisungen mit commit() geschrieben werden. Nach Beendigung des PHP-Skriptes verfallen
     * nicht geschriebene Anweisungen (automatischen Rollback).
     * Konnte der Status ge�ndert werden gibt die Funktion true zur�ck, andernfalls false.
     *
     * @param {Boolean} $bool_state
     * @return {Boolean}
     */
    public function autocommit($bool_state) {
        return false;
    }

    /**
     * Schreibt bei autocommit false, Anweisungen in die Datenbank.
     * Gibt bei Erfolg true zur�ck.
     *
     * @return {Boolean}
     */
    public function commit() {
        return false;
    }

    /**
     * Gibt wahr zurück, falls die Tabelle gesperrt ist.
     * 
     * @param {String} $table_name
     * @return {Boolean}
     */
    public function isLocked($table_name){
      return false;
    }

    /**
     * Wartet max. `$iterations` Durchläufe auf das entsperren der 
     * der Tabelle, sonst wird eine exception ausgelöst
     * 
     * @param {String} $table_name
     * @param {Integer} $iterations, default 5
     * @param {Integer} $ms, dafault 500
     * @return {Boolean}
     */
    public function waitForUnlock($table_name,$iterations = 10,$ms=1500){
      $count = 0;
      while ($this->isLocked($table_name)&&($count<$iterations)){
        usleep($ms);
        $count++;
      }
      if (defined('__THROW_ERROR_ON_WAIT_TIMEOUT__')){
        if(__THROW_ERROR_ON_WAIT_TIMEOUT__==1){
          if ($count>=$iterations){
            throw new \Exception("Wait to long for unlocking table `".$table_name."`");
          }
        }
      }
      return true;
    }

    /**
     * Rollt alle nicht geschriebenen Anweisungen zur�ck.
     * Gibt bei Erfolg true zur�ck.
     *
     * @return {Boolean}
     */
    public function rollback() {
        return false;
    }

    /**
     * Gibt den aktuellen Commit-Status zur�ck.
     *
     * @return {Boolean}
     */
    public function commitstate() {
        return false;
    }

    /**
     * Gibt alle Tabellennamen des angemeldeten Schemas zur�ck.
     *
     * @return {String[]}
     */
    public function getTables(){
        return array();
    }

    /**
     * Gibt ein Array aller Spalten der Tabelle $table_name zur�ck.
     * Jedes Element des Arrays hat folgenden Aufbau:
     *
<pre><code>
$element = array(

        'name' => COLUMNAME,
        'type' => TYPE,
        'length' => LENGTH,
        'precision' => PRECISION,
        'scale' => SCALE,
        'key' => KEY,
        'nullable' => NULLABLE

);
</code></pre>
     * COLUMNAME {String} Spaltenname
     * TYPE {String} [integer,fixed,float,date,time,datetime,string]
     * LENGTH {Integer} maximale L�nge der Spalte
     * PRECISION {Integer} Genauigkeit der Spalte, bei float und fixed
     * SCALE {Integer} Anzahl der m�gllichen Nachkommastellen
     * KEY {Boolean} Wahr wenn die Spalte eine Schl�sselspalte ist
     * NULLABLE {Boolean} Wahr wenn die Spalte Null-Werte entahlen kann
     *
     * @param {String} $table_name
     * @return {String[]}
     */
    public function getColumns($table_name){
        return array();
    }

    /**
     * Findet einen Eintrag in einem Array, wenn dieser nicht vorhanden ist
     * wird $default zur�ck gegeben.
     *
     * @param {String[]} $array
     * @param {String} $value
     * @param {String} $default
     * @return {String}
     */
    private function find_in($array,$value,$default=''){
        return $default;
    }


    public function explode_by_delimiter($sql){
      $all_queries = [];
      preg_match_all("/delimiter\s*(?P<delimiter>(\/\/|;))/i", $sql, $matches);
      if (count($matches)>0){
          
          foreach($matches[0] as $index=>$delimiters){
              if ($index==0){
                  $startat = strpos($sql,$delimiters)+strlen($delimiters);
                  $sql = substr($sql,$startat);
              }
              
              if ($index +1 == count($matches[0])){
                  
                $all_queries = array_merge($all_queries,explode($matches['delimiter'][$index],$sql));

              }else{
                  $all_queries = array_merge($all_queries,explode($matches['delimiter'][$index],explode($matches[0][$index+1],$sql)[0]));
                  $startat = strpos($sql,$matches[0][$index+1])+strlen($matches[0][$index+1]);
                  $sql = substr($sql,$startat);
              }
              
          } 
      }else{
          $all_queries = explode(';', $sql);
      }

      return $all_queries;
    }

    public function split_delimiter($sql,$current_delimiter=';'){
      $sqls = array();
      $in_single_qoute=false;
      $in_double_qoute=false;

      $old_position=0;
      $current_position=0;
      $length =strlen($sql);
      $delimit_length =strlen($current_delimiter);
      while($current_position<$length){
        if ($sql[$current_position]=='\''){
          if ($in_single_qoute){
            $in_single_qoute=false;
          }else{
            $in_single_qoute=true;
          }
        }else if ($sql[$current_position]=='"'){
          if ($in_double_qoute){
            $in_double_qoute=false;
          }else{
            $in_double_qoute=true;
          }
        }else{
          if (!$in_double_qoute && !$in_single_qoute){
            //echo $sql[$current_position]."\n";
            if (substr($sql,$current_position,$delimit_length)==$current_delimiter){
              //echo "**$old_position*".substr($sql,$old_position,$current_position-$old_position)."*$current_position**\n\n";
              $sqls[]=substr($sql,$old_position,$current_position-$old_position);
              $old_position = $current_position+$delimit_length;
            }
            //'DELI MITE R $$'
            if ($current_position>=10){
              if (substr($sql,$current_position-10,10)=='DELIMITER '){
                //echo "found delimiter at ".$current_position."\n";
                $delindex = $current_position;
                for($delindex=$current_position;$delindex<$current_position+10;$delindex++){
                  if (
                    ($sql[$delindex]==' ')||
                    ($sql[$delindex]=="\n")||
                    ($sql[$delindex]=="\t")
                  ){
                    $current_delimiter=substr($sql,$current_position,$delindex-$current_position);
                    $delimit_length =strlen($current_delimiter);
                    $current_position=$delindex;
                    $old_position=$current_position;
                    //echo "new delimiter is ".$current_delimiter."\n";
                    break;
                  }
                }

              }
            }
          }
        }
        $current_position++;
      }
      $sqls[]=substr($sql,$old_position,$current_position-$old_position);
      $temp = $sqls;
      $sqls = array();
      foreach($temp as $s){
        if (trim(chop($s))=='DELIMITER'){

        }else if (trim(chop($s))==''){

        }else{
          $sqls[] = $s;
        }
      }
      return ($sqls);
    }
}
