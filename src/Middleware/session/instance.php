<?php
use tualo\Office\Basic\TualoApplication;
use tualo\Office\Basic\Session;

TualoApplication::use('TualoApplicationSessionInit',function(){
    try{
        TualoApplication::set('session',Session::getInstance());
    }catch(\Exception $e){
        TualoApplication::set('maintanceMode','on');
        TualoApplication::addError($e->getMessage());
    }
},$middlewareOrder,[],true);