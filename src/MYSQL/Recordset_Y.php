<?php

namespace Tualo\Office\Basic\MYSQL;

use Tualo\Office\Basic\TualoApplication;
use Amp\Mysql\MysqlResult;
use Amp\Mysql\MysqlStatement;

/**
 * Diese Klasse steuert Recordsets.
 *
 * @package basic
 * @subpackage classes
 */
class Recordset_Y
{

    public  $version;
    private $_version = '1.2.001';

    public $rs_ref;
    private $a_row;
    public $a_fields;
    public $a_info;
    private $row_pointer;
    private $row_count;
    private $ref;
    private $open;
    private $isFreed = false;
    private $dbTypes = true;
    private $_tinyIntAsBoolean = true;



    function map_field_type_to_bind_type($field_type)
    {
        switch ($field_type) {
            case MYSQLI_TYPE_DECIMAL:
            case MYSQLI_TYPE_NEWDECIMAL:
            case MYSQLI_TYPE_FLOAT:
            case MYSQLI_TYPE_DOUBLE:
                return 'd';

            case MYSQLI_TYPE_BIT:
                return 'x';
            case MYSQLI_TYPE_TINY:
                return (($this->_tinyIntAsBoolean) ? 'x' : 'i');
            case MYSQLI_TYPE_SHORT:
            case MYSQLI_TYPE_LONG:
            case MYSQLI_TYPE_LONGLONG:
            case MYSQLI_TYPE_INT24:
            case MYSQLI_TYPE_YEAR:
            case MYSQLI_TYPE_ENUM:
                return 'i';

            case MYSQLI_TYPE_TIMESTAMP:
            case MYSQLI_TYPE_DATE:
            case MYSQLI_TYPE_TIME:
            case MYSQLI_TYPE_DATETIME:
            case MYSQLI_TYPE_NEWDATE:
                // case MYSQLI_TYPE_INTERVAL:
            case MYSQLI_TYPE_SET:
            case MYSQLI_TYPE_VAR_STRING:
            case MYSQLI_TYPE_STRING:
            case MYSQLI_TYPE_CHAR:
            case MYSQLI_TYPE_GEOMETRY:
                return 's';

            case MYSQLI_TYPE_TINY_BLOB:
            case MYSQLI_TYPE_MEDIUM_BLOB:
            case MYSQLI_TYPE_LONG_BLOB:
            case MYSQLI_TYPE_BLOB:
                return 'b';

            default:
                return 's';
        }
    }

    function __construct(MysqlResult $ref, MysqlStatement $statement)
    {
        $this->row_count = $ref->getRowCount();
        $this->open = true;
        $fres = [];

        $columns = $statement->getColumnDefinitions();
        for ($i = 0; $i < count($columns); $i++) {
            $fres[strtolower($columns[$i]->getName())] = array(
                'type' => $columns[$i]->getType()->value,
                'table' => $columns[$i]->getTable(),
                'name' => $columns[$i]->getName(),
                'type_string' => $this->map_field_type_to_bind_type($columns[$i]->getType()->value),
                'max_length' => $columns[$i]->getLength(),
                'index' => $i
            );

            $fres[strtolower($columns[$i]->getName())] = array(
                'type' => $columns[$i]->getType()->value,
                'table' => $columns[$i]->getTable(),
                'name' => $columns[$i]->getName(),
                'type_string' => $this->map_field_type_to_bind_type($columns[$i]->getType()->value),
                'max_length' => $columns[$i]->getLength(),
                'index' => $i
            );
        }
        $this->a_fields = $fres;


        $this->ref  = $ref;
    }

    function tinyIntAsBoolean($val)
    {
        $this->_tinyIntAsBoolean = $val;
    }

    function useDBTypes($val)
    {
        $this->dbTypes = $val;
    }

    function __destruct()
    {
        /*
        if ($this->open) {
            $this->open = false;
            $this->ref->close();
        }*/
    }

    public function moveNext()
    {

        $res = $this->rs_ref = $this->ref->fetchRow();
        if ($res === false) {
            if (!$this->isFreed) {
                $this->isFreed = true;
            }
        }
        return $res;
    }

    public function singleRow($utf8 = false)
    {
        $rows = $this->toArray('', $utf8);
        $this->unload();
        if (count($rows) == 1) {
            return $rows[0];
        }
        return false;
    }

    public function toArray($id = '', $utf8 = false, $start = 0, $limit = 999999999, $byName = false)
    {
        $d = array();
        $i = 0;

        while ($this->moveNext()) {


            $ds = array();
            foreach ($this->a_fields as $fname => $x) {
                $cname = $fname;
                if ($byName) {
                    $cname = $x['name'];
                    /*
					if ($utf8){
						$ds[$cname] = utf8_encode($this->rs_ref[$x['index']]);
					}else{
						*/

                    if ($this->dbTypes) {
                        switch ($x['type_string']) {
                            case 'd':
                                $ds[$cname] = doubleval($this->rs_ref[$x['index']]);
                                break;
                            case 'x':
                                $ds[$cname] = boolval($this->rs_ref[$x['index']]);
                                break;
                            case 'i':
                                $ds[$cname] = intval($this->rs_ref[$x['index']]);
                                break;
                            default:
                                $ds[$cname] = $this->rs_ref[$x['index']];
                                break;
                        }
                    } else {
                        $ds[$cname] = $this->rs_ref[$x['index']];
                    }
                    // }
                } else {
                    /*
					if ($utf8){
						$ds[$cname] = utf8_encode($this->rs_ref[$x['index']]);
					}else{
					*/

                    if ($this->dbTypes) {

                        switch ($x['type_string']) {
                            case 'd':
                                $ds[$cname] = doubleval($this->rs_ref[$x['name']]);
                                break;
                            case 'x':
                                $ds[$cname] = boolval($this->rs_ref[$x['name']]);
                                break;
                            case 'i':
                                /*
                                if (!isset(($this->rs_ref[$x['index']]))) {
                                    echo 'Error: ' . $x['name'] . ' is not set in recordset';
                                    echo "\n";
                                    echo 'Error: ' . $x['index'] . ' is not set in recordset';
                                    echo "\n";
                                    echo 'Recordset: ';
                                    print_r($this->rs_ref);
                                    echo "\n";
                                    echo 'Recordset index: ' . $x['index'];
                                    echo "\n";
                                    exit();
                                }*/
                                $ds[$cname] = intval($this->rs_ref[$x['name']]);
                                break;
                            default:
                                if ($cname == 'daten') {
                                    echo $this->rs_ref[$x['name']] . "\n";
                                }
                                $ds[$cname] = $this->rs_ref[$x['name']];
                                break;
                        }
                    } else {
                        $ds[$cname] = $this->rs_ref[$x['name']];
                    }
                    //}
                }
            }
            if ($id != '') {
                $d[$ds[$id]] = $ds;
            } else {
                $d[] = $ds;
            }
        }
        TualoApplication::result('ddd', $d);
        return $d;
    }

    private function appendItem(&$data, &$ds, $ids)
    {
        $id = $ids[0];
        if (!isset($data[$ds[$id]])) {
            $data[$ds[$id]] = array();
        }
        if (count($ids) > 1) {
            return $this->appendItem($data[$ds[$id]], $ds, array_slice($ids, 1));
        } else {
            $data[$ds[$id]][] = $ds;
            //return $data[$ds[$id]];
        }
    }
    public function toHash($id = '', $utf8 = false, $start = 0, $limit = 999999999, $byName = false)
    {
        $d = array();
        $i = 0;
        while ($this->moveNext()) {
            if ($i >= $start) {
                if ($i - $start < $limit) {

                    $ds = array();
                    foreach ($this->a_fields as $fname => $x) {
                        $cname = $fname;
                        if ($byName) {
                            $cname = $x['name'];
                        }
                        /*
						if ($utf8){
							$ds[$cname] = utf8_encode($this->rs_ref[$x['index']]);
						}else{
							*/
                        if ($this->dbTypes) {
                            switch ($x['type_string']) {
                                case 'd':
                                    $ds[$cname] = doubleval($this->rs_ref[$x['index']]);
                                    break;
                                case 'b':
                                    $ds[$cname] = boolval($this->rs_ref[$x['index']]);
                                    break;
                                case 'i':
                                    $ds[$cname] = intval($this->rs_ref[$x['index']]);
                                    break;
                                default:
                                    $ds[$cname] = $this->rs_ref[$x['index']];
                                    break;
                            }
                        } else {
                            $ds[$cname] = $this->rs_ref[$x['index']];
                        }
                        // }
                    }
                    if ($id != '') {
                        if (is_array($id)) {
                            $item = $this->appendItem($d, $ds, $id);
                        } else {

                            if (!isset($d[$ds[$id]])) {
                                $d[$ds[$id]] = array();
                            }
                            $d[$ds[$id]][] = $ds;
                        }
                    } else {
                        $d[] = $ds;
                    }
                }
            }
            $i++;
        }
        return $d;
    }

    public function fieldValue($field_name)
    {
        $field_name = strtolower($field_name);
        $value = '';
        if (isset($this->a_fields[($field_name)])) {
            $type = $this->a_fields[($field_name)]["type"];
            $index = $this->a_fields[($field_name)]["index"];
            $value = $this->rs_ref[$index];
            //echo $value;exit();
            if (($type == "FLOAT") || ($type == "DOUBLE")) {
                $value = doubleval($value);
            }
        }
        return $value;
    }

    public function fieldName($n)
    {
        return $this->a_info[$n]->name;
    }
    public function rows()
    {
        return $this->row_count;
    }
    public function fields()
    {
        return count($this->a_fields);
    }
    public function LongReadLen($n)
    {
        // odbc_longreadlen($this->rs_ref,$n);
    }

    public function fieldType($fieldName)
    {
        return $this->a_fields[$fieldName]["type"];
    }

    public function unload()
    {
        if ($this->open) {
            $this->open = false;
            if (!$this->isFreed) {
                $this->isFreed = true;
            }
            //$this->ref->close();
        }
    }
}
