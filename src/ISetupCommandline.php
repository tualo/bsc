<?php
namespace Tualo\Office\Basic;
use Garden\Cli\Cli;
use Garden\Cli\Args;

interface ISetupCommandline
{
    public static function getCommandName():string;
    public static function getCommandDescription():string;
    public static function run(Args $args);
}