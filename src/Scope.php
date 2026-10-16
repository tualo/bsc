<?php

namespace Tualo\Office\Basic;

class Scope implements IScope
{
    private static string $identifier = '----';
    private static array $name = [
        'EN' => 'Basic',
        'DE' => 'Basis',
    ];
    private static array $description = [
        'EN' => 'standard functions',
        'DE' => 'Grundlegende Funktionen',
    ];

    public static function identifier(): string
    {
        // Implement the method
        return self::$identifier;
    }

    public static function name(string $language = 'EN'): string
    {
        // Implement the method
        return self::$name[$language] ?? self::$name['EN'];
    }

    public static function description(string $language = 'EN'): string
    {
        // Implement the method
        return self::$description[$language] ?? self::$description['EN'];
    }
}
