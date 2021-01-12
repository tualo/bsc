<?php

namespace Tualo\Office\Basic;


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
      
      }catch(Execption $e){
      }
    }

    private function newDBByRow($row){
      if (defined('__DB_SSL_KEY__')&&defined('__DB_SSL_CERT__')&&defined('__DB_SSL_CA__')){
        return new MYSQL\Database($row['dbuser'],$row['dbpass'],$row['dbname'],$row['dbhost'],$row['dbport'],__DB_SSL_KEY__,__DB_SSL_CERT__,__DB_SSL_CA__);
      }
      return new MYSQL\Database($row['dbuser'],$row['dbpass'],$row['dbname'],$row['dbhost'],$row['dbport']);
    }


    private function __construct() {
      session_start();
      
      if (!isset($_SESSION['db'])) $_SESSION['db']=[];
      if (!isset($_SESSION['tualoapplication'])) $_SESSION['tualoapplication']=[];
      if (!isset($_SESSION['tualoapplication']['loggedIn'])) $_SESSION['tualoapplication']['loggedIn']=false;


      if(defined('__SESSION_DSN__')&&defined('__SESSION_USER__')&&defined('__SESSION_PASSWORD__')&&defined('__SESSION_HOST__')&&defined('__SESSION_PORT__')){
        $this->db = $this->newDBByRow([
          'dbhost'=>__SESSION_HOST__,
          'dbpass'=>__SESSION_PASSWORD__,
          'dbuser'=>__SESSION_USER__,
          'dbname'=>__SESSION_DSN__,
          'dbport'=>__SESSION_PORT__
        ]);
      }
      if (is_object($this->db)) $this->db->mysqli->set_charset('utf8');
    }

    public function getDB() {
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
          
          try{

              $this->clientdb->execute_with_hash('SET lc_time_names = {lc_time_name};',array('lc_time_name'=>'de_DE'));
              $this->clientdb->execute_with_hash('set @sessiondb = {sessiondb}',array('sessiondb'=>$this->db->dbname));

              $this->db->execute_with_hash('set @sessionuser = {username}',$_SESSION);
              $this->db->execute_with_hash('set @sessionuserfullname = {fullname}',$_SESSION);

          }catch(\Exception $e){ echo $e->getMessage(); }

        }
      }catch(\Exception $e){
        echo $e->getMessage();
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

