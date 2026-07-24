<?php

namespace Tualo\Office\Basic\BASIC;

use Tualo\Office\Basic\BASIC\RecordsetBasic;

class  Database_basic
{
  public  $state = false;
  public  $last_sql = '';
  public  $dbname = '';
  public  $dbuser = '';
  public  $dbhost = '';



  /**
   * Konstruktor des Datenbank-Objektes
   * @param {String} Datenbankbenutzer
   * @param {String} Datenbankbenutzer-Passwort
   * @param {String} Datenbank-Name
   * @param {String} Datenbankhost, IP oder Name
   * @return {database_basic}
   */
  function __construct(string $user, string $pass, string $db, string $host, int $port = 3306, ?string $ssl_key = null, ?string $ssl_cert = null, ?string $ssl_ca = null)
  {
    $this->dbname = $db;
    $this->dbuser = $user;
    $this->dbhost = $host;
  }

  public $dbTypes = true;
  private $_tinyIntAsBoolean = false;

  public function useDBTypes(bool $val): void
  {
    $this->dbTypes = $val;
  }
  /**
   * Gibt die letzte Fehlermeldung, des Datenbanksystems, als Text zur�ck
   * @return {String}
   */
  public function GetError()
  {
    return "";
  }

  /**
   * Gibt die letzte Fehlermeldung, des Datenbanksystems, als Fehlernummer zur�ck
   * @return {Integer}
   */
  public function GetErrorNum()
  {
    return 0;
  }
  public function getLastSQL()
  {
    return $this->last_sql;
  }

  public function tinyIntAsBoolean(bool $val): bool
  {
    $this->_tinyIntAsBoolean = $val;
    return $this->_tinyIntAsBoolean;
  }



  public function direct(string $statement, array $hash = [], string $key = '', bool $byName = false): array | bool
  {
    $res = array();
    $rs = $this->execute_with_hash($statement, $hash);
    if (is_object($rs) && (method_exists($rs, 'toArray'))) {
      $rs->useDBTypes($this->dbTypes);
      $rs->tinyIntAsBoolean($this->_tinyIntAsBoolean);
      $utf8 = false;
      $start = 0;
      $limit = 999999999;
      if (is_array($key)) {

        $res = $rs->toHash($key, $utf8, $start, $limit, $byName);
      } else {
        $res = $rs->toArray($key, $utf8, $start, $limit, $byName);
      }
      $rs->unload();
      return $res;
    } else {
      return $rs;
    }
  }

  public function directMap(string $statement, array $hash = [], string $key = '', string $value = ''): array
  {
    $res = [];
    $vals = $this->direct($statement, $hash, $key);
    foreach ($vals as $key => $v) {
      $res[$key] = $v[$value];
    }
    return $res;
  }


  public function directArray(string $statement, array $hash = [], string $value = ''): array
  {
    $res = [];
    $vals = $this->direct($statement, $hash);
    //print_r($vals );
    foreach ($vals as $key => $v) {
      $res[] = $v[$value];
    }
    return $res;
  }




  public function directHash(string $statement, array $hash = [], string $key = ''): array|bool
  {
    $res = array();
    $rs = $this->execute_with_hash($statement, $hash);
    $utf8 = false;
    $start = 0;
    $limit = 999999999;
    $byName = false;
    if (is_object($rs)) {
      $res = $rs->toHash($key, $utf8, $start, $limit, $byName);
      $rs->unload();
      return $res;
    } else {
      return $rs;
    }
  }

  public function directSingleHash(string $statement, array $hash = []): array | bool
  {
    $row = $this->singleRow($statement, $hash, '');
    if ($row === false) return false;
    $res = [];
    foreach ($row as $key => $v) {
      $res[$key] = $v;
    }
    return $res;
  }

  public function replace_hash($sql, $hash)
  {

    $matches = array();
    $i = preg_match_all('/\{(?P<name>(\w+)(.\w+)*)\}/', $sql, $matches);
    if ($i === false) {
    } else {
      if (isset($matches['name'])) {
        foreach ($matches['name'] as $p) {
          $func = '';
          $field = '';
          if (strpos($p, ':') !== false) {
            $parts = explode(':', $p);
            $func = $parts[1];
            $field = $parts[0];
          }
          if ($func == 'array') {
            if (isset($hash[$field])) {
              $v = array();
              foreach ($hash[$field] as $x) {
                $v[] = $this->escape_string($x);
              }
              $sql = str_replace('{' . $p . '}', '\'' . implode('\',\'', $v) . '\'', $sql); // ' \''.$this->escape_string($hash[$p]).'\' ' : '(null)', $sql);
            } else {
              $sql = str_replace('{' . $p . '}', 'null', $sql);
            }
          } else if ($func == 'json') {
            $sql = str_replace('{' . $p . '}', isset($hash[$field]) ? ' \'' . ($hash[$field]) . '\' ' : 'null', $sql);
          } else {
            $sql = str_replace('{' . $p . '}', isset($hash[$p]) ? ' \'' . $this->escape_string($hash[$p]) . '\' ' : 'null', $sql);
          }
        }
      }
    }
    return $sql;
  }

  public function execute_with_hash(string $sql_statement, array $hash, $decode = false): RecordsetBasic | bool
  {

    return $this->execute($this->replace_hash($sql_statement, $hash));
  }

  public function escape_string(string $str): string
  {
    return $str;
  }

  public function singleRow(string $statement, array $hash = [], string $key = ''): array | bool
  {
    $rs = $this->execute_with_hash($statement, $hash);
    $res = $rs->toArray($key);
    $rs->unload();
    if (count($res) == 1) {
      return $res[0];
    }
    return false;
  }

  public function singleValue(string $statement, array $hash = [], string $key = ''): mixed
  {
    $rs = $this->singleRow($statement, $hash, '');
    if ($rs !== false) {
      if (isset($rs[$key])) {
        return $rs[$key];
      }
    }
    return false;
  }

  /**
   * F�hrt ein SQL-Statement aus und gibt bei SELECT Statements ein Recordset-Objekt zur�ck.
   * Bei INSERT, UPDATE, DROP, CREATE oder ALTER Statements gibt es true bei Erfolg zur�ck.
   * @param {String} SQL Statement
   * @return {IRecordset|Boolean}
   */
  public function execute(string $statement): RecordsetBasic | bool
  {
    return false;
  }


  /**
   * F�hrt ein SQL-Statement mit Parametern aus und gibt bei SELECT Statements ein Recordset-Objekt zur�ck.
   * Bei INSERT, UPDATE, DROP, CREATE oder ALTER Statements gibt es true bei Erfolg zur�ck.
   * Das Array Params muss genau so viele Elemente enthalten, wie "?" im Statement platziert sind.
   *
   * @param {String} $statement
   * @param {String[]} $params
   * @return {IRecordset|Boolean}
   */
  public function execute_with_params(string $statement, array $params): RecordsetBasic | bool
  {
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
  public function autocommit(bool $bool_state): bool
  {
    return false;
  }

  /**
   * Schreibt bei autocommit false, Anweisungen in die Datenbank.
   * Gibt bei Erfolg true zur�ck.
   *
   * @return {Boolean}
   */
  public function commit(): bool
  {
    return false;
  }

  /**
   * Gibt wahr zurück, falls die Tabelle gesperrt ist.
   * 
   * @param {String} $table_name
   * @return {Boolean}
   */
  public function isLocked(string $table_name): bool
  {
    return false;
  }

  /**
   * Rollt alle nicht geschriebenen Anweisungen zur�ck.
   * Gibt bei Erfolg true zur�ck.
   *
   * @return {Boolean}
   */
  public function rollback(): bool
  {
    return false;
  }

  /**
   * Gibt den aktuellen Commit-Status zur�ck.
   *
   * @return {Boolean}
   */
  public function commitstate(): bool
  {
    return false;
  }

  /**
   * Gibt alle Tabellennamen des angemeldeten Schemas zur�ck.
   *
   * @return {String[]}
   */
  public function getTables(): array
  {
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
  public function getColumns(string $table_name): array
  {
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
  private function find_in($array, $value, $default = '')
  {
    return $default;
  }


  public function explode_by_delimiter(string $sql): array
  {
    $all_queries = [];
    preg_match_all("/delimiter\s*(?P<delimiter>(\/\/|;))/i", $sql, $matches);
    if (count($matches) > 0) {

      foreach ($matches[0] as $index => $delimiters) {
        if ($index == 0) {
          $startat = strpos($sql, $delimiters) + strlen($delimiters);
          $sql = substr($sql, $startat);
        }

        if ($index + 1 == count($matches[0])) {

          $all_queries = array_merge($all_queries, explode($matches['delimiter'][$index], $sql));
        } else {
          $all_queries = array_merge($all_queries, explode($matches['delimiter'][$index], explode($matches[0][$index + 1], $sql)[0]));
          $startat = strpos($sql, $matches[0][$index + 1]) + strlen($matches[0][$index + 1]);
          $sql = substr($sql, $startat);
        }
      }
    } else {
      $all_queries = explode(';', $sql);
    }

    return $all_queries;
  }

  public function split_delimiter(string $sql, string $current_delimiter = ';'): array
  {
    $sqls = array();
    $in_single_qoute = false;
    $in_double_qoute = false;

    $old_position = 0;
    $current_position = 0;
    $length = strlen($sql);
    $delimit_length = strlen($current_delimiter);
    while ($current_position < $length) {
      if ($sql[$current_position] == '\'') {
        if ($in_single_qoute) {
          $in_single_qoute = false;
        } else {
          $in_single_qoute = true;
        }
      } else if ($sql[$current_position] == '"') {
        if ($in_double_qoute) {
          $in_double_qoute = false;
        } else {
          $in_double_qoute = true;
        }
      } else {
        if (!$in_double_qoute && !$in_single_qoute) {
          //echo $sql[$current_position]."\n";
          if (substr($sql, $current_position, $delimit_length) == $current_delimiter) {
            //echo "**$old_position*".substr($sql,$old_position,$current_position-$old_position)."*$current_position**\n\n";
            $sqls[] = substr($sql, $old_position, $current_position - $old_position);
            $old_position = $current_position + $delimit_length;
          }
          //'DELI MITE R $$'
          if ($current_position >= 10) {
            if (substr($sql, $current_position - 10, 10) == 'DELIMITER ') {
              //echo "found delimiter at ".$current_position."\n";
              $delindex = $current_position;
              for ($delindex = $current_position; $delindex < $current_position + 10; $delindex++) {
                if (
                  ($sql[$delindex] == ' ') ||
                  ($sql[$delindex] == "\n") ||
                  ($sql[$delindex] == "\t")
                ) {
                  $current_delimiter = substr($sql, $current_position, $delindex - $current_position);
                  $delimit_length = strlen($current_delimiter);
                  $current_position = $delindex;
                  $old_position = $current_position;
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
    $sqls[] = substr($sql, $old_position, $current_position - $old_position);
    $temp = $sqls;
    $sqls = array();
    foreach ($temp as $s) {
      if (trim(chop($s)) == 'DELIMITER') {
      } else if (trim(chop($s)) == '') {
      } else {
        $sqls[] = $s;
      }
    }
    return ($sqls);
  }
}
