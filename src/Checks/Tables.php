<?php

namespace Tualo\Office\BSC\Checks;

use Tualo\Office\Basic\Middleware\Session;
use Tualo\Office\Basic\PostCheck;
use Tualo\Office\Basic\TualoApplication as App;


class Tables  extends PostCheck
{

    public static function testSessionDB(array $config)
    {
        $tables = [
            'oauth' => [
                'columns' => [
                    'id' => 'varchar(36)',
                    'client' => 'varchar(255)',
                    'username' => 'varchar(255)',
                    'create_time' => 'datetime',
                    'validuntil' => 'datetime',
                    'lastcontact' => 'datetime',
                    'singleuse' => 'tinyint(4)',
                    'name' => 'varchar(255)',
                    'device' => 'varchar(255)'
                ]
            ],
            'oauth_path' => [
                'columns' => [
                    'id' => 'varchar(36)',
                    'path' => 'varchar(255)'
                ]
            ],
        ];
        self::tableCheck('bsc', $tables);
    }

    public static function test(array $config)
    {
        $tables = [
            'view_session_groups' => [
                'columns' => [
                    // 'group'=>'varchar(100)'
                ]
            ],
            'view_session_users' => [
                'columns' => [
                    // 'login'=>'varchar(100)',
                    'anzeigename' => 'text',
                    'telefon' => 'varchar(255)',
                    'zeichen' => 'varchar(255)',
                    'fax' => 'varchar(255)'
                ]
            ],
            'route_scopes' => [],
            'route_scopes_permissions' => [],
            'bsc_route_log' => []
        ];
        self::tableCheck('bsc', $tables);
    }
}
