<?php

namespace Tualo\Office\Basic;



class RouteSantizer
{
    /*
    $expected_inputs = [
        'name' => [
            'type' => 'string',
            
            'max_length' => 50,
            'pattern' => '/^[a-zA-ZäöüÄÖÜß\s\-]+$/u'  // nur Buchstaben, Leerzeichen, Bindestriche
        ],
        'age' => [
            'type' => 'int',
            'min' => 0,
            'max' => 120
        ],
        'email' => [
            'type' => 'email'
        ],
        'newsletter' => [
            'type' => 'bool'
        ]
    ];
    */

    public static function sanitize(
        array $input,
        array $expected_inputs,
        array &$sanitized = [],
        bool $errorCodeOnInvalid = true,
        bool $errorCodeOnUnexpected = true
    ): array {
        $sanitized = [];
        $errors = [];

        foreach ($expected_inputs as $key => $rules) {
            if (!isset($input[$key])) {
                if (isset($rules['required']) && $rules['required']) {
                    $errors[$key] = 'Feld ist erforderlich';
                }
                continue; // Feld ist nicht vorhanden, überspringen
            }

            $value = $input[$key];

            switch ($rules['type']) {
                case 'string':
                    if (!is_string($value)) {
                        $errors[$key] = 'Ungültiger Typ';
                        break;
                    }
                    $value = trim($value);
                    if (isset($rules['max_length']) && strlen($value) > $rules['max_length']) {
                        $errors[$key] = 'Zu lang';
                        break;
                    }
                    if (isset($rules['pattern']) && !preg_match($rules['pattern'], $value)) {
                        $errors[$key] = 'Ungültiges Format';
                        break;
                    }
                    $sanitized[$key] = $value;
                    break;

                case 'integer':
                case 'int':
                    if (filter_var($value, FILTER_VALIDATE_INT) === false) {
                        $errors[$key] = 'Keine gültige Zahl';
                        break;
                    }
                    $value = (int)$value;
                    if (($rules['min'] ?? PHP_INT_MIN) > $value || $value > ($rules['max'] ?? PHP_INT_MAX)) {
                        $errors[$key] = 'Zahl außerhalb des erlaubten Bereichs';
                        break;
                    }
                    $sanitized[$key] = $value;
                    break;

                case 'email':
                    if (!filter_var($value, FILTER_VALIDATE_EMAIL)) {
                        $errors[$key] = 'Ungültige E-Mail-Adresse';
                        break;
                    }
                    $sanitized[$key] = $value;
                    break;

                case 'bool':
                    // Erlaubt: true, false, '1', '0', 1, 0
                    $sanitized[$key] = filter_var($value, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
                    if (is_null($sanitized[$key])) {
                        $errors[$key] = 'Ungültiger Wahrheitswert';
                    }
                    break;
                case 'array':
                    if (!is_array($value)) {
                        $errors[$key] = 'Ungültiger Typ, erwartet ein Array';
                        break;
                    }
                    break;
                case 'array|string':
                    if (!is_array($value) && (!is_string($value))) {
                        $errors[$key] = 'Ungültiger Typ, erwartet ein Array';
                        break;
                    }
                    if (is_string($value)) {
                        $value = json_decode($value, true);
                        if (json_last_error() !== JSON_ERROR_NONE) {
                            $errors[$key] = 'Ungültiges JSON-Format';
                        }
                    }
                    break;

                default:
                    $errors[$key] = 'Unbekannter Typ';
            }
        }

        if (!empty($errors)) {
            if ($errorCodeOnInvalid) {
                http_response_code(400); // Bad Request
            }
            return $errors; // Rückgabe der Fehler
        }

        $unexpected = array_diff(array_keys($input), array_keys($expected_inputs));
        if (!empty($unexpected)) {

            if ($errorCodeOnUnexpected) {
                foreach ($unexpected as $key) {
                    $errors[$key] = 'Unerwartetes Feld (' . $key . ')';
                }
                http_response_code(400); // Bad Request
            }
            return $errors; // Rückgabe der unerwarteten Felder
        }

        // Alle Eingaben sind validiert und gesäubert
        return $errors; // des leere Array signalisiert Erfolg
    }
};
