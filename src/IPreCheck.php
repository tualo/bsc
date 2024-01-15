<?php
namespace Tualo\Office\Basic;
interface IPreCheck
{
    public static function testSessionDB(array $config);
    public static function test(array $config);
}