<?php

namespace Tualo\Office\Basic;

use Garden\Cli\Cli;
use Garden\Cli\Args;
use Tualo\Office\Basic\ICommandline;
use Tualo\Office\ExtJSCompiler\Helper;
use Tualo\Office\Basic\TualoApplication as App;
use Tualo\Office\Basic\SystemCheck;
use Tualo\Office\Basic\Version;

class SystemCheckCommandline implements ICommandline
{

    public static function getCommandName(): string
    {
        return 'systemcheck';
    }

    public static function setup(Cli $cli)
    {
        $cli->command(self::getCommandName())
            ->description('runs systemcheck commands for all modules')
            ->opt('client', 'only use this client', false, 'string');
    }




    public static function loopClients(array $config, ?string $clientName = null)
    {
        try {
            $_SERVER['REQUEST_URI'] = '';
            $_SERVER['REQUEST_METHOD'] = 'none';
            App::run();
            $session = App::get('session');
            if (is_null($session->db)) {
                SystemCheck::formatPrintLn(['red'], 'there is not database configuration');
                SystemCheck::formatPrintLn(['yellow'], 'performing basic check');
                $classes = get_declared_classes();
                foreach ($classes as $cls) {
                    $class = new \ReflectionClass($cls);
                    if ($class->implementsInterface('Tualo\Office\Basic\ISystemCheck')) {
                        if ($cls::hasClientTest()) {
                            SystemCheck::formatPrintLn(['blue'], 'SystemCheck for ' . $cls::getModuleName() . ':');
                            SystemCheck::intent();
                            $cls::test($config);
                            SystemCheck::unintent();
                        }
                    }
                }
            } else {
                $sessiondb = $session->db;

                $dbs = $sessiondb->direct('select username db_user, password db_pass, id db_name, host db_host, port db_port from macc_clients ');
                foreach ($dbs as $db) {
                    if (!is_null($clientName) && $clientName != $db['db_name']) {
                        continue;
                    } else {


                        try {
                            App::set('clientDB', $session->newDBByRow($db));
                            SystemCheck::formatPrintLn(['blue'], 'checks on ' . $db['db_name'] . ':  ');
                            $classes = get_declared_classes();
                            foreach ($classes as $cls) {
                                $class = new \ReflectionClass($cls);
                                if ($class->implementsInterface('Tualo\Office\Basic\ISystemCheck')) {
                                    if ($cls::hasClientTest()) {
                                        SystemCheck::formatPrintLn(['blue'], 'SystemCheck for ' . $cls::getModuleName() . ':');
                                        SystemCheck::intent();
                                        $cls::test($config);
                                        SystemCheck::unintent();
                                    }
                                }
                            }
                            App::get('clientDB')->close();
                        } catch (\Exception $e) {
                            SystemCheck::formatPrintLn(['red'], 'error on ' . $db['db_name'] . ':  ');
                            SystemCheck::formatPrintLn(['red'], $e->getMessage());
                            SystemCheck::formatPrintLn(['blue'], 'try `./tm createsystem --db "' . $db['db_name'] . '"`');
                        }
                    }
                }
            }

            App::set('clientDB', $session->db);
            $classes = get_declared_classes();
            foreach ($classes as $cls) {
                $class = new \ReflectionClass($cls);
                if ($class->implementsInterface('Tualo\Office\Basic\ISystemCheck')) {
                    if ($cls::hasSessionTest()) {
                        SystemCheck::formatPrintLn(['blue'], 'SystemCheck for ' . $cls::getModuleName() . ' (sessiontests):');
                        SystemCheck::intent();
                        $cls::testSessionDB($config);
                        SystemCheck::unintent();
                    }
                }
            }
            App::get('clientDB')->close();
        } catch (\Exception $e) {
        }
    }

    public static function run(Args $args)
    {
        self::loopClients((array)App::get('configuration'), $args->getOpt('client'));
        // Version::versionMD5(true);
        if (!file_exists(App::get('basePath') . '/cache')) {
            mkdir(App::get('basePath') . '/cache');
        }
        if (!file_exists(App::get('basePath') . '/temp')) {
            mkdir(App::get('basePath') . '/temp');
        }
    }
}
