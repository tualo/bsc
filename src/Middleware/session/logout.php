<?php
use Tualo\Office\Basic\TualoApplication;
/*
TualoApplication::use('TualoApplicationSession_Logout',function(){
    try{
        $session = TualoApplication::get('session');
        if (
                isset($_SESSION['tualoapplication']['loggedIn'])
            &&  ($_SESSION['tualoapplication']['loggedIn']===true)
            &&  (isset($_REQUEST['logout']))
            &&  ($_REQUEST['logout']==1)
            &&  (!is_null($session))
        ){
            TualoApplication::result('success',true);
            TualoApplication::result('msg','Bye');
            TualoApplication::contenttype('application/json');
            TualoApplication::end();
            $session->destroy();
            session_commit();
            exit();
        }
    }catch(\Exception $e){
        TualoApplication::set('maintanceMode','on');
        TualoApplication::addError($e->getMessage());
    }
},$middlewareOrder,[],true);
*/