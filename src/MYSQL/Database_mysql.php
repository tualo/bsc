<?php

namespace Tualo\Office\Basic\MYSQL;

use Tualo\Office\Basic\TualoApplication;

use Tualo\Office\Basic\BASIC\Database_basic;
use Tualo\Office\Basic\BASIC\RecordsetBasic;
use Tualo\Office\Basic\MYSQL\Recordset_mysql;
use Mysqli;

class Database_mysql extends Database_basic
{
    private $_version = '1.2.001';
    public \Mysqli $mysqli;
    private $commit_state = true;
    public $state = false;
    public $dbname = '';
    public $lastSQL = '';

    private $logfile = '';
    private $logcommands = array();
    private $warnings = array();
    public $last_sql = '';
    private $charset = '';

    private $user = '';
    private $pass = '';
    private $host = '';
    private $port = 3306;
    private $db = '';

    private $_tinyIntAsBoolean = false;


    public function tinyIntAsBoolean(bool $value): bool
    {
        $this->_tinyIntAsBoolean = $value;
        return $this->_tinyIntAsBoolean;
    }


    public function __construct(string $user, string $pass, string $db, string $host, int $port = 3306, ?string $ssl_key = null, ?string $ssl_cert = null, ?string $ssl_ca = null)
    {
        parent::__construct($user, $pass, $db, $host);
        if (strpos($host, ':') !== false) {
            list($host, $port) = explode(':', $host);
        }

        TualoApplication::timing("db __construct");

        $this->dbname = $db;
        $this->mysqli = new mysqli;
        $this->mysqli->options(MYSQLI_OPT_CONNECT_TIMEOUT,  TualoApplication::configuration('', 'client.mysql.connect_timeout', 10));
        $this->mysqli->options(MYSQLI_OPT_SSL_VERIFY_SERVER_CERT, false);
        // $this->mysqli->options(MYSQLI_SET_CHARSET_NAME ,"utf8mb4");
        $c = false;

        TualoApplication::timing("db __construct options");

        if ($ssl_key !== null && $ssl_key !== '' && $ssl_cert !== null && $ssl_cert !== '' && $ssl_ca !== null && $ssl_ca !== '') {
            $this->mysqli->ssl_set($ssl_key, $ssl_cert, $ssl_ca, NULL, NULL);
            $c = @$this->mysqli->real_connect($host, ($user), ($pass), $db, $port, NULL, MYSQLI_CLIENT_SSL_DONT_VERIFY_SERVER_CERT);
            TualoApplication::timing("db __construct connect ssl");
        } else {
            $c = @$this->mysqli->real_connect($host, ($user), ($pass), $db, $port, null,  MYSQLI_CLIENT_SSL);
            TualoApplication::timing("db __construct connect plain");
        }
        TualoApplication::timing("db __construct connect step a");
        if (!$c) {
            TualoApplication::logger("Database")->critical("Database not reachable $host:$port, $user, $db " . gethostname());
            throw new \Exception('Verbindungsfehler, die Datenbank kann nicht erreicht werden (' . $this->mysqli->connect_error . ') ' . $this->mysqli->connect_errno);
        } else {
            TualoApplication::timing("db __construct connect step x");
            // $this->mysqli->set_charset('utf8');
            $this->charset = 'utf8';
            if ($this->mysqli->connect_errno) {
            } else {
                $this->host = $host;
                $this->user = $user;
                $this->pass = $pass;
                $this->db = $db;
                $this->port = $port;
            }

            // $this->autocommit($this->commit_state);
            $this->state = true;

            // $this->execute("SET NAMES 'utf8mb4' COLLATE 'utf8mb4_general_ci'");
            $this->execute('SET collation_connection = @@collation_database;');
            $this->execute('SET character_set_client = @@character_set_database;');

            if ($val = TualoApplication::configuration('database', 'lc_time_names', false)) $this->execute('SET SESSION lc_time_names= ' . $val . ';');

            if ($val = TualoApplication::configuration('database', 'set_names', false)) {
                //"SET NAMES 'utf8mb4' COLLATE 'utf8mb4_general_ci'")) 
                $this->execute($val);
            }
        }


        TualoApplication::timing("db __construct connect ready");
    }

    private function log($txt)
    {
        if (defined("__LOG_DB_COMMANDS__")) {
            $fh = fopen(constant('__LOG_DB_COMMANDS__'), 'a+');
            fwrite($fh, implode("\t", array(date("Y-m-d H:i:s", time()), $this->get_callee(), str_replace("\t", " ", str_replace("\r", " ", str_replace("\n", " ", $txt))) . "\n")));
            fclose($fh);
        }
    }

    private function get_callee()
    {
        $backtrace = debug_backtrace();
        $txt = array();
        foreach ($backtrace as $trace) {
            $txt[] = $trace['function'] . '-' . $trace['file'] . '(' . $trace['line'] . ')';
        }
        return implode('>', $txt);
    }

    public function reconnect()
    {
        $this->mysqli->close();
        $this->mysqli = new \mysqli($this->host, ($this->user), ($this->pass), $this->db, $this->port);
    }

    public function __destruct()
    {
        //$this->mysqli->close();
    }

    public function close()
    {
        if ($this->state) {
            $this->mysqli->close();
            $this->state = false;
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
        if (defined(constant('__QUERY_CHECK__'))) {
            if (constant('__QUERY_CHECK__') == '1') {
                $sql = str_replace("'", '*', $sql);
                if (strlen($sql) > 3900) {
                    $sql = substr($sql, 0, 3900);
                }
                $s = "insert into query_check (diff,anfrage) values ($diff,'$sql')";
                $this->execute($s);
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
                            $part = substr($sql_statement, $start + 6, $ende - 6 - $start);
                            $start_sql = substr($sql_statement, 0, $start - 1);
                            $end_sql = substr($sql_statement, $ende + 7);
                            $parts = array();
                            $i = preg_match_all('/\{(?P<name>(\w+)(.\w+)*)\}/', $part, $matches);
                            if ($i === false) {
                            } else {
                                if (isset($matches['name'])) {
                                    foreach ($list as $item) {
                                        $xs = $part;
                                        foreach ($matches['name'] as $p) {
                                            $xs = str_replace('{' . $p . '}', isset($item[$p]) ? ' \'' . $this->escape_string($item[$p]) . '\' ' : 'null', $xs);
                                        }
                                        $parts[] = $xs;
                                    }
                                }
                            }
                            $sql_statement = $start_sql . implode(',', $parts) . $end_sql;
                            return $this->execute($sql_statement);
                        }
                    }
                }
            }
        }
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

    public function moreResults()
    {
        $results = [];

        while ($this->mysqli->more_results()) {

            if ($result = $this->mysqli->use_result()) {
                $res = [];
                while ($row = $result->fetch_row()) {
                    $res[] = $row;
                }
                $results[] = $res;
                $result->close();
            }
            $this->mysqli->next_result();
        }
        return $results;
    }

    public function execute_with_hash(string $sql_statement, array $hash, $decode = false): Recordset_mysql | bool
    {

        return $this->execute($this->replace_hash($sql_statement, $hash));
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

    public function execute(string $statement): Recordset_mysql | bool
    {
        $this->check_start();
        $statement = trim($statement);
        $this->log($statement);


        $this->warnings = array();
        if ($this->logfile != '') {
            if (count($this->logcommands) > 0) {
                if (!file_exists($this->logfile)) {
                    file_put_contents($this->logfile, '');
                }
                $space_pos = strpos($statement, ' ');
                if ($space_pos !== false) {
                    $keyword = strtoupper(substr($statement, 0, $space_pos));
                    if (isset($this->logcommands[$keyword])) {
                        if ($this->logcommands[$keyword] === true) {
                            file_put_contents($this->logfile, utf8_encode($statement) . ";\n", FILE_APPEND);
                        }
                    }
                }
            }
        }
        $this->last_sql = $statement;

        if ($statement != '') {
            if (
                (strtoupper(substr($statement, 0, 6)) == 'SELECT') ||
                (strtoupper(substr($statement, 0, 4)) == 'SHOW') ||
                (strtoupper(substr($statement, 0, 4)) == 'WITH') ||
                (strtoupper(substr($statement, 0, 5)) == 'CHECK') ||
                (strtoupper(substr($statement, 0, 6)) == 'REPAIR') ||
                (strtoupper(substr($statement, 0, 7)) == 'EXPLAIN')
            ) {
                $rs = false;
                $this->lastSQL = $statement;


                //TualoApplication::timing(self::class.' mysqli->query start '.__LINE__);
                $res = $this->mysqli->query($statement);
                //TualoApplication::timing(self::class.' mysqli->query stop '.__LINE__);

                if ($res !== false) {
                    try {
                        $rs = new Recordset_mysql($res);
                        if (property_exists($this, "dbTypes")) {
                            $rs->useDBTypes($this->dbTypes);
                        }
                        $rs->tinyIntAsBoolean($this->_tinyIntAsBoolean);
                    } catch (\Exception $error) {
                        throw new \Exception($this->GetError());
                    }
                } else {
                    throw new \Exception($this->GetError());
                }
                if ($this->mysqli->warning_count != 0) {
                    $e = $this->mysqli->get_warnings();
                    do {
                        $this->warnings[] = array('errno' => $e->errno, 'message' => $e->message, 'sqlstate' => $e->sqlstate);
                    } while ($e->next());
                }
                //TualoApplication::timing(self::class.' execute return '.__LINE__);

                return $rs;
            } else {
                $this->lastSQL = $statement;
                $res = $this->mysqli->query($statement);
                if ($this->mysqli->warning_count != 0) {
                    $e = $this->mysqli->get_warnings();
                    do {
                        $this->warnings[] = array('errno' => $e->errno, 'message' => $e->message, 'sqlstate' => $e->sqlstate);
                    } while ($e->next());
                }


                if ($res) {
                    return true;
                } else {
                    throw new \Exception($this->GetError());
                }
            }
        } else {
            return false;
        }
        $this->check_stop($statement);
    }

    public function escape_string(string $str): string
    {
        if (is_string($str)) {
            return $this->mysqli->real_escape_string($str);
        } else {
            return $str;
        }
    }

    public function getWarnings()
    {
        return $this->warnings;
    }

    public function execute_with_params(string $statement, array $params): Recordset_mysql | bool
    {
        $statement = trim($statement);
        if (strtoupper(substr($statement, 0, 6)) == 'SELECT') {
            throw new \Exception('Parameterbindung bei auswählenden Anweisungen nicht möglich. ' . addslashes($statement));

            return false;
        } else {
            $sql_temp = '';
            $parts = explode('?', $statement);
            for ($i = 0, $m = count($parts); $i < $m; ++$i) {
                $sql_temp .= $parts[$i];
                $value = '';
                if ($i < ($m - 1)) {
                    if ($i < count($params)) {
                        if (isset($params[$i])) {
                            switch (gettype($params[$i])) {
                                case 'string':
                                    $value = '\'' . $this->escape_string($params[$i]) . '\'';
                                    break;
                                default:
                                    $value = '' . $params[$i] . '';
                            }
                        } else {
                            $value = 'null';
                        }
                    } else {
                        throw new \Exception($statement . ' - ' . print_r($params, true) . ' - Parameteranzahl stimmt nicht überein. ' . $i . ' < ' . count($params));

                        return false;
                    }
                    $sql_temp .= $value;
                }
            }
            return $this->execute($sql_temp);
        }
    }

    public function autocommit(bool $bool_state): bool
    {
        $this->commit_state = $bool_state;
        $this->mysqli->autocommit($bool_state);
        if ($this->commit_state == false) {
            $this->mysqli->begin_transaction();
        }

        return $this->commit_state;
    }

    public function commit(): bool
    {
        return $this->mysqli->commit();
    }

    public function rollback(): bool
    {
        return $this->mysqli->rollback();
    }

    public function commitstate(): bool
    {
        return $this->commit_state;
    }

    public function isLocked(string $table_name): bool
    {
        $item = $this->singleRow('show open tables from ' . $this->dbname . ' like {table_name}', array('table_name' => $table_name));
        if ($item === false) {
            return false;
        } else {
            if (intval($item['in_use']) > 0) {
                return true;
            }
        }
        return false;
    }
    /*
     * Listet alle Tabellen
     */

    public function getTables(): array
    {
        $tables = array();
        $sql = 'select table_name from information_schema.tables where table_schema=\'' . $this->dbname . '\' ';
        $rs = $this->execute($sql);
        while ($rs->moveNext()) {
            $tables[] = $rs->fieldValue('table_name');
        }
        $rs->unload();

        return $tables;
    }
    public function getColumns(string $table_name): array
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
        $sql = 'select column_name columnname,data_type ctype,character_maximum_length clength,column_key ckey,is_nullable,NUMERIC_PRECISION,NUMERIC_SCALE from information_schema.columns where  table_schema=\'' . $this->dbname . '\' and table_name=\'' . $table_name . '\' order by ordinal_position ';
        $rs = $this->execute($sql);
        while ($rs->moveNext()) {
            $columns[] = array(
                'name' => $rs->fieldValue('columnname'),
                'type' => $this->find_in($types, $rs->fieldValue('ctype'), 'string'),
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
