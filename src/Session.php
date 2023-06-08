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


    private function __construct() {
      $is_web=http_response_code()!==FALSE;
      if ($is_web){
        session_start();
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
        //echo $e->getMessage();
        TualoApplication::logger('TualoApplication')->error($e->getMessage(),$_SESSION['db']);
      }
      /*
      if (is_null($clientdb)){
        $this->destroy();
        return false;
      }
      */
      return $clientdb;
    }

    public function id() {
      return session_id();
    }

    public function destroy() {
      $_SESSION['db']=[];
      $_SESSION['tualoapplication']=[];
      $_SESSION['tualoapplication']['loggedIn'] = false;
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
      try{
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
    }catch(\Exception $e){
      echo $this->db->last_sql;
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
      $headers =  getallheaders();

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

