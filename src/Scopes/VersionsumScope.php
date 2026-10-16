<?php

namespace Tualo\Office\Basic\Scopes;

use Tualo\Office\Basic\Scope;

class VersionsumScope extends Scope
{
    private static string $identifier = 'bsc.versionsum';
    private static array $name = [
        'EN' => 'Version Summary',
        'DE' => 'Versionsübersicht',
    ];
    private static array $description = [
        'EN' => 'Summarize versions',
        'DE' => 'Versionen zusammenfassen',
    ];
}
