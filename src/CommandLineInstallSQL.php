<?php

namespace Tualo\Office\Basic;

use Garden\Cli\Cli;
use Garden\Cli\Args;
use phpseclib3\Math\BigInteger\Engines\PHP;
use Tualo\Office\Basic\ICommandline;
use Tualo\Office\ExtJSCompiler\Helper;
use Tualo\Office\Basic\TualoApplication as App;
use Tualo\Office\Basic\PostCheck;

class CommandLineInstallSQL
{

    public static $shortName  = '';
    public static $dir = '';
    public static $files = [];

    public static function exitOnError(): bool
    {
        return false;
    }

    public static function getDir(): string
    {
        return __DIR__;
    }
    public static function getShortName(): string
    {
        if (static::$shortName == '') {
            throw new \Exception('shortName is not set*');
        }
        return static::$shortName;
    }

    public static function getCommandName(): string
    {

        return 'install-sql-' . static::getShortName();
    }

    public static function getFiles(): array
    {
        if (count(static::$files) == 0) {
            throw new \Exception('files is not set');
        }
        return static::$files;
    }

    public static function setup(Cli $cli)
    {
        $cli->command(static::getCommandName())
            ->description('installs needed sql for ' . self::getShortName())
            ->opt('client', 'only use this client', true, 'string')
            ->opt('sleep', 'seconds to sleep between each command', false, 'integer')
            ->opt('debug', 'show command index', false, 'boolean');
    }

    public static function setupClients(string $msg, string $clientName, string $file, callable $callback)
    {
        $_SERVER['REQUEST_URI'] = '';
        $_SERVER['REQUEST_METHOD'] = 'none';
        ini_set('memory_limit', '48024M');
        App::run();

        $session = App::get('session');
        $sessiondb = $session->db;
        $dbs = $sessiondb->direct('select username db_user, password db_pass, id db_name, host db_host, port db_port from macc_clients ');
        foreach ($dbs as $db) {
            if (($clientName != '') && ($clientName != $db['db_name'])) {
                continue;
            } else {

                App::set('clientDB', $session->newDBByRow($db));
                PostCheck::formatPrint(['blue'], $msg . '(' . $db['db_name'] . '):  ');
                $callback($file);
                PostCheck::formatPrintLn(['green'], "\t" . ' done');
                App::get('clientDB')->close();
            }
        }
    }


    public static function run(Args $args)
    {
        $files = static::getFiles();

        foreach ($files as $file => $msg) {
            $installSQL = function (string $file) {
                global $args;
                if ($args->getOpt('debug')) {
                    PostCheck::formatPrintLn(['blue'], "\n");
                }
                $filename = static::getDir() . '/sql/' . $file . '.sql';
                $sql = file_get_contents($filename);
                $sql = preg_replace('!/\*.*?\*/!s', '', $sql);
                $sql = preg_replace('#^\s*\-\-.+$#m', '', $sql);

                $sinlgeStatements = App::get('clientDB')->explode_by_delimiter($sql);
                $sleep_count = 0;
                foreach ($sinlgeStatements as $commandIndex => $statement) {
                    try {
                        App::get('session')->db->direct('select database()'); // keep connection alive
                        if ($args->getOpt('debug')) {
                            PostCheck::formatPrintLn(['blue'], "\t\t" . $commandIndex . ': ' . substr(preg_replace("/\\n/m", "", $statement), 0, 60));
                        }
                        $statement = str_replace('SESSIONDB.', App::get('session')->db->dbname . '.', $statement);
                        App::get('clientDB')->direct('select database()'); // keep connection alive
                        App::get('clientDB')->execute($statement);


                        App::get('clientDB')->moreResults();
                        if ($sleep_count++ > 30) {
                            $sleep_count = 0;
                            if (($sleep = $args->getOpt('sleep', 0)) != 0) sleep($sleep);
                        }
                    } catch (\Exception $e) {
                        echo PHP_EOL;
                        PostCheck::formatPrintLn(['red'], $e->getMessage() . ': commandIndex => ' . $commandIndex);
                        if (static::exitOnError()) {
                            exit(1);
                        }
                    }
                }
            };
            $clientName = $args->getOpt('client');
            if (is_null($clientName)) $clientName = '';
            self::setupClients($msg, $clientName, $file, $installSQL);
        }
    }
}
