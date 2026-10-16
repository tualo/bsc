<?php

namespace Tualo\Office\Basic\Scopes;

use Tualo\Office\Basic\Scope;

class RegisterClientScope extends Scope
{
    private static string $identifier = 'bsc.registerclient';
    private static array $name = [
        'EN' => 'Register Client',
        'DE' => 'Client registrieren',
    ];
    private static array $description = [
        'EN' => 'Create a client token',
        'DE' => 'Einen Client-Token erstellen',
    ];
}
