<?php

declare(strict_types=1);

namespace Tualo\Office\Basic;

use Garden\Cli\Cli;
use Tualo\Office\Basic\TualoApplication;
use Tualo\Office\Basic\MYSQL\Database as Database;
use Ramsey\Uuid\Uuid;
use GuzzleHttp\Client;
use GuzzleHttp\Exception\ClientException;
use GuzzleHttp\Exception\ServerException;



class Notifications
{
    private static Notifications $instance;

    private static ?Database $_db = null;
    private static array $MESSAGES = [];


    public static function getInstance(): Notifications
    {
        if (!isset(self::$instance)) {
            self::$instance = new self;
        }
        return self::$instance;
    }



    public function db($db = null)
    {
        if (!is_null($db) && is_null(self::$_db)) {
            self::$_db = $db;
        }
        if (is_null(self::$_db)) {
            self::$_db = TualoApplication::get('session')->getDB();
        }

        return self::$_db;
    }

    public function addNotification(
        string $title,
        string $message,
        string $type = 'info',
        ?string $redirectUrl = null,

    ): void {
        self::$MESSAGES[] = [
            'title' => $title,
            'message' => $message,
            'type' => $type,
            'redirectUrl' => $redirectUrl
        ];
    }

    public function getNotifications(): array
    {
        return self::$MESSAGES;
    }
}
