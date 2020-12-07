<?php
use tualo\Office\Basic\TualoApplication;
use tualo\Office\Basic\TualoDBSessionHandler;

TualoApplication::use('TualoApplicationSessionHandler',function(){
    if (defined('__USE_DB_SESSION_HANLDER__')){
        if (__USE_DB_SESSION_HANLDER__==1){
            session_set_save_handler(new TualoDBSessionHandler(), true);
        }
    }
},$middlewareOrder,[],true);

