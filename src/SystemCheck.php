<?php

namespace Tualo\Office\Basic;


class SystemCheck extends FormatedCommandLineOutput implements ISystemCheck
{

    public static function hasClientTest(): bool
    {
        return true;
    }

    public static function hasSessionTest(): bool
    {
        return false;
    }

    public static function getModuleName(): string
    {
        return 'basic';
    }

    public static function testSessionDB(array $config): int
    {
        return 0;
    }

    public static function test(array $config): int
    {
        // self::formatPrintLn(['blue'], 'SystemCheck:');
        // self::formatPrintLn(['green'], '  - checking database connection');
        return 0;
    }
}
