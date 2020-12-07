<?php
use tualo\Office\Basic\TualoApplication;

TualoApplication::use('TualoApplicationSessionInitTemp',function(){
    try{
        if (isset($_SESSION['tualoapplication']['loggedIn'])&&($_SESSION['tualoapplication']['loggedIn']===true)){
            TualoApplication::set('sid',TualoApplication::get('session')->id());
            $path = TualoApplication::get('basePath').'/temp/'.TualoApplication::get('sid');
            TualoApplication::set('tempPath',$path);
            if(!file_exists($path)){ mkdir($path); }
        }
    }catch(\Exception $e){
        TualoApplication::set('maintanceMode','on');
        TualoApplication::addError($e->getMessage());
    }
},$middlewareOrder,[],true);

