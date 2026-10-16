<?php

namespace Tualo\Office\Basic\Scopes;

use Tualo\Office\Basic\Scope;

class BasicScope extends Scope
{
    private static string $identifier = 'basic';
    private static array $name = [
        'EN' => 'Basic',
        'DE' => 'Basis',
    ];
    private static array $description = [
        'EN' => 'Read your basic information.',
        'DE' => 'Deine Basisinformationen lesen.',
    ];
}
