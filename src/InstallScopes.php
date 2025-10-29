<?php

namespace Tualo\Office\BSC\Commands;

use Garden\Cli\Cli;
use Garden\Cli\Args;
use phpseclib3\Math\BigInteger\Engines\PHP;
use Tualo\Office\Basic\ICommandline;
use Tualo\Office\ExtJSCompiler\Helper;
use Tualo\Office\Basic\TualoApplication as App;
use Tualo\Office\Basic\PostCheck;

class InstallScopes implements ICommandline
{


    public static function getCommandName(): string
    {
        return 'install-sql-bsc-scopes';
    }

    public static function setup(Cli $cli)
    {
        $cli->command(self::getCommandName())
            ->description('installs needed scopes ddl ')
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
                // PostCheck::formatPrintLn(['green'], "\t" . ' done');

                $scopes = [];
                $classes = get_declared_classes();
                foreach ($classes as $cls) {
                    $class = new \ReflectionClass($cls);
                    if ($class->implementsInterface('Tualo\Office\Basic\IRoute')) {
                        $GLOBALS['current_cls'] = $cls;
                        $scopes[] = $cls::scope();
                    }
                }
                $scopes = array_unique($scopes);
                $sql = 'insert ignore into route_scopes (scope) values ({scope}) ';
                foreach ($scopes as $scope) {
                    App::get('clientDB')->direct($sql, [
                        'scope' => $scope
                    ]);
                }

                App::get('clientDB')->close();
            }
        }
    }

    public static function run(Args $args)
    {
        $files = [
            'bsc_route_log' => 'setup scopes '
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
