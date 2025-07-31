<?php

namespace Tualo\Office\BSC;

use Garden\Cli\Cli;
use Garden\Cli\Args;
use phpseclib3\Math\BigInteger\Engines\PHP;
use Tualo\Office\Basic\ICommandline;
use Tualo\Office\ExtJSCompiler\Helper;
use Tualo\Office\Basic\TualoApplication as App;
use Tualo\Office\Basic\PostCheck;

class InstallViewSQLCommandline implements ICommandline
{

    public static function getCommandName(): string
    {
        return 'install-sql-sessionviews';
    }

    public static function setup(Cli $cli)
    {
        $cli->command(self::getCommandName())
            ->description('installs needed session views')
            ->opt('client', 'only use this client', true, 'string');
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
        $files = [
            'install/session_funcs' => 'setup session_funcs ',
            'install/doublequote' => 'setup doublequote ',
            'sessionviews' => 'setup sessionviews ',
            'oauth' => 'setup oauth '
        ];

        foreach ($files as $file => $msg) {
            $installSQL = function (string $file) {

                $filename = __DIR__ . '/sql/' . $file . '.sql';


                exec('cat ' . $filename . ' | sed -E \'s#SESSIONDB#' . App::get('session')->db->dbname . '#g\' | sed -E \'s#DBNAME#' . App::get('clientDB')->dbname . '#g\' | mysql --force=true -D ' . App::get('clientDB')->dbname . ' ', $res, $err);

                if ($err != 0) {
                    PostCheck::formatPrintLn(['red'], 'failed');
                    PostCheck::formatPrintLn(['red'], implode("\n", $res));
                    exit();
                } else {
                    PostCheck::formatPrintLn(['green'], 'done');
                }
            };
            $clientName = $args->getOpt('client');
            if (is_null($clientName)) $clientName = '';
            self::setupClients($msg, $clientName, $file, $installSQL);
        }
    }
}
