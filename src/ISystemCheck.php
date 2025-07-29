<?php

namespace Tualo\Office\Basic;

interface ISystemCheck
{
    public static function getModuleName(): string;
    public static function hasClientTest(): bool;
    public static function hasSessionTest(): bool;

    public static function testSessionDB(array $config): int;

    /**
     * @param array $config
     * @return int 0 on success, or error code on failure
     */
    public static function test(array $config): int;
}
