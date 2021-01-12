<?php
use Tualo\Office\Basic\TualoApplication;
use Tualo\Office\Basic\TualoDBSessionHandler;

TualoApplication::use('TualoApplicationSessionHandler',function(){
    if (defined('__USE_DB_SESSION_HANLDER__')){
        if (__USE_DB_SESSION_HANLDER__==1){
            session_set_save_handler(new TualoDBSessionHandler(), true);
        }
    }
},$middlewareOrder,[],true);

