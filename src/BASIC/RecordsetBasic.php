<?php

namespace Tualo\Office\Basic\BASIC;

class RecordsetBasic implements IRecordset
{
    public function useDBTypes(bool $val): void {}

    public function tinyIntAsBoolean(bool $value): bool
    {
        return false;
    }
    public function toHash(string $id = '', bool $utf8 = false, int $start = 0, int $limit = 999999999, bool $byName = false): array
    {
        return [];
    }
    public function toArray(string $key = '', bool $utf8 = false, int $start = 0, int $limit = 999999999, bool $byName = false): array
    {
        return [];
    }
    public function moveNext(): array | false
    {
        return false;
    }
    public function singleRow($utf8 = false): array | bool
    {
        return false;
    }
    public function fieldValue(string $field_name): mixed
    {
        return null;
    }
    public function directMap(string $statement, array $hash = [], string $key = '', string $value = ''): array
    {
        return [];
    }
    public function fieldName(int $n): string
    {
        return '';
    }
    public function rows(): int
    {
        return 0;
    }
    public function fields(): int
    {
        return 0;
    }
    public function fieldType(string $fieldName): string
    {
        return '';
    }
    public function unload(): void {}
}
