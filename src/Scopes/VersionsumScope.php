<?php

namespace Tualo\Office\Basic\Scopes;

use Tualo\Office\Basic\Scope;

class VersionsumScope extends Scope
{
    protected static string $identifier = 'bsc.versionsum';
    protected static array $name = [
        'EN' => 'Version Summary',
        'DE' => 'Versionsübersicht',
    ];
    protected static array $description = [
        'EN' => 'Summarize versions',
        'DE' => 'Versionen zusammenfassen',
    ];
}
