<?php

namespace Tualo\Office\Basic;

use Tualo\Office\Basic\TualoApplication;
use Tualo\Office\Basic\Route as R;
use Tualo\Office\Basic\IRoute;

class RouteSecurityHelper
{
    /**
     * Sicherer File-Handler für statische Assets
     * 
     * @param string $requestedFile Der angeforderte Dateipfad
     * @param string $baseDir Das Basis-Verzeichnis (relativ zum Projekt)
     * @param array $allowedExtensions Erlaubte Dateierweiterungen
     * @param array $contentTypes Content-Type Mapping für Erweiterungen
     * @return bool True wenn Datei sicher ausgeliefert wurde, false bei Fehler
     */
    public static function serveSecureStaticFile(
        string $requestedFile,
        string $baseDir,
        array $allowedExtensions = ['js', 'css', 'map'],
        array $contentTypes = [
            'js' => 'application/javascript',
            'css' => 'text/css',
            'map' => 'application/json'
        ]
    ): bool {
        // 1. Path Traversal Schutz
        if (!self::isSecurePath($requestedFile)) {
            http_response_code(404);
            return false;
        }

        // 2. Sichere Pfad-Auflösung
        $safePath = self::resolveSafePath($requestedFile, $baseDir);
        if (!$safePath) {
            http_response_code(404);
            return false;
        }

        // 3. Datei-Validierung und Auslieferung
        return self::validateAndServeFile($safePath, $allowedExtensions, $contentTypes);
    }

    /**
     * Prüft ob ein Pfad sicher ist (kein Path Traversal)
     */
    private static function isSecurePath(string $file): bool
    {
        // URL-Decoding für versteckte Traversal-Versuche
        $decodedFile = urldecode($file);

        return !(
            strpos($file, '..') !== false ||
            strpos($file, './') !== false ||
            strpos($file, '\\') !== false ||
            strpos($decodedFile, '..') !== false ||
            // Zusätzliche Sicherheitsprüfungen
            strpos($file, chr(0)) !== false || // Null-Byte (falls Regex umgangen)
            preg_match('/[^a-zA-Z0-9\-_\/\.]/', $file) // Strikte Zeichen-Validierung
        );
    }

    /**
     * Löst Pfad sicher auf und prüft ob er im erlaubten Bereich liegt
     */
    private static function resolveSafePath(string $file, string $baseDir): ?string
    {
        // Basis-Pfad auflösen
        $basePath = realpath($baseDir);
        if (!$basePath) {
            return null;
        }

        // Vollständigen Pfad auflösen
        $fullPath = realpath($basePath . DIRECTORY_SEPARATOR . $file);

        // Prüfen ob Pfad im erlaubten Bereich liegt
        if (!$fullPath || strpos($fullPath, $basePath . DIRECTORY_SEPARATOR) !== 0) {
            return null;
        }

        return $fullPath;
    }

    /**
     * Validiert Datei und liefert sie aus
     */
    private static function validateAndServeFile(
        string $fullPath,
        array $allowedExtensions,
        array $contentTypes
    ): bool {
        if (!file_exists($fullPath) || !is_file($fullPath)) {
            http_response_code(404);
            return false;
        }

        $pathInfo = pathinfo($fullPath);
        $extension = strtolower($pathInfo['extension'] ?? '');

        if (!in_array($extension, $allowedExtensions)) {
            http_response_code(404);
            return false;
        }

        // Content-Type setzen
        if (isset($contentTypes[$extension])) {
            TualoApplication::contenttype($contentTypes[$extension]);
        }

        // Datei ausliefern
        TualoApplication::etagFile($fullPath);
        return true;
    }
}
