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

class Database_Y extends Database_basic
{

    private $_tinyIntAsBoolean = false;
    private $dbpool = null;
    public $dbname = '';
    public $mysqli = null;
    public $last_sql = '';
    public $warnings = [];

    public function moreResults()
    {
        $results = [];

        return $results;
    }

    public function __construct($user, $pass, $db, $host, $port = 3306, $ssl_key = '', $ssl_cert = '', $ssl_ca = '')
    {
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

        // $config->withCharset("ascii", "ascii_general_ci");
        $this->dbpool = new MysqlConnectionPool($config);

        $this->mysqli = new Fake();

        $this->execute('SET collation_connection = @@collation_database;');
        $this->execute('SET character_set_client = @@character_set_database;');
        // $config = $config->withCharset("ascii", "ascii_general_ci");
        $this->dbname = $db;
    }


    public function execute($sql_statement)
    {
        $sql_statement = trim($sql_statement);


        $this->warnings = [];


        $this->last_sql = $sql_statement;

        if ($sql_statement != '') {
            if (
                (strtoupper(substr($sql_statement, 0, 6)) == 'SELECT') ||
                (strtoupper(substr($sql_statement, 0, 4)) == 'SHOW') ||
                (strtoupper(substr($sql_statement, 0, 4)) == 'WITH') ||
                (strtoupper(substr($sql_statement, 0, 5)) == 'CHECK') ||
                (strtoupper(substr($sql_statement, 0, 6)) == 'REPAIR') ||
                (strtoupper(substr($sql_statement, 0, 7)) == 'EXPLAIN')
            ) {
                $rs = false;
                $this->last_sql = $sql_statement;





                try {
                    $statement = $this->dbpool->prepare($sql_statement);
                    $result = $statement->execute();
                    $rs = new Recordset_Y($result, $statement);
                } catch (\Amp\Sql\SqlQueryError $e) {
                    throw new \Exception($this->GetError());
                }

                /*
                if ($this->mysqli->warning_count != 0) {
                    $e = $this->mysqli->get_warnings();
                    do {
                        $this->warnings[] = array('errno' => $e->errno, 'message' => $e->message, 'sqlstate' => $e->sqlstate);
                    } while ($e->next());
                }
                */
                return $rs;
            } else {

                try {
                    $statement = $this->dbpool->prepare($this->replace_hash($sql_statement, []));
                    $result = $statement->execute();
                    return $result;
                } catch (\Amp\Sql\SqlQueryError $e) {
                    throw new \Exception($this->GetError());
                }
                /*

                $this->lastSQL = $sql_statement;
                $res = $this->mysqli->query($sql_statement);
                if ($this->mysqli->warning_count != 0) {
                    $e = $this->mysqli->get_warnings();
                    do {
                        $this->warnings[] = array('errno' => $e->errno, 'message' => $e->message, 'sqlstate' => $e->sqlstate);
                    } while ($e->next());
                }


                if ($res) {
                    //TualoApplication::timing(self::class.' execute return '.__LINE__);
                    return $res;
                } else {
                    throw new \Exception($this->GetError());
                    //					throw new mException($this->GetError()." ".addslashes($sql_statement)." ",__FILE__,__LINE__);
                }
                                    */
            }
        } else {
            //TualoApplication::timing(self::class.' execute return false '.__LINE__);
            return false;
        }
        //$this->check_stop($sql_statement);
    }
}
