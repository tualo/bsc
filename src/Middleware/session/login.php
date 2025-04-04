<?php

use Tualo\Office\Basic\TualoApplication;

TualoApplication::use('TualoApplicationSession_Login', function () {
    try {
        $session = TualoApplication::get('session');


        if (
            isset($_SESSION['tualoapplication']['loggedIn'])
            &&  (
                ($_SESSION['tualoapplication']['loggedIn'] === false)
                || (
                    isset($_REQUEST['forcelogin']) &&
                    $_REQUEST['forcelogin'] == 1
                )
            )
            &&  (isset($_REQUEST['username']))
            &&  (isset($_REQUEST['password']))
            &&  (!is_null($session))
        ) {

            TualoApplication::result('success', false);
            TualoApplication::result('msg', '');

            $hash = [];
            $hash['username'] = strtolower($_REQUEST['username']);
            $hash['password'] = ($_REQUEST['password']);
            $hash['mandant'] = strtolower((isset($_REQUEST['mandant']) ? $_REQUEST['mandant'] : (isset($_REQUEST['client']) ? $_REQUEST['client'] : '')));
            $hash['mandant'] = TualoApplication::configuration('', 'FORCE_CLIENT', $hash['mandant']);

            $sql = '
                SELECT
                    macc_users.login,
                    macc_users.passwd,
                    macc_users.typ,
                    concat(ifnull(loginnamen.vorname,"")," ",ifnull(loginnamen.nachname,"")) fullname,
                    test_login({username},{password}) pwresult,

                    macc_users_clients.client  db_name,
                    view_macc_clients.username db_user,
                    view_macc_clients.password db_pass,
                    view_macc_clients.host db_host,
                    view_macc_clients.port db_port 

                FROM
                    macc_users
                    join macc_users_clients 
                    on macc_users_clients.login = macc_users.login
                    join view_macc_clients 
                    on macc_users_clients.client = view_macc_clients.id
                    left join loginnamen 
                    on macc_users.login=loginnamen.login
                WHERE 
                    macc_users.login = {username}

                HAVING 
                    pwresult=1 
                    and (  macc_users_clients.client={mandant} or {mandant}=""  )

                LIMIT 1
            ';
            $row = $session->db->singleRow($sql, $hash);
            if (false !== $row) {

                TualoApplication::result('success', true);
                TualoApplication::result('msg', 'Login OK');


                $_SESSION['db']['db_host'] = $row['db_host'];
                $_SESSION['db']['db_user'] = $row['db_user'];
                $_SESSION['db']['db_pass'] = $row['db_pass'];
                $_SESSION['db']['db_port'] = $row['db_port'];
                $_SESSION['db']['db_name'] = $row['db_name'];

                // $_SESSION['redirect_url'] = isset($row['url'])?$row['url']:'./';

                $_SESSION['tualoapplication']['loggedIn'] = true;
                $_SESSION['tualoapplication']['loggedInType'] = 'login';

                $_SESSION['tualoapplication']['typ'] = $row['typ'];
                $_SESSION['tualoapplication']['username'] = $row['login'];
                if (function_exists('mb_convert_encoding')) {
                    $_SESSION['tualoapplication']['fullname'] = mb_convert_encoding($row['fullname'], 'UTF-8', 'UTF-8');
                } else {
                    $_SESSION['tualoapplication']['fullname'] = $row['fullname'];
                }
                $_SESSION['tualoapplication']['client'] = $row['db_name'];
                $_SESSION['tualoapplication']['clients'] = $session->db->direct('SELECT macc_users_clients.client FROM macc_users_clients join view_macc_clients on macc_users_clients.client = view_macc_clients.id WHERE macc_users_clients.login = {username}', $_SESSION['tualoapplication']);


                // Test DB Access
                if (is_null($session->getDB())) {
                    TualoApplication::result('success', false);
                    TualoApplication::result('msg', 'Fehler beim Zugriff auf die Datenbank (418)');
                    TualoApplication::logger('BSC')->error('Fehler beim Zugriff auf die Datenbank (418)');
                    $session->destroy();
                } else {
                    TualoApplication::result('fullname',    $_SESSION['tualoapplication']['fullname']);
                    TualoApplication::result('username',    $_SESSION['tualoapplication']['username']);
                    TualoApplication::result('client',      $_SESSION['tualoapplication']['client']);
                    TualoApplication::result('clients',     $_SESSION['tualoapplication']['clients']);
                    TualoApplication::result('dbaccess', true);
                }
            } else {
                TualoApplication::result('success', false);
                TualoApplication::result('msg', 'Anmeldung fehlerhaft');
            }

            TualoApplication::contenttype('application/json');
            TualoApplication::end();
            session_commit();
            exit();
        } else {
        }
    } catch (\Exception $e) {
        //echo $e->getMessage();

        TualoApplication::set('maintanceMode', 'on');
        TualoApplication::addError($e->getMessage());
    }
}, $middlewareOrder, [], true);
