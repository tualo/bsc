<?php

namespace Tualo\Office\Basic;

use Tualo\Office\Basic\MYSQL\Database;


class TualoDBSessionHandler implements \SessionHandlerInterface , \SessionIdInterface {
  /* Methoden */
  private $db =  null;//new database(__SESSION_USER__,__SESSION_PASSWORD__,__SESSION_DSN__,__SESSION_HOST__,__SESSION_PORT__);
  private $name = "__SECURE-PHPSESSID";


  private function newDBByRow($row){
    if (defined('__DB_SSL_KEY__')&&defined('__DB_SSL_CERT__')&&defined('__DB_SSL_CA__')){
      return new Database($row['dbuser'],$row['dbpass'],$row['dbname'],$row['dbhost'],$row['dbport'],__DB_SSL_KEY__,__DB_SSL_CERT__,__DB_SSL_CA__);
    }
    return new Database($row['dbuser'],$row['dbpass'],$row['dbname'],$row['dbhost'],$row['dbport']);
  }

  function __construct() {
    if (!defined('__USE_DB_SESSION_HANLDER_ENCRYPTION__')){ define('__USE_DB_SESSION_HANLDER_ENCRYPTION__','shouldbesecret'); }
    $this->db = $this->newDBByRow([
      'dbhost'=>__SESSION_HOST__,
      'dbpass'=>__SESSION_PASSWORD__,
      'dbuser'=>__SESSION_USER__,
      'dbname'=>__SESSION_DSN__,
      'dbport'=>__SESSION_PORT__
    ]);
  }



  /**
    * decrypt AES 256
    *
    * @param data $edata
    * @param string $password
    * @return decrypted data
    */
  function decrypt($edata) {
    $password = __USE_DB_SESSION_HANLDER_ENCRYPTION__;
    $data = base64_decode($edata);
    $salt = substr($data, 0, 16);
    $ct = substr($data, 16);

    $rounds = 3; // depends on key length
    $data00 = $password.$salt;
    $hash = array();
    $hash[0] = hash('sha256', $data00, true);
    $result = $hash[0];
    for ($i = 1; $i < $rounds; $i++) {
        $hash[$i] = hash('sha256', $hash[$i - 1].$data00, true);
        $result .= $hash[$i];
    }
    $key = substr($result, 0, 32);
    $iv  = substr($result, 32,16);

    return openssl_decrypt($ct, 'AES-256-CBC', $key, true, $iv);
  }

  /**
   * crypt AES 256
   *
   * @param data $data
   * @param string $password
   * @return base64 encrypted data
   */
  function encrypt($data) {
      // Set a random salt
      $password = __USE_DB_SESSION_HANLDER_ENCRYPTION__;
      $salt = openssl_random_pseudo_bytes(16);

      $salted = '';
      $dx = '';
      // Salt the key(32) and iv(16) = 48
      while (strlen($salted) < 48) {
        $dx = hash('sha256', $dx.$password.$salt, true);
        $salted .= $dx;
      }

      $key = substr($salted, 0, 32);
      $iv  = substr($salted, 32,16);

      $encrypted_data = openssl_encrypt($data, 'AES-256-CBC', $key, true, $iv);
      return base64_encode($salt . $encrypted_data);
  }

  public  function close (   ){

    $this->db->close();
    return true;
  }

  public function create_sid (   ){
    return uniqid();
  }

  public function destroy (   $session_id ){
    $sql = '
      DELETE FROM session_handler WHERE session_id ={session_id}
    ';
    $this->db->direct($sql,array('session_id'=>$session_id));

    return true;
  }
  public function gc (   $maxlifetime ){
    $sql = '
      DELETE FROM session_handler
      WHERE
      lastaccesstime < DATE_SUB(NOW(), INTERVAL {maxlifetime} SECOND)
    ';
    $this->db->direct($sql,array('maxlifetime'=>$maxlifetime));
    return 0;
  }
  public function open (   $save_path ,   $session_name ){
    $this->name = $session_name;
    /*
    $sql = '
      INSERT INTO session_handler SET
        session_id = {session_id},
        lastaccesstime = now()
      ON DUPLICATE KEY UPDATE lastaccesstime=values(lastaccesstime);
    ';
    $this->db->direct($sql,array('session_id'=>$session_id));
    */
    return true;
  }
  public function read (   $session_id ){
    $sql = '
    SELECT
      ifnull(session_data,\'\') session_data
    FROM
      session_handler
    WHERE
      session_id={session_id}
    ';

    if ($this->db->state===false){
      $this->db = new database(__SESSION_USER__,__SESSION_PASSWORD__,__SESSION_DSN__,__SESSION_HOST__,__SESSION_PORT__);
    }

    $row = $this->db->singleRow($sql,array('session_id'=>$session_id));

    $sql = '
    INSERT INTO session_handler (session_id,session_data,createtime,lastaccesstime)
    values ({session_id},{session_data},now(),now())
    ON DUPLICATE KEY UPDATE lastaccesstime=values(lastaccesstime);
    ';
    $this->db->direct($sql,array('session_id'=>$session_id));

    if ($row!==false){
      return  base64_decode($row['session_data']);
    }
    return "";
  }

  public function write (   $session_id ,   $session_data ){
    $sql = '
    INSERT INTO session_handler (session_id,session_data,createtime,lastaccesstime)
    values ({session_id},{session_data},now(),now())
    ON DUPLICATE KEY UPDATE session_data =values(session_data),lastaccesstime=values(lastaccesstime);
    ';
    $this->db->direct($sql,array('session_data'=> base64_encode( $session_data ),'session_id'=>$session_id));
    return true;
  }
  
}

