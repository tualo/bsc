<?php

namespace Tualo\Office\Basic;

use InvalidArgumentException;


class Path
{

    const CHAR_FORWARD_SLASH = 47;
    const CHAR_BACKWARD_SLASH = 92;
    const CHAR_DOT = 46;
    const CHAR_COLON = 58;

    public static function join(...$paths): string
    {
        $pathsNum = sizeof($paths);

        if ($pathsNum === 0) {
            return '.';
        }

        $joined = null;
        for ($i = 0; $i < $pathsNum; ++$i) {
            $arg = $paths[$i];

            if (!is_string($arg)) {
                throw new InvalidArgumentException(
                    'All paths passed to the join() method must be strings'
                );
            }

            if (strlen($arg) > 0) {
                if (is_null($joined)) {
                    $joined = $arg;
                } else {
                    $joined .= "/$arg";
                }
            }
        }
        if (is_null($joined)) {
            return '.';
        }

        return static::normalize($joined);
    }

    public static function normalize(string $path): string
    {
        if (strlen($path) === 0) {
            return '.';
        }

        $isAbsolute = ord($path) === static::CHAR_FORWARD_SLASH;
        $trailingSeparator = ord($path[strlen($path) - 1]) === static::CHAR_FORWARD_SLASH;

        // Normalize the path
        $path = static::normalizeString($path, !$isAbsolute);

        if (strlen($path) === 0) {
            if ($isAbsolute) {
                return '/';
            }
            return $trailingSeparator ? './' : '.';
        }
        if ($trailingSeparator) {
            $path .= '/';
        }

        return $isAbsolute ? "/$path" : $path;
    }

    public static function getSeparator(): string
    {
        return '/';
    }

    /**
     * {@inheritdoc}
     */
    public static function isAbsolute(string $path): bool
    {
        return strlen($path) > 0 && ord($path) === static::CHAR_FORWARD_SLASH;
    }

    protected static function isPosixPathSeparator(int $code): bool
    {
        return $code === static::CHAR_FORWARD_SLASH;
    }

    /**
     * {@inheritdoc}
     */
    protected static function isPathSeparator(int $code): bool
    {
        return static::isPosixPathSeparator($code);
    }

    protected static function normalizeString(string $path, bool $allowAboveRoot): string
    {
        $res = '';
        $lastSegmentLength = 0;
        $lastSlash = -1;
        $dots = 0;
        $code = 0;

        $pathLength = strlen($path);

        for ($i = 0; $i <= $pathLength; ++$i) {
            if ($i < $pathLength) {
                $code = ord($path[$i]);
            } elseif (static::isPathSeparator($code)) {
                break;
            } else {
                $code = static::CHAR_FORWARD_SLASH;
            }

            if (static::isPathSeparator($code)) {
                if ($lastSlash === $i - 1 || $dots === 1) {
                    // NOOP
                } elseif ($dots === 2) {
                    if (
                        strlen($res) < 2 ||
                        $lastSegmentLength !== 2 ||
                        ord($res[-1]) !== static::CHAR_DOT ||
                        ord($res[-2]) !== static::CHAR_DOT
                    ) {
                        if (strlen($res) > 2) {
                            $lastSlashIndex = strrpos($res, static::getSeparator());
                            if ($lastSlashIndex === false) {
                                $lastSlashIndex = -1;
                            }

                            if ($lastSlashIndex === -1) {
                                $res = '';
                                $lastSegmentLength = 0;
                            } else {
                                $res = static::slice($res, 0, $lastSlashIndex);
                                $newLastSlashIndex = strrpos($res, static::getSeparator());
                                if ($newLastSlashIndex === false) {
                                    $newLastSlashIndex = -1;
                                }

                                $lastSegmentLength =
                                    strlen($res) - 1 - $newLastSlashIndex;
                            }

                            $lastSlash = $i;
                            $dots = 0;
                            continue;
                        } elseif (strlen($res) !== 0) {
                            $res = '';
                            $lastSegmentLength = 0;
                            $lastSlash = $i;
                            $dots = 0;
                            continue;
                        }
                    }

                    if ($allowAboveRoot) {
                        $res .= strlen($res) > 0 ? static::getSeparator() . '..' : '..';
                        $lastSegmentLength = 2;
                    }
                } else {
                    if (strlen($res) > 0) {
                        $res .= static::getSeparator() . static::slice($path, $lastSlash + 1, $i);
                    } else {
                        $res = static::slice($path, $lastSlash + 1, $i);
                    }

                    $lastSegmentLength = $i - $lastSlash - 1;
                }

                $lastSlash = $i;
                $dots = 0;
            } elseif ($code === static::CHAR_DOT && $dots !== -1) {
                ++$dots;
            } else {
                $dots = -1;
            }
        }

        return $res;
    }

    /**
     * Slices a substring from a string given a start end end index, matches JavaScript's String.prototype.slice
     *
     * @param string       $value      The string to slice
     * @param integer      $startIndex The index to start at. May be negative to start relative to the end of the string.
     * @param integer|null $endIndex   The index to stop at. If omitted, the returned slice will end at the end of $value
     * @return string The sliced substring
     */
    protected static function slice(string $value, int $startIndex, ?int $endIndex = null): string
    {
        if (is_null($endIndex)) {
            return substr($value, $startIndex) ?: '';
        } else {
            return substr(
                $value,
                $startIndex,
                is_null($endIndex) ? null : ($endIndex - $startIndex)
            ) ?: '';
        }
    }
}
