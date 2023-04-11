<?php
use Tualo\Office\Basic\TualoApplication;

TualoApplication::use('TualoApplicationSession_Auth',function(){
    try{
        $session = TualoApplication::get('session');



        if (
                isset($_SESSION['tualoapplication']['loggedIn'])
            &&  ($_SESSION['tualoapplication']['loggedIn']===false)

            &&  (!is_null($session))
        ){
            //if (is_null($session->db)) throw new \Exception("Session DB not loaded");
            $path = '';
            $method = $_SERVER['REQUEST_METHOD'];
            $parsed_url = parse_url($_SERVER['REQUEST_URI']);//Parse Uri
            if(isset($_SERVER['REDIRECT_URL'])) $parsed_url = parse_url($_SERVER['REDIRECT_URL']);
            if(isset($parsed_url['path'])){ $path = $parsed_url['path']; }else{ $path = '/'; }
    
            if(preg_match('#/~/(?P<oauth>\w+)/*#',$path,$matches)){
                $_SESSION['tualoapplication']['oauth'] = $matches['oauth'];
                if (isset($_SERVER['REDIRECT_URL'])){
                    $_SERVER['REQUEST_URI']=str_replace('/~/'.$matches['oauth'].'/','/',$_SERVER['REDIRECT_URL']);
                    unset($_SERVER['REDIRECT_URL']);
                }else{
                    $_SERVER['REQUEST_URI']=str_replace('/~/'.$matches['oauth'].'/','/',$_SERVER['REQUEST_URI']);
                }
                
                    
                $session->inputToRequest();
                $token = $matches['oauth'];
                $_SESSION['session_condition']=array();
                $session->db->direct('delete from oauth where validuntil<now()');
                $session->db->direct('delete from oauth where singleuse=1');
                
            
                $result = array();
                $result['msg'] = '';
                $result['success'] = false;
                $hash = array();

                $sql = '
                select

                    oauth.id,
                    oauth.client dbname,
                    oauth.username, 
                    concat(loginnamen.vorname,\' \',loginnamen.nachname) fullname,
                    view_macc_clients.username dbuser,
                    view_macc_clients.password dbpass,
                    view_macc_clients.host dbhost,
                    view_macc_clients.port dbport,
                    macc_users.typ,
                    macc_users.login login
            
                from
                    oauth
                    join macc_users_clients
                        on    
                            oauth.client = macc_users_clients.client
                        and oauth.username = macc_users_clients.login
                    join view_macc_clients
                        on 
                            oauth.client =view_macc_clients.id
                    join loginnamen 
                        on 
                            oauth.username = loginnamen.login
                    join macc_users 
                            on macc_users.login = loginnamen.login
                where
                    oauth.id = {id}
                    and (validuntil>=now() or validuntil is null)
            
                union 
            
                    select
                        oauth.id,
                        macc_users_clients.client dbname,
                        oauth.username,
                        concat(loginnamen.vorname,\' \',loginnamen.nachname) fullname, 
                        view_macc_clients.username dbuser,
                        view_macc_clients.password dbpass,
                        view_macc_clients.host dbhost,
                        view_macc_clients.port dbport,
                        macc_users.typ,
                        macc_users.login login
            
                    from
                        oauth
                        join macc_users_clients
                            on  oauth.username = macc_users_clients.login
                        join view_macc_clients

                            on macc_users_clients.client =view_macc_clients.id
                        join loginnamen 
                            on oauth.username = loginnamen.login
                        join macc_users 
                            on macc_users.login = loginnamen.login
                    where
                        oauth.id = {id}
                        and oauth.client = \'*\'
                        and (validuntil>=now()
                            or validuntil is null)
            
                ';
                $row = $session->db->singleRow($sql,['id'=>$token]);
                if ($row!==false){
                    $path = $session->db->singleValue('select path from oauth_path where id = {id} ',array('id'=>$token),'path');
                    if ($path!==false){
                        $uri = $_SERVER['REQUEST_URI'];
                        //if (isset($_SERVER['REDIRECT_URL'])) $uri = $_SERVER['REDIRECT_URL'];
                        if (strpos($uri,'?')!==false){
                            $p = explode('?',$uri);
                            $uri = $p[0];
                        };
                    }
                    if (substr($path,strlen($path)-1,1)=='*'){
                        if ( strpos($uri,TualoApplication::get('requestPath').substr($path,0,strlen($path)-1))===0  ){
                            $byPath = true;
                            $_SESSION['session_condition']['path']=TualoApplication::get('requestPath').$path;
                        }
                    }
                    if ( ($uri==TualoApplication::get('requestPath').$path) ){
                        $byPath = true;
                        $_SESSION['session_condition']['path']=TualoApplication::get('requestPath').$path;
                    }

                    
                    $_SESSION['db']['dbhost'] = $row['dbhost'];
                    $_SESSION['db']['dbuser'] = $row['dbuser'];
                    $_SESSION['db']['dbpass'] = $row['dbpass'];
                    $_SESSION['db']['dbport'] = $row['dbport'];
                    $_SESSION['db']['dbname'] = $row['dbname'];
                    
                    $_SESSION['tualoapplication']['loggedIn'] = true;
                    $_SESSION['tualoapplication']['typ'] = $row['typ'];
                    $_SESSION['tualoapplication']['username'] = $row['login'];
                    $_SESSION['tualoapplication']['fullname'] = $row['fullname'];
                    $_SESSION['tualoapplication']['client'] = $row['dbname'];
                    $_SESSION['tualoapplication']['clients'] = $session->db->direct('SELECT macc_users_clients.client FROM macc_users_clients join view_macc_clients on macc_users_clients.client = view_macc_clients.id WHERE macc_users_clients.login = {username}',$_SESSION['tualoapplication']);

                    
                    // Test DB Access
                    if ( is_null( $session->getDB() ) ){
                        TualoApplication::result('success',false);
                        TualoApplication::result('msg','Felher beim Zugriff auf die Datenbank');
                        TualoApplication::logger('BSC')->error('Felher beim Zugriff auf die Datenbank (client db)');
                        $session->destroy();
                    }else{
                        TualoApplication::result('fullname',    $_SESSION['tualoapplication']['fullname']);
                        TualoApplication::result('username',    $_SESSION['tualoapplication']['username']);
                        TualoApplication::result('client',      $_SESSION['tualoapplication']['client']);
                        TualoApplication::result('clients',     $_SESSION['tualoapplication']['clients']);
                        TualoApplication::result('dbaccess',true);

                        TualoApplication::result('success',true);
                        TualoApplication::logger('BSC')->debug('Login '.$_SESSION['tualoapplication']['username'].' ');
                        TualoApplication::result('msg','Login OK');
        
                    }
        
                }else{
                    TualoApplication::result('success',false);
                    TualoApplication::result('msg','Anmeldung fehlerhaft');
                }

                //TualoApplication::contenttype('application/json');
                //TualoApplication::end();
                session_commit();
                //exit();
            }
        }elseif (
                isset($_SESSION['tualoapplication']['loggedIn'])
            &&  ($_SESSION['tualoapplication']['loggedIn']===true)
            &&  isset($_SESSION['tualoapplication']['oauth'])
            &&  (!is_null($session))
        ){

            if (isset($_SERVER['REDIRECT_URL'])){
                $_SERVER['REQUEST_URI']=str_replace('/~/'.$_SESSION['tualoapplication']['oauth'].'/','/',$_SERVER['REDIRECT_URL']);
                unset($_SERVER['REDIRECT_URL']);
            }else{
                $_SERVER['REQUEST_URI']=str_replace('/~/'.$_SESSION['tualoapplication']['oauth'].'/','/',$_SERVER['REQUEST_URI']);
            }

        }
    }catch(\Exception $e){
        TualoApplication::set('maintanceMode','on');
        TualoApplication::addError($e->getMessage());
    }
},$middlewareOrder,[],true);

