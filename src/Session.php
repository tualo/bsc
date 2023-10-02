<?php

namespace Tualo\Office\Basic;
use Tualo\Office\Basic\TualoApplication;
use Ramsey\Uuid\Uuid;

class Session{

    // THE only instance of the class
    public static $client_db_instance;
    private static $instance;
    public $db;
    
    public $client;

    public static function getInstance(){
      if ( !isset(self::$instance)) {
          self::$instance = new self;
      }
      return self::$instance;
    }



    


    public function inputToRequest(){
      try{
          $postdata = file_get_contents("php://input");
          if (isset($postdata)) {
              $request = json_decode($postdata,true);
              if (!is_null($request)){
              $_REQUEST = array_merge($_REQUEST,$request);
              }
          }
      
      }catch(\Exception $e){
      }
    }

    public static function newDBByRow($row){
      
      $config = TualoApplication::get('configuration');
      if(isset($config["FORCE_DB_HOST"])) $row['dbhost']=$config["FORCE_DB_HOST"];
      if(isset($config["FORCE_DB_PORT"])) $row['dbport']=$config["FORCE_DB_PORT"];
      
      $row += [
        'sslkey'=>isset($config["__DB_SSL_KEY__"])?$config["__DB_SSL_KEY__"]:'',
        'sslcert'=>isset($config["__DB_SSL_CERT__"])?$config["__DB_SSL_CERT__"]:'',
        'sslca'=>isset($config["__DB_SSL_CA__"])?$config["__DB_SSL_CA__"]:''
      ];
          
      $db = new MYSQL\Database($row['dbuser'],$row['dbpass'],$row['dbname'],$row['dbhost'],$row['dbport'],$row['sslkey'],$row['sslcert'],$row['sslca']);
      return $db;
    }


    public function switchClient($client){
      $hash = [
        'username' => $_SESSION['tualoapplication']['username'],
        'client' => $client
      ];

      $sql = '
      SELECT
        view_macc_clients.*
      FROM macc_users_clients join view_macc_clients
        on macc_users_clients.client = view_macc_clients.id
      WHERE macc_users_clients.login = {username}
        and macc_users_clients.client= {client}';
      
        $row = $this->db->singleRow($sql,$hash);
      if ($row!==false){

        @session_start(); 
        $_SESSION['db']['dbhost'] = $row['host'];
        $_SESSION['db']['dbuser'] = $row['username'];
        $_SESSION['db']['dbpass'] = $row['password'];
        $_SESSION['db']['dbport'] = $row['port'];
        $_SESSION['db']['dbname'] = $row['id'];

        
        $_SESSION['redirect_url'] = isset($row['url'])?$row['url']:'./';

        $_SESSION['tualoapplication']['client'] = $row['id'];
        
        session_commit();
      }else{
        throw new \Exception("No Access");
      }
    }
    
    private function __construct() {
      $is_web=http_response_code()!==FALSE;

      

      

      if ($is_web){
        session_start( );
      }

      
      $config = TualoApplication::get('configuration');
      
      if (!isset($_SESSION['db'])) $_SESSION['db']=[];
      if (!isset($_SESSION['tualoapplication'])) $_SESSION['tualoapplication']=[];
      if (!isset($_SESSION['tualoapplication']['loggedIn'])) $_SESSION['tualoapplication']['loggedIn']=false;

      if (
          ($_SESSION['tualoapplication']['loggedIn']===true) && 
          ($_SESSION['tualoapplication']['username']=='') && 
          ($_SESSION['tualoapplication']['client']=='')
      ){
        $_SESSION['tualoapplication']['loggedIn']=false;
      }

      if(
        isset($config["__SESSION_DSN__"]) &&
        isset($config["__SESSION_USER__"]) &&
        isset($config["__SESSION_PASSWORD__"]) &&
        isset($config["__SESSION_HOST__"]) &&
        isset($config["__SESSION_PORT__"])

      ){
        $db = null;
        $db_config = [
          'dbhost'=>$config["__SESSION_HOST__"],
          'dbpass'=>$config["__SESSION_PASSWORD__"],
          'dbuser'=>$config["__SESSION_USER__"],
          'dbname'=>$config["__SESSION_DSN__"],
          'dbport'=>$config["__SESSION_PORT__"]
        ];

        try{
          $this->db = self::newDBByRow($db_config);
        }catch(\Exception $e){
          TualoApplication::logger('BSC('.__FILE__.')')->error( $e->getMessage() );
          $is_web=http_response_code()!==FALSE;
          if ($is_web){
            echo "Bitte richten Sie die Sitzungsdatenbank ein. *";
            exit();
          }

        }
      }else{
        echo "*Bitte richten Sie die Sitzungsdatenbank ein.";
        exit();
      }
      if (is_object($this->db)) $this->db->mysqli->set_charset('utf8');
    }

    public function loginByToken($token){
      $session = $this;
      $_SESSION['session_condition']=array();
      $session->db->direct('delete from oauth where validuntil<now()');
      
  
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
          
          $_SESSION['tualoapplication']['loggedInType'] = 'oauth';

          $_SESSION['tualoapplication']['loggedIn'] = true;
          $_SESSION['tualoapplication']['typ'] = $row['typ'];
          $_SESSION['tualoapplication']['username'] = $row['login'];
          $_SESSION['tualoapplication']['fullname'] = $row['fullname'];
          $_SESSION['tualoapplication']['client'] = $row['dbname'];
          $_SESSION['tualoapplication']['clients'] = $session->db->direct('SELECT macc_users_clients.client FROM macc_users_clients join view_macc_clients on macc_users_clients.client = view_macc_clients.id WHERE macc_users_clients.login = {username}',$_SESSION['tualoapplication']);

          
          // Test DB Access
          if ( is_null( $session->getDB() ) ){
              TualoApplication::result('success',false);
              TualoApplication::result('msg','Fehler beim Zugriff auf die Datenbank');
              TualoApplication::logger('BSC')->error('Fehler beim Zugriff auf die Datenbank (client db)');
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

      try{
          $session->db->direct('delete from oauth where singleuse=1 and id = {token}',['token'=>$token ]);
      }catch(\Exception $e){
          echo $e->getMessage();
          exit();
      }
      
    }

    public function getDB() {
      if ($_SESSION['tualoapplication']['loggedIn']===false) return null;
      

      TualoApplication::timing("session getDB");
      $clientdb = null;
      try{
        if (
            isset($_SESSION['db']['dbuser']) 
            &&  (is_null(self::$client_db_instance) )
        ){
          TualoApplication::timing("session new by row");
          TualoApplication::logger('TualoApplication')->info('getDB new',[__FILE__]);
          self::$client_db_instance = self::newDBByRow($_SESSION['db']);
        }
        if (is_object( self::$client_db_instance )){
          TualoApplication::timing("session getDB existing");
          $clientdb =  self::$client_db_instance;
          $clientdb->mysqli->set_charset('utf8');
          $clientdb->execute_with_hash('set @sessionuser = {username}',$_SESSION['tualoapplication']);
          $clientdb->execute_with_hash('set @sessionuserfullname = {fullname}',$_SESSION['tualoapplication']);

          $this->db->execute_with_hash('set @sessionuser = {username}',$_SESSION['tualoapplication']);
          $this->db->execute_with_hash('set @sessionuserfullname = {fullname}',$_SESSION['tualoapplication']);

          if (isset($_SESSION['buchungskreis'])) $this->db->execute_with_hash('set @sessionbuchungskreis = {buchungskreis}',$_SESSION);
          if (isset($_SESSION['buchungskreis'])) $clientdb->execute_with_hash('set @sessionbuchungskreis = {buchungskreis}',$_SESSION);

          if (isset($_SESSION['geschaeftsstelle'])) $this->db->execute_with_hash('set @sessionoffice = {geschaeftsstelle}',$_SESSION);
          if (isset($_SESSION['geschaeftsstelle'])) $clientdb->execute_with_hash('set @sessionoffice = {geschaeftsstelle}',$_SESSION);
          
          if (isset($_SESSION['seniority'])) $this->db->execute_with_hash('set @sessionseniority = {seniority}',$_SESSION);
          if (isset($_SESSION['seniority'])) $clientdb->execute_with_hash('set @sessionseniority = {seniority}',$_SESSION);

          try{
            $clientdb->execute_with_hash('set @sessionbuchungskreis = getSessionCurrentBKR() ',$_SESSION);
          }catch(\Exception $e){ }
        
          try{
            $clientdb->execute_with_hash('set @sessionoffice = getSessionCurrentOffice() ',$_SESSION);
          }catch(\Exception $e){ }
        
          try{
            $clientdb->execute_with_hash('set @sessionseniority = getSessionCurrentSeniority() ',$_SESSION);
          }catch(\Exception $e){ }
          
          $clientdb->execute_with_hash('SET lc_time_names = {lc_time_name};',array('lc_time_name'=>'de_DE'));
          $clientdb->execute_with_hash('set @sessiondb = {sessiondb}',array('sessiondb'=>$this->db->dbname));

          $this->db->execute_with_hash('set @sessionuser = {username}',$_SESSION);
          $this->db->execute_with_hash('set @sessionuserfullname = {fullname}',$_SESSION);


        }
      }catch(\Exception $e){
        TualoApplication::logger('TualoApplication')->error($e->getMessage(),$_SESSION['db']);
      }
      return $clientdb;
    }

    public function id() {
      return session_id();
    }

    public function destroy() {
      $_SESSION['db']=[];
      $_SESSION['tualoapplication']=[];
      $_SESSION['tualoapplication']['loggedInType'] = '';
      $_SESSION['tualoapplication']['typ'] = '';
      $_SESSION['tualoapplication']['username'] = '';
      $_SESSION['tualoapplication']['fullname'] = '';
      $_SESSION['tualoapplication']['client'] = '';
      $_SESSION['tualoapplication']['clients'] = '';
      $_SESSION['tualoapplication']['loggedIn'] = false;
      $_SESSION['session_condition']=[];

      return true;
    }




    /**
     * OAuth
     * 
     */


    public function oauthValidUntil($token,$validUntil){
      // alter table oauth add validuntil datetime default null;
      $this->db->direct('update oauth set validuntil={validuntil} where id={token}',array('token'=>$token,'validuntil'=>$validUntil));
    }

    public function oauthSingleUse($token){
      // alter table oauth add validuntil datetime default null;
      $this->db->direct('update oauth set singleuse=1 where id={token}',array('token'=>$token ));
    }

    public function oauthValidDays($token,$days){
      // alter table oauth add validuntil datetime default null;
      $this->db->direct('update oauth set validuntil=date_add(current_date,interval {days} day) where id={token}',array('token'=>$token,'validuntil'=>$days));
    }


    public function registerOAuth($params=array(),$force=false,$anyclient=false,$path=''){
        if ($force!==true){
          $test = array();
          foreach( $params as $key=>$value){
            $test[]=$key.'='.$value;
          }
          sort($test);
          if (count($test)==0){
            throw new \Exception("registerOAuth needs at least cmp parameter", 1);
          }
          
          if ($anyclient){
            $sql  = '
            select
              oauth.id,
              oauth.client
            from
              (select id,group_concat( concat(param,\'=\',property) order by concat(param,\'=\',property) asc separator \',\') p from oauth_resources_property group by id having p={p}) a
              join oauth on a.id=oauth.id
            where
              client=\'*\' and
              username={username}
            ';
            $list = $this->db->direct($sql,array('p'=>implode(',',$test) ));

          }else{
            $sql  = '
            select
              oauth.id,
              oauth.client
            from
              (select id,group_concat( concat(param,\'=\',property) order by concat(param,\'=\',property) asc separator \',\') p from oauth_resources_property group by id having p={p}) a
              join oauth on a.id=oauth.id
            where
              client={client} and
              username{username}
            ';
            $list = $this->db->direct($sql,array('p'=>implode(',',$test) ,
            'client'=>$_SESSION['tualoapplication']['client'],
            'username'=>$_SESSION['tualoapplication']['username']
            ));
          }
          
          if (count($list)>0){
            $token=$list[0]['id'];
          }else{
            $force=true;
          }
        }

        if ($force==true){
          $token = (Uuid::uuid4())->toString();

          $sql = 'insert into oauth (id,client,username) values ({id},{client},{username}) ';
          if ($anyclient){
            $oauth = $this->db->direct($sql,array('id'=>$token,'client'=>'*' ));
          }else{
            $oauth = $this->db->direct($sql,array('id'=>$token,
            'client'=>$_SESSION['tualoapplication']['client'],
            'username'=>$_SESSION['tualoapplication']['username'] ));
          
          }

          if ($path!=''){

            $this->db->direct('create table if not exists oauth_path (id varchar(32) primary key, path varchar(255), CONSTRAINT `fk_oauth_path_id` FOREIGN KEY (`id`) REFERENCES `oauth` (`id`) ON DELETE CASCADE ON UPDATE CASCADE ) ');

            $this->db->direct('insert into oauth_path (id,path) values ({id},{path}) on duplicate key update path=values(path) ',array('path'=>$path,'id'=> $token));
          
          }

          foreach( $params as $key=>$value){
            $this->registerOAuthParam($token,$key,$value);
          }
        }
      
      return $token;
    }

    public function registerOAuthParam($token,$param,$property){

      $sql = 'insert into oauth_resources (id,param) values ({id},{param}) on duplicate key update param=values(param)';
      $this->db->direct($sql,array('id'=>$token,'param'=>$param));

      $sql = 'insert into oauth_resources_property (id,param,property) values ({id},{param},{property}) on duplicate key update property=values(property)';
      $this->db->direct($sql,array('id'=>$token,'param'=>$param,'property'=>$property));

      return true;
    }

    public function getHeader($hkey){
      $is_web=http_response_code()!==FALSE;
      $headers=[];
      if ($is_web) $headers = getallheaders();

      foreach($headers as $key=>$val){
        if ($hkey==$key){
          return $val;
        }
      }
      return false;
    }


    public function changeToken($token=''){
      if ($token==''){
        $token = $this->getHeader('Authorization');
      }
      $newtoken = (Uuid::uuid4())->toString();
      $this->db->direct('update oauth set id = {newtoken} where id={oldtoken} ',array('newtoken'=>$newtoken,'oldtoken'=>$token));
      return $newtoken;
    }

    public function setOauthForcedValues($token='',$value=''){
      $def = $this->db->direct('explain oauth_resources_property',array(),'field');
      if (!isset($def['forcedvalue'])){
        $this->db->direct('alter table oauth_resources_property add forcedvalue tinyint default 0');
      }
      $this->db->direct('update oauth_resources_property set forcedvalue = {value} where id={token} ',array('token'=>$token,'value'=>$value));
      return true;
    }

}

