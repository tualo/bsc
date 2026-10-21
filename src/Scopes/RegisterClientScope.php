<?php

namespace Tualo\Office\Basic\Scopes;

use Tualo\Office\Basic\Scope;

class RegisterClientScope extends Scope
{
    protected static string $identifier = 'bsc.registerclient';
    protected static array $name = [
        'EN' => 'Register Client',
        'DE' => 'Client registrieren',
    ];
    protected static array $description = [
        'EN' => 'Create a client token',
        'DE' => 'Einen Client-Token erstellen',
    ];
}
