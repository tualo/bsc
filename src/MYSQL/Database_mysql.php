<?php
namespace tualo\Office\Basic\MYSQL;

use tualo\Office\Basic\BASIC\Database_basic;
use tualo\Office\Basic\MYSQL\Recordset_mysql;

class Database_mysql extends Database_basic
{
    public $version;
    private $_version = '1.2.001';
    public $mysqli;
    private $commit_state = true;
    public $state = false;
    public $dbname = '';
    public $lastSQL = '';

    private $logfile = '';
    private $logcommands = array();
    private $warnings = array();
    public $last_sql = '';
    private $charset = '';

    private $user='';
    private $pass='';
    private $host='';
    private $port=3306;
    private $db='';

    
    public function __construct($user, $pass, $db, $host, $port = 3306,$ssl_key='',$ssl_cert='',$ssl_ca='')
    {
        parent::__construct($user, $pass, $db, $host);

        
        if (strpos($host, ':') !== false) {
            list($host, $port) = explode(':', $host);
        }

        $this->dbname = $db;
        syslog(LOG_CRIT,"$host $db $user");
        $this->mysqli = new \mysqli($host, ($user), ($pass), $db, $port);

        
        $this->mysqli = mysqli_init();
        $this->mysqli->options(MYSQLI_OPT_CONNECT_TIMEOUT, 10);

        if ( ($ssl_key!='') && ($ssl_cert!='') && ($ssl_ca!='') ){
            $this->mysqli->set_ssl($ssl_key,$ssl_cert,$ssl_ca,NULL,NULL);
        }
        
        if (!$this->mysqli->real_connect($host, ($user), ($pass), $db, $port)){
            throw new \Exception('Verbindungsfehler, die Datenbank kann nicht erreicht werden ('.$this->mysqli->connect_error.') '.$this->mysqli->connect_errno);
        }else{
            $this->mysqli->set_charset('latin1');
            $this->charset = 'latin1';
            if ($this->mysqli->connect_errno) {
                
            } else {
            $this->host=$host;
            $this->user=$user;
            $this->pass=$pass;
            $this->db=$db;
            $this->port=$port;
            }

            $this->autocommit($this->commit_state);
            $this->state = true;
        }

    }

    private function log($txt)
    {
        if (defined("__LOG_DB_COMMANDS__")){
            $fh = fopen(__LOG_DB_COMMANDS__, 'a+');
            fwrite($fh, implode("\t",array(date("Y-m-d H:i:s",time()), $this->get_callee(),str_replace("\t"," ",str_replace("\r"," ",str_replace("\n"," ",$txt)))."\n" ) ) );
            fclose($fh);
        }
    }

    private function get_callee()
    {
        $backtrace = debug_backtrace();
        $txt = array();
        foreach($backtrace as $trace){
            $txt[]=$trace['function'].'-'.$trace['file'].'('.$trace['line'].')';
        }
        return implode('>',$txt);
    }

    public function reconnect(){
      $this->mysqli->close();
      $this->mysqli = new \mysqli($this->host, ($this->user), ($this->pass), $this->db, $this->port);
    }

    public function __destruct()
    {
        //$this->mysqli->close();
    }

    public function close()
    {
      if ($this->state){
        $this->mysqli->close();
        $this->state=false;
      }
    }
    public function GetError()
    {
        return $this->mysqli->error;
    }

    public function GetErrorNum()
    {
        return $this->mysqli->errno;
    }

    
	

    private $check_start = 0;

    public function check_start()
    {
        $this->check_start = time();
    }

    public function check_stop($sql)
    {
        $check_stop = time();
        $diff = $check_stop - $this->check_start;
        if (defined(__QUERY_CHECK__)) {
            if (__QUERY_CHECK__ == '1') {
                $sql = str_replace("'", '*', $sql);
                if (strlen($sql) > 3900) {
                    $sql = substr($sql, 0, 3900);
                }
                $s = "insert into query_check (diff,anfrage) values ($diff,'$sql')";
                $this->db_ref->query($s);
            }
        }
    }

    public function execute_with_bulkhash($sql_statement, $list, $decode = false)
    {
        $matches = array();
        $j = preg_match_all('/\<bulk?(.*?)?\>/m', $sql_statement, $bmatches);
        if ($j !== false) {
            if (isset($bmatches[0])) {
                if (isset($bmatches[0][0])) {
                    $start = strpos($sql_statement, $bmatches[0][0]);
                    $ende = strrpos($sql_statement, '</bulk>');
                    if ($start !== false) {
                        if ($ende !== false) {
                            $part = substr($sql_statement, $start+6, $ende -6- $start);
                            $start_sql = substr($sql_statement, 0, $start - 1);
                            $end_sql = substr($sql_statement, $ende+7);
                            $parts = array();
                            $i = preg_match_all('/\{(?P<name>(\w+)(.\w+)*)\}/', $part, $matches);
                            if ($i === false) {
                            } else {
                                if (isset($matches['name'])) {
                                    foreach ($list as $item) {
                                        $xs=$part;
                                        foreach ($matches['name'] as $p) {
                                          $xs=str_replace('{'.$p.'}', isset($item[$p]) ? ' \''.$this->escape_string($item[$p]).'\' ' : 'null', $xs);
                                        }
                                        $parts[] =$xs;
                                    }
                                }
                            }
                            $sql_statement = $start_sql.implode(',', $parts).$end_sql;
                            return $this->execute($sql_statement);
                        }
                    }
                }
            }
        }
    }

    public function replace_hash($sql,$hash){
      //if ($hash instanceof DSModel) $hash = $hash->toArray();
      
      //error_reporting(E_ALL);
      ini_set("display_errors","on");

      $matches = array();
      $i = preg_match_all('/\{(?P<name>(\w+)(.\w+)*)\}/', $sql, $matches);
      if ($i === false) {
      } else {
        if (isset($matches['name'])) {
          foreach ($matches['name'] as $p) {
            $func = '';
            $field = '';
            if (strpos($p,':')!==false){
                $parts = explode(':',$p);
                $func = $parts[1];
                $field =$parts[0];
            }
            if ($func == 'array'){
                if (isset($hash[$field])){
                    $v=array();
                    foreach($hash[$field] as $x){
                        $v[] = $this->escape_string($x);
                    }
                    $sql = str_replace('{'.$p.'}', '\''.implode('\',\'',$v).'\'', $sql);// ' \''.$this->escape_string($hash[$p]).'\' ' : '(null)', $sql);
                }else{
                    $sql = str_replace('{'.$p.'}', 'null', $sql);
                }
            }else{
                $sql = str_replace('{'.$p.'}', isset($hash[$p]) ? ' \''.$this->escape_string($hash[$p]).'\' ' : 'null', $sql);
            }
          }
        }
      }
      return $sql;
    }

    public function execute_with_hash($sql_statement, $hash, $decode = false)
    {
        /*
        if ($this->charset == 'utf8') {
            $decode = false;
        }
        $matches = array();
        $i = preg_match_all('/\{(?P<name>(\w+)(.\w+)*)\}/', $sql_statement, $matches);
        if ($i === false) {
        } else {
            if (isset($matches['name'])) {
                foreach ($matches['name'] as $p) {
                    if ($decode === true) {
                        $sql_statement = str_replace('{'.$p.'}', isset($hash[$p]) ? ' \''.$this->escape_string(utf8_decode($hash[$p])).'\' ' : 'null', $sql_statement);
                    } else {
                        $sql_statement = str_replace('{'.$p.'}', isset($hash[$p]) ? ' \''.$this->escape_string($hash[$p]).'\' ' : 'null', $sql_statement);
                    }
                }
            }
        }
        return $this->execute( $sql_statement );
        */
        return $this->execute( $this->replace_hash( $sql_statement, $hash ) );
    }

    public function enableLogging($command)
    {
        $this->logcommands[strtoupper($command)] = true;
    }
    public function disableLogging($command)
    {
        $this->logcommands[strtoupper($command)] = false;
    }
    public function setLogFile($filename)
    {
        $this->logfile = $filename;
    }
    public function execute($sql_statement)
    {
        $this->check_start();
        $sql_statement = trim($sql_statement);
        $this->log($sql_statement );

        
        $this->warnings=array();
        if ($this->logfile != '') {
            if (count($this->logcommands) > 0) {
                if (!file_exists($this->logfile)) {
                    file_put_contents($this->logfile, '');
                }
                $space_pos = strpos($sql_statement, ' ');
                if ($space_pos !== false) {
                    $keyword = strtoupper(substr($sql_statement, 0, $space_pos));
                    if (isset($this->logcommands[$keyword])) {
                        if ($this->logcommands[$keyword] === true) {
                            file_put_contents($this->logfile, utf8_encode($sql_statement).";\n", FILE_APPEND);
                        }
                    }
                }
            }
        }
        $this->last_sql = $sql_statement;

        if ($sql_statement != '') {
            if (
                (strtoupper(substr($sql_statement, 0, 6)) == 'SELECT') ||
                (strtoupper(substr($sql_statement, 0, 4)) == 'SHOW') ||
                (strtoupper(substr($sql_statement, 0, 5)) == 'CHECK') ||
                (strtoupper(substr($sql_statement, 0, 6)) == 'REPAIR') ||
                (strtoupper(substr($sql_statement, 0, 7)) == 'EXPLAIN')
            ) {
                $rs = false;
                $this->lastSQL = $sql_statement;
                
                $res = $this->mysqli->query($sql_statement);
                if ($res !== false) {
                    try {
                        $rs = new Recordset_mysql($res);
                        if (property_exists($this,"dbTypes")){
                            $rs->useDBTypes($this->dbTypes);
                        }

                    } catch (\Exception $error) {
                        throw new \Exception($this->GetError() );
                    }
                } else {
                    throw new \Exception($this->GetError() );
                }
                if ($this->mysqli->warning_count!=0) { 
                    $e = $this->mysqli->get_warnings(); 
                    do { 
                        $this->warnings[] = array('errno'=>$e->errno,'message'=>$e->message,'sqlstate'=>$e->sqlstate);
                    } while ($e->next()); 
                }
                return $rs;
            } else {
                $this->lastSQL = $sql_statement;
                $res = $this->mysqli->query($sql_statement);

                if ($this->mysqli->warning_count!=0) { 
                    $e = $this->mysqli->get_warnings(); 
                    do { 
                        $this->warnings[] = array('errno'=>$e->errno,'message'=>$e->message,'sqlstate'=>$e->sqlstate);
                    } while ($e->next()); 
                }


                if ($res) {
                    return $res;
                } else {
                    throw new \Exception($this->GetError() );
                    //					throw new mException($this->GetError()." ".addslashes($sql_statement)." ",__FILE__,__LINE__);
                }
            }
        } else {
            return false;
        }
        $this->check_stop($sql_statement);
    }

    public function escape_string($str)
    {
        if (is_string($str)){
            return $this->mysqli->real_escape_string($str);
        }else{
            return $str;
        }
    }

    public function execute_with_params($sql_statement, $params, $debug = false)
    {
        $sql_statement = trim($sql_statement);
        if (strtoupper(substr($sql_statement, 0, 6)) == 'SELECT') {
            throw new \Exception('Parameterbindung bei auswählenden Anweisungen nicht möglich. '.addslashes($sql_statement));

            return false;
        } else {
            $sql_temp = '';
            $parts = explode('?', $sql_statement);
            for ($i = 0, $m = count($parts); $i < $m; ++$i) {
                $sql_temp .= $parts[$i];
                $value = '';
                if ($i < ($m - 1)) {
                    if ($i < count($params)) {
                        if (isset($params[$i])) {
                            switch (gettype($params[$i])) {
                                case 'string':
                                $value = '\''.$this->escape_string($params[$i]).'\'';
                                break;
                                default:
                                $value = ''.$params[$i].'';
                            }
                        } else {
                            $value = 'null';
                        }
                    } else {
                        throw new \Exception($sql_statement.' - '.print_r($params, true).' - Parameteranzahl stimmt nicht überein. '.$i.' < '.count($params));

                        return false;
                    }
                    $sql_temp .= $value;
                }
            }
            if ($debug) {
                echo $sql_temp;
            }
            /*
            if (isset($_REQUEST['mysql.db.param.debug']) && ($_REQUEST['mysql.db.param.debug'] == 1)) {
                file_put_contents('mysql.db.param.txt', $sql_temp);
            }
                        */
            return $this->execute($sql_temp);
        }
    }

    public function autocommit($bool_state)
    {
        $this->commit_state = $bool_state;
        $this->mysqli->autocommit($bool_state);
        if ($this->commit_state==false){
            $this->mysqli->begin_transaction();
        }

        return $this->commit_state;
    }

    public function commit()
    {
        return $this->mysqli->commit();
    }

    public function rollback()
    {
        return $this->mysqli->rollback();
    }

    public function commitstate()
    {
        return $this->commit_state;
    }

    public function isLocked($table_name){
        $item=$this->singleRow('show open tables from '.$this->dbname.' like {table_name}',array('table_name'=>$table_name));
        if ($item===false){
            return false;
        }else{
            if (intval($item['in_use'])>0){
                return true;
            }
        }
        return false;
    }
    /*
     * Listet alle Tabellen
     */

    public function getTables()
    {
        $tables = array();
        $sql = 'select table_name from information_schema.tables where table_schema=\''.$this->dbname.'\' ';
        $rs = $this->execute($sql);
        while ($rs->moveNext()) {
            $tables[] = $rs->fieldValue('table_name');
        }
        $rs->unload();

        return $tables;
    }

    public function getColumns($table_name)
    {
        $types = array();
        $types['int'] = 'integer';
        $types['bigint'] = 'integer';
        $types['tinyint'] = 'integer';

        $types['float'] = 'float';

        $types['decimal'] = 'fixed';
        $types['fixed'] = 'fixed';

        $types['date'] = 'date';
        $types['time'] = 'time';
        $types['datetime'] = 'datetime';

        $types['varchar'] = 'string';
        $types['char'] = 'string';

        $columns = array();
        $sql = 'select column_name columnname,data_type ctype,character_maximum_length clength,column_key ckey,is_nullable,NUMERIC_PRECISION,NUMERIC_SCALE from information_schema.columns where  table_schema=\''.$this->dbname.'\' and table_name=\''.$table_name.'\' order by ordinal_position ';
        $rs = $this->execute($sql);
        while ($rs->moveNext()) {
            $columns[] = array(
                'name' => $rs->fieldValue('columnname'),
                'type' => find_in($types, $rs->fieldValue('ctype'), 'string'),
                'length' => $rs->fieldValue('clength'),
                'precision' => $rs->fieldValue('numeric_precision'),
                'scale' => $rs->fieldValue('numeric_scale'),
                'key' => $rs->fieldValue('ckey') != '' ? true : false,
                'nullable' => $rs->fieldValue('is_nullable') == 'YES' ? true : false,
            );
        }
        $rs->unload();

        return $columns;
    }

    private function find_in($array, $value, $default = '')
    {
        $return = $default;
        if (isset($array[$value])) {
            $return = $array[$value];
        }

        return $return;
    }
}
