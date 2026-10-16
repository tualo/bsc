<?php

namespace Tualo\Office\Basic;

interface IScope
{
    public static function identifier(): string;
    public static function name(string $language = 'EN'): string;
    public static function description(string $language = 'EN'): string;
}
