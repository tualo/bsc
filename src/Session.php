<?php

namespace Tualo\Office\Basic;
use Tualo\Office\Basic\TualoApplication;


class Session{

    // THE only instance of the class
    private static $instance;
    public $db;
    public $clientdb;
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

    private function newDBByRow($row){
      
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
      session_start();
      
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
          $this->db = $this->newDBByRow($db_config);
        }catch(\Exception $e){
          TualoApplication::logger('BSC('.__FILE__.')')->error( $e->getMessage() );
          echo "Bitte richten Sie die Sitzungsdatenbank ein. *";
          exit();

        }
      }else{
        echo "Bitte richten Sie die Sitzungsdatenbank ein.";
        exit();
      }
      if (is_object($this->db)) $this->db->mysqli->set_charset('utf8');
    }

    public function getDB() {
      TualoApplication::logger('TualoApplication')->warning('getDB',[__FILE__]);
      if ($_SESSION['tualoapplication']['loggedIn']===false) return null;
      

      try{
        if (
                isset($_SESSION['db']['dbuser']) 
            /*&&  (!is_object($this->clientdb) || is_null($this->clientdb))*/
        ){

          $this->clientdb = $this->newDBByRow($_SESSION['db']);
        }
        if (is_object($this->clientdb)){

          $this->clientdb->mysqli->set_charset('utf8');
          $this->clientdb->execute_with_hash('set @sessionuser = {username}',$_SESSION['tualoapplication']);
          $this->clientdb->execute_with_hash('set @sessionuserfullname = {fullname}',$_SESSION['tualoapplication']);

          $this->db->execute_with_hash('set @sessionuser = {username}',$_SESSION['tualoapplication']);
          $this->db->execute_with_hash('set @sessionuserfullname = {fullname}',$_SESSION['tualoapplication']);

          if (isset($_SESSION['buchungskreis'])) $this->db->execute_with_hash('set @sessionbuchungskreis = {buchungskreis}',$_SESSION);
          if (isset($_SESSION['buchungskreis'])) $this->clientdb->execute_with_hash('set @sessionbuchungskreis = {buchungskreis}',$_SESSION);

          if (isset($_SESSION['geschaeftsstelle'])) $this->db->execute_with_hash('set @sessionoffice = {geschaeftsstelle}',$_SESSION);
          if (isset($_SESSION['geschaeftsstelle'])) $this->clientdb->execute_with_hash('set @sessionoffice = {geschaeftsstelle}',$_SESSION);
          
          if (isset($_SESSION['seniority'])) $this->db->execute_with_hash('set @sessionseniority = {seniority}',$_SESSION);
          if (isset($_SESSION['seniority'])) $this->clientdb->execute_with_hash('set @sessionseniority = {seniority}',$_SESSION);

          try{
            $this->clientdb->execute_with_hash('set @sessionbuchungskreis = getSessionCurrentBKR() ',$_SESSION);
          }catch(\Exception $e){ }
        
          try{
            $this->clientdb->execute_with_hash('set @sessionoffice = getSessionCurrentOffice() ',$_SESSION);
          }catch(\Exception $e){ }
        
          try{
            $this->clientdb->execute_with_hash('set @sessionseniority = getSessionCurrentSeniority() ',$_SESSION);
          }catch(\Exception $e){ }
          
          $this->clientdb->execute_with_hash('SET lc_time_names = {lc_time_name};',array('lc_time_name'=>'de_DE'));
          $this->clientdb->execute_with_hash('set @sessiondb = {sessiondb}',array('sessiondb'=>$this->db->dbname));

          $this->db->execute_with_hash('set @sessionuser = {username}',$_SESSION);
          $this->db->execute_with_hash('set @sessionuserfullname = {fullname}',$_SESSION);


        }
      }catch(\Exception $e){
        //echo $e->getMessage();
        TualoApplication::logger('TualoApplication')->error($e->getMessage(),$_SESSION['db']);
      }
      return $this->clientdb;
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

}

