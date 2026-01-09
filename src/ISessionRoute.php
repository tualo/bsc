<?php

namespace Tualo\Office\Basic;

interface ISessionRoute
{
    public static function scope(): string;
    public static function register();
}
