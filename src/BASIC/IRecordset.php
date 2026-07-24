<?php

namespace Tualo\Office\Basic\BASIC;

interface IRecordset
{
    public function useDBTypes(bool $val): void;
    public function tinyIntAsBoolean(bool $value): bool;
    public function toHash(string $id = '', bool $utf8 = false, int $start = 0, int $limit = 999999999, bool $byName = false): array;
    public function toArray(string $key = '', bool $utf8 = false, int $start = 0, int $limit = 999999999, bool $byName = false): array;
    public function moveNext(): array | false;
    public function singleRow($utf8 = false): array | bool;
    public function fieldValue(string $field_name): mixed;
    public function directMap(string $statement, array $hash = [], string $key = '', string $value = ''): array;
    public function fieldName(int $n): string;
    public function rows(): int;
    public function fields(): int;
    public function fieldType(string $fieldName): string;
    public function unload(): void;
}
