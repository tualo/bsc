<?php

namespace Tualo\Office\Basic;

use Garden\Cli\Cli;
use Garden\Cli\Args;

class BaseSetupCommand implements ISetupCommandline
{
    public static function getCommandName(): string
    {
        return 'base-setup';
    }
    public static function getCommandDescription(): string
    {
        return 'perform a base setup';
    }
    public static function setup(Cli $cli)
    {
        $cli->command(self::getCommandName())
            ->description(self::getCommandDescription())
            ->opt('client', 'only use this client', true, 'string');
    }

    // This method should be overridden in child classes to provide specific commands
    public static function getCommands(Args $args): array
    {
        return [
            'install-sessionsql-bsc-main',
            'install-sql-sessionviews',
            'install-sql-bsc-main-ds',
            'install-sql-bsc-menu',

        ];
    }
    public static function performInstall(
        string $cmdString,
        string $clientName
    ) {
        $cmd = explode(' ', $cmdString);
        if ($clientName != '') $cmd[] = '--client=' . $clientName;
        $classes = get_declared_classes();
        foreach ($classes as $cls) {
            $class = new \ReflectionClass($cls);
            if ($class->implementsInterface('Tualo\Office\Basic\ICommandline')) {
                if ($cmd[0] == $cls::getCommandName()) {
                    $cli = new Cli();
                    $cls::setup($cli);
                    $args = $cli->parse(['./tm', ...$cmd], true);
                    $cls::run($args);
                }
            }
        }
    }

    public static function getHeadLine(): string
    {
        return 'Base Setup Command';
    }

    public static function run(Args $args)
    {
        $clientName = $args->getOpt('client');
        if (is_null($clientName)) $clientName = '';

        PostCheck::formatPrintLn(['blue'], "Installing all for: " . static::getHeadLine());
        PostCheck::formatPrintLn(['blue'], "==========================================================");

        $installCommands = static::getCommands($args);

        foreach ($installCommands as $cmdString) {
            static::performInstall($cmdString, $clientName);
        }
    }
}
