<?php

namespace Tualo\Office\Basic\Scopes;

use Tualo\Office\Basic\Scope;

class BasicScope extends Scope
{
    protected static string $identifier = 'basic';
    protected static array $name = [
        'EN' => 'Basic',
        'DE' => 'Basis',
    ];
    protected static array $description = [
        'EN' => 'Read your basic information.',
        'DE' => 'Deine Basisinformationen lesen.',
    ];
}
