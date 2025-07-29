<?php

namespace Tualo\Office\Basic;

/**
 * Class FormatedCommandLineOutput
 * Provides methods to format command line output with ANSI escape codes.
 *
 * @package Tualo\Office\Basic
 */
class FormatedCommandLineOutput
{
    private static $intentLevel;

    public static function intent()
    {
        self::$intentLevel++;
    }

    public static function unintent()
    {
        self::$intentLevel--;
        if (self::$intentLevel < 0) {
            self::$intentLevel = 0;
        }
    }

    public static function formatPrint(array $format = [], string $text = '')
    {
        $codes = [
            'bold' => 1,
            'italic' => 3,
            'underline' => 4,
            'strikethrough' => 9,
            'black' => 30,
            'red' => 31,
            'green' => 32,
            'yellow' => 33,
            'blue' => 34,
            'magenta' => 35,
            'cyan' => 36,
            'white' => 37,
            'blackbg' => 40,
            'redbg' => 41,
            'greenbg' => 42,
            'yellowbg' => 44,
            'bluebg' => 44,
            'magentabg' => 45,
            'cyanbg' => 46,
            'lightgreybg' => 47
        ];
        $formatMap = array_map(function ($v) use ($codes) {
            return $codes[$v];
        }, $format);
        echo "\e[" . implode(';', $formatMap) . 'm' . $text . "\e[0m";
    }
    public static function formatPrintLn(array $format = [], string $text = '')
    {
        if (self::$intentLevel > 0) {
            $text = str_repeat('    ', self::$intentLevel) . $text;
        }
        if (empty($text)) {
            $text = ' ';
        }
        echo self::formatPrint($format, $text) . PHP_EOL;
    }
}
