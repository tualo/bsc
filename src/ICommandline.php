<?php
namespace Tualo\Office\Basic;
use Garden\Cli\Cli;
use Garden\Cli\Args;

interface ICommandline
{
    public static function getCommandName():string;
    public static function setup(Cli $cli);
    public static function run(Args $args);
}