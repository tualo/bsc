<?php

namespace Tualo\Office\Basic;

use Garden\Cli\Cli;
use Garden\Cli\Args;
use phpseclib3\Math\BigInteger\Engines\PHP;
use Tualo\Office\Basic\ICommandline;
use Tualo\Office\ExtJSCompiler\Helper;
use Tualo\Office\Basic\TualoApplication as App;
use Tualo\Office\Basic\PostCheck;

class CommandLineInstallSessionSQL
{

    public static $shortName  = '';
    public static $dir = '';
    public static $files = [];

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

        return 'install-sessionsql-' . static::getShortName();
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
            ->description('installs needed session sql for ' . self::$shortName)
            ->opt('client', 'only use this client', true, 'string')
            ->opt('debug', 'show command index', false, 'boolean');
    }

    public static function setupClients(string $msg, string $clientName, string $file, callable $callback)
    {
        $_SERVER['REQUEST_URI'] = '';
        $_SERVER['REQUEST_METHOD'] = 'none';
        App::run();

        $session = App::get('session');
        $sessiondb = $session->db;
        $dbs = $sessiondb->direct('select username db_user, password db_pass, id db_name, host db_host, port db_port from macc_clients ');
        foreach ($dbs as $db) {
            if (($clientName != '') && ($clientName != $db['dbname'])) {
                continue;
            } else {

                App::set('clientDB', $session->newDBByRow($db));
                PostCheck::formatPrint(['blue'], $msg . '(' . $db['dbname'] . '):  ');
                $callback($file);
                PostCheck::formatPrintLn(['green'], "\t" . ' done');
            }
        }
    }


    public static function run(Args $args)
    {
        $files = self::getFiles();

        foreach ($files as $file => $msg) {
            $installSQL = function (string $file) {
                global $args;
                if ($args->getOpt('debug')) {
                    PostCheck::formatPrintLn(['blue'], "\n");
                }
                $filename = static::getDir() . '/sql/' . $file . '.sql';
                exec('cat ' . $filename . ' | sed -E \'s#SESSIONDB#' . App::get('session')->db->dbname . '#g\' | sed -E \'s#DBNAME#' . App::get('clientDB')->dbname . '#g\' | mysql --force=true -D ' . App::get('clientDB')->dbname . ' ', $res, $err);

                if ($err != 0) {
                    PostCheck::formatPrintLn(['red'], 'failed');
                    PostCheck::formatPrintLn(['red'], implode("\n", $res));
                    exit();
                } else {
                    // PostCheck::formatPrintLn(['green'],'done');
                }
            };
            $clientName = $args->getOpt('client');
            if (is_null($clientName)) $clientName = '';
            self::setupClients($msg, $clientName, $file, $installSQL);
        }
    }
}
