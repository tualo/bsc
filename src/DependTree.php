<?php
namespace tualo\Office\Basic;

class DependTree{
    public $key;
    public $childs=array();
    public $parent;

    function __construct($key){
        $this->childs = array();
        $this->key = $key;
    }

    function &mergeChild($f){
        $element = new DependTree($f);
        $this->childs[] = $element;
        $element->parent = &$this;
        return $element;
    }

    function mergeChilds($newchilds){
        foreach($newchilds as $f){
            $this->mergeChild($f);
        }
    }

    function &find($key){
        if ($this->key == $key){
            return $this;
        }
        foreach ($this->childs as $child) {
            $item = $child->find($key);
            if ($item!==false){
                return $item;
            }
        }
        $r = false;
        return $r;
    
    }
    function childList(&$res){
        foreach ($this->childs as $child) {
            $child->childList($res);
        }
        $res[] = $this->key;
    }

    function debug(){
        foreach ($this->childs as $child) {
            $child->debug();
        }
        echo "debug: ".$this->key."\n";
    }

    function append($key,$dependson){
        $item = $this->find($key);
        if ($item!==false){
            $item->mergeChilds($dependson);
            return $this;
        }else{
            $ditem=false;
            foreach ($dependson as $dkey) {
                $ditem = $this->find($dkey);
                if ($ditem!==false){
                    break;
                }
            }
            if ($ditem!==false){
                if (is_null($ditem->parent)){
                    $element = new DependTree($key);
                    $element->childs[]=$ditem;
                    foreach($dependson as $d){
                        if ($d!==$ditem->key){
                            $element->mergeChild($d);
                        }
                    }
                    return $element;
                }else{
                    $element = new DependTree($key);
                    $element->parent = $ditem->parent;
                    $ditem->parent = $element;
                    $element->childs[]=$ditem;
                    foreach($dependson as $d){
                        if ($d!==$ditem->key){
                            $element->mergeChild($d);
                        }
                    }
                }
            }else{
                
                $element = $this->mergeChild($key);
                foreach($dependson as $d){
                    $element->mergeChild($d);
                }

            }
        }
        return $this;
    }
}
