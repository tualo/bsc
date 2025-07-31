<?php

namespace Tualo\Office\Basic;

use Tualo\Office\Basic\TualoApplication as App;

class PreCheck implements IPreCheck
{

    public static function testSessionDB(array $config) {}

    public static function loopClients(array $config, string $clientName = null)
    {

        try {
            $_SERVER['REQUEST_URI'] = '';
            $_SERVER['REQUEST_METHOD'] = 'none';
            App::run();
            $session = App::get('session');
            if (is_null($session->db)) {
                self::formatPrintLn(['red'], 'there is not database configuration');
                self::formatPrintLn(['yellow'], 'performing basic check');
                $classes = get_declared_classes();
                foreach ($classes as $cls) {
                    $class = new \ReflectionClass($cls);
                    if ($class->implementsInterface('Tualo\Office\Basic\IPreCheck')) {
                        $cls::test($config);
                    }
                }
            } else {
                $sessiondb = $session->db;

                $dbs = $sessiondb->direct('select username db_user, password db_pass, id db_name, host db_host, port db_port from macc_clients ');
                foreach ($dbs as $db) {
                    if (!is_null($clientName) && $clientName != $db['db_name']) {
                        continue;
                    } else {
                        App::set('clientDB', $session->newDBByRow($db));
                        self::formatPrintLn(['blue'], 'checks on ' . $db['db_name'] . ':  ');
                        $classes = get_declared_classes();
                        foreach ($classes as $cls) {
                            $class = new \ReflectionClass($cls);
                            if ($class->implementsInterface('Tualo\Office\Basic\IPreCheck')) {
                                $cls::test($config);
                            }
                        }
                        App::get('clientDB')->close();
                    }
                }
            }

            App::set('clientDB', $session->db);
            $classes = get_declared_classes();
            foreach ($classes as $cls) {
                $class = new \ReflectionClass($cls);
                if ($class->implementsInterface('Tualo\Office\Basic\IPreCheck')) {
                    $cls::testSessionDB($config);
                }
            }
            App::get('clientDB')->close();
        } catch (\Exception $e) {

            self::formatPrintLn(['red'], 'error on ' . $db['db_name'] . ':  ' . $e->getMessage());
            exit(65);
        }
    }



    public static function test(array $config)
    {
        if (!file_exists(App::get('basePath') . '/tm')) {
            copy(App::get('basePath') . '/vendor/tualo/bsc/src/commandline/client-script', App::get('basePath') . '/tm');
            chmod(App::get('basePath') . '/tm', 0755);
        }
        if (!file_exists(App::get('basePath') . '/index.php')) {
            copy(App::get('basePath') . '/vendor/tualo/bsc/src/commandline/index.php', App::get('basePath') . '/index.php');
        }

        if (!file_exists(App::get('basePath') . '/.htaccess')) {
            $prompt = [
                "\t" . 'do you want to copy the .htaccess now? [y|n|c] '
            ];
            while (in_array($line = readline(implode("\n", $prompt)), ['yes', 'y', 'n', 'no', 'c'])) {
                if ($line == 'c') exit();
                if ($line == 'y') {
                    copy(App::get('basePath') . '/vendor/tualo/bsc/src/commandline/tpl/tpl.htaccess', App::get('basePath') . '/.htaccess');
                    self::formatPrintLn(['green'], "\t done");
                    break;
                }
                if ($line == 'n') {
                    break;
                }
            }
        }
    }

    public static function formatPrint(array $format = [], string $text = '')
    {
        $codes = [
            'bold' => 1,
            'italic' => 3,
            'underline' => 4,
            'strikethrough' => 9,
            'black' => 30,
            'red' => 31,
            'green' => 32,
            'yellow' => 33,
            'blue' => 34,
            'magenta' => 35,
            'cyan' => 36,
            'white' => 37,
            'blackbg' => 40,
            'redbg' => 41,
            'greenbg' => 42,
            'yellowbg' => 44,
            'bluebg' => 44,
            'magentabg' => 45,
            'cyanbg' => 46,
            'lightgreybg' => 47
        ];
        $formatMap = array_map(function ($v) use ($codes) {
            return $codes[$v];
        }, $format);
        echo "\e[" . implode(';', $formatMap) . 'm' . $text . "\e[0m";
    }
    public static function formatPrintLn(array $format = [], string $text = '')
    {
        echo self::formatPrint($format, $text) . PHP_EOL;
    }

    public static function tableCheck(string $displayName, array $tables, string $missingHint = '', string $differentHint = '')
    {
        $clientdb = App::get('clientDB');
        if (is_null($clientdb)) return;
        foreach ($tables as $tablename => $tabledef) {
            $columns = [];
            try {
                $columns = $clientdb->direct('explain `' . $tablename . '`');
                self::formatPrintLn(['green'], "\tmodule " . $displayName . " test table " . $clientdb->dbname . '.' . $tablename . ' exists  ');
                // $columnnames = array_map(function($v){ return $v['field']; },$columns);
                if (isset($tabledef['columns'])) {
                    foreach ($tabledef['columns'] as $colDef => $coltype) {
                        $found = false;
                        foreach ($columns as $column) {
                            if ($column['field'] == $colDef) {
                                $found = true;
                                if ($column['type'] != $coltype) {
                                    self::formatPrintLn(['red'], "\tmodule " . $displayName . " test table " . $clientdb->dbname . '.' . $tablename . ' column ' . $colDef . ' has different type ' . $column['type'] . ' != ' . $coltype);
                                    if ($differentHint != '')
                                        self::formatPrintLn(['blue'], "\t" . $differentHint);
                                }
                            }
                        }
                        if (!$found) {
                            self::formatPrintLn(['red'], "\tmodule " . $displayName . " test table " . $clientdb->dbname . '.' . $tablename . ' column ' . $colDef . ' does not exist');
                            if ($missingHint != '')
                                self::formatPrintLn(['blue'], "\t" . $missingHint);
                        }
                    }
                }
            } catch (\Exception $e) {
                self::formatPrintLn(['red'], "\tmodule " . $displayName . " test table " . $clientdb->dbname . '.' . $tablename . ' failed  ');
                if ($missingHint != '')
                    self::formatPrintLn(['blue'], "\t" . $missingHint);
                continue;
            }
        }
    }

    public static function procedureCheck(string $displayName, array $procedures, string $missingHint = '', string $differentHint = '')
    {
        $clientdb = App::get('clientDB');
        if (is_null($clientdb)) return;
        foreach ($procedures as $procedurename => $procedure_md5) {
            $columns = [];
            try {
                $columns = $clientdb->singleValue('select md5(routine_definition) md5 from information_schema.routines WHERE routine_schema = {clientdb} and routine_name like {procedurename}', ['procedurename' => $procedurename, 'clientdb' => $clientdb->dbname], 'md5');
                if ($columns === false) {
                    self::formatPrintLn(['red'], "\tmodule " . $displayName . " test stored procedure " . $clientdb->dbname . '.' . $procedurename . ' does not exist');
                    self::formatPrintLn(['blue'], "\t" . $missingHint);
                } else if ($columns == $procedure_md5) {
                    self::formatPrintLn(['green'], "\tmodule " . $displayName . " test stored procedure " . $clientdb->dbname . '.' . $procedurename . ' done  ');
                } else {
                    self::formatPrintLn(['yellow'], "\tmodule " . $displayName . " test stored procedure " . $clientdb->dbname . '.' . $procedurename . ' other version (got: ' . $columns . ', expected: ' . $procedure_md5 . ')');
                    self::formatPrintLn(['blue'], "\t" . $differentHint);
                }
            } catch (\Exception $e) {
                self::formatPrintLn(['red'], "\t" . $e->getMessage());
                continue;
            }
        }
    }
}
