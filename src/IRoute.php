<?php

namespace Tualo\Office\Basic;

interface IRoute
{
    public static function scope(): string;
    public static function register();
}
