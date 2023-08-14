<?php
namespace Tualo\Office\Basic;
interface IPostCheck
{
    public static function testSessionDB(array $config);
    public static function test(array $config);
}