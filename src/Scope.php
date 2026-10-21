<?php

namespace Tualo\Office\Basic;

class Scope implements IScope
{
    protected static string $identifier = '----';
    protected static array $name = [
        'EN' => 'Basic',
        'DE' => 'Basis',
    ];
    protected static array $description = [
        'EN' => 'standard functions',
        'DE' => 'Grundlegende Funktionen',
    ];

    public static function identifier(): string
    {
        // Implement the method
        return static::$identifier;
    }

    public static function name(string $language = 'EN'): string
    {
        // Implement the method
        return static::$name[$language] ?? static::$name['EN'];
    }

    public static function description(string $language = 'EN'): string
    {
        // Implement the method
        return static::$description[$language] ?? static::$description['EN'];
    }
}
