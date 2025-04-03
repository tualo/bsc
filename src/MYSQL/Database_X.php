<?php

namespace Tualo\Office\Basic\MYSQL;

use Amp\Mysql\MysqlConfig;
use Amp\Mysql\MysqlConnectionPool;
use Tualo\Office\Basic\BASIC\Database_basic;

class Fake
{
    public function set_charset($charset)
    {
        return true;
    }
}


class RecordSet
{
    private $result;
    public $a_fields = [];

    public function __construct($res)
    {
        $this->result = $res;
        $this->a_fields = $res->getColumnDefinitions();
    }
    public function toArray()
    {
        $return = [];
        $result = $this->result;
        foreach ($result as $row) {
            $return[] = $row;
        }
        $this->unload();
        return $return;
    }
    public function singleRow($utf8 = false)
    {
        $rows = $this->toArray('', $utf8);
        $this->unload();
        if (count($rows) == 1) {
            return $rows[0];
        }
        return false;
    }
    public function unload()
    {
        $this->result = null;
    }

    public function __serialize()
    {
        return [];
    }
}

class Database_X extends Database_basic
{


    private $_tinyIntAsBoolean = false;
    private $dbpool = null;
    public $dbname = '';
    public $mysqli = null;
    public $last_sql = '';

    function tinyIntAsBoolean($val)
    {
        $this->_tinyIntAsBoolean = $val;
    }



    public function replace_hash($sql, $hash)
    {
        //if ($hash instanceof DSModel) $hash = $hash->toArray();

        //error_reporting(E_ALL);
        ini_set("display_errors", "on");

        $matches = array();
        $i = preg_match_all('/\{(?P<name>(\w+)(.\w+)*)\}/', $sql, $matches);
        if ($i === false) {
        } else {
            if (isset($matches['name'])) {
                foreach ($matches['name'] as $p) {

                    $sql = str_replace('{' . $p . '}', ':' . $p, $sql);
                    /*
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
            */
                }
            }
        }
        return $sql;
    }

    public function execute_with_hash($sql_statement, $hash, $decode = false)
    {

        return new RecordSet($this->direct($sql_statement, $hash, '', true));
    }


    public function __construct($user, $pass, $db, $host, $port = 3306, $ssl_key = '', $ssl_cert = '', $ssl_ca = '')
    {
        $this->mysqli = new Fake();

        $config = new MysqlConfig(
            $host,
            $port,
            $user,
            $pass,
            $db/*,
            // sslKey: $ssl_key,
            // sslCert: $ssl_cert,
            // sslCa: $ssl_ca
            // 
            */
        );

        $config->withCharset("ascii", "ascii_general_ci");
        $this->dbpool = new MysqlConnectionPool($config);

        $this->execute('SET collation_connection = @@collation_database;');
        $this->execute('SET character_set_client = @@character_set_database;');
        // $config = $config->withCharset("ascii", "ascii_general_ci");
        $this->dbname = $db;
    }

    public function escape_string($str)
    {
        if (is_string($str)) {
            return $str; //this->mysqli->real_escape_string($str);
        } else {
            return $str;
        }
    }

    public function execute($statement)
    {
        $statement = $this->dbpool->prepare($this->replace_hash($statement, []));
        $result = $statement->execute();
        return new RecordSet($result);
    }

    public function moreResults()
    {
        $results = [];

        /*
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
        */
        return $results;
    }

    public function direct($statement, $hash = [], $key = '', $byName = false)
    {
        $res = array();
        try {


            $statement = $this->dbpool->prepare($this->replace_hash($statement, $hash));
            /*
            echo 'SQL: ' . $statement->getQuery() . "\n";
            print_r($hash);
            */
            if ($statement->getQuery() == 'set @request = :request;') {
                echo 'SQL: ' . $statement->getQuery() . "\n";
                var_dump($hash);
            }
            $result = $statement->execute($hash);

            $this->last_sql =  $statement->getQuery();

            foreach ($result as $row) {
                if ($byName) {
                    $res[] = $row;
                } else {
                    $res[] = ($row);
                }
            }
            //print_r($res);
        } catch (\Amp\Sql\SqlQueryError $e) {
            throw new \Exception('SQL Error: ' . $e->getMessage() . ' - SQL: ' . $statement->getQuery());
        }

        return $res;
        // new RecordSet($result);
    }
}

/*
$config = MysqlConfig::fromString(
    "host=localhost user=username password=password db=test"
);

$pool = new MysqlConnectionPool($config);

$statement = $pool->prepare("SELECT * FROM table_name WHERE id = :id");

$result = $statement->execute(['id' => 1337]);
foreach ($result as $row) {
    // $row is an associative-array of column values, e.g.: $row['column_name']
}
    */
