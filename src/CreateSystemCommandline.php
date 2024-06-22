<?php
namespace Tualo\Office\Basic;
use Garden\Cli\Cli;
use Garden\Cli\Args;
use Tualo\Office\Basic\ICommandline;
use Tualo\Office\ExtJSCompiler\Helper;
use Tualo\Office\Basic\TualoApplication as App;
use Tualo\Office\Basic\PostCheck;
use Tualo\Office\DS\DataRenderer;
use Ramsey\Uuid\Uuid;


class CreateSystemCommandline implements ICommandline{

    public static function getCommandName():string { return 'createsystem';}

    public static function setup(Cli $cli){
        $cli->command(self::getCommandName())
            ->description('create a new system')

            ->opt('username', 'username', false, 'string')
            ->opt('password', 'password', false, 'string')
            ->opt('host', 'host', false, 'string')
            ->opt('createusers', 'createusers', false, 'boolean')
            ->opt('silent', 'silent', false, 'boolean')
            ->opt('db', 'db name', false, 'string')
            ->opt('session', 'session db name', false, 'string');
    }

    

    public static function run(Args $args){
        $prompt = [
            "\t".'do you want to create a new system? [y|n|c] '
        ];
        $line =( $args->getOpt('silent',false))?'y':'';
        
        while( ($line == 'y') || in_array($line = readline(implode("\n",$prompt)),['yes','y','n','no','c']) ){
            if ($line=='c') exit();
            if ($line=='y'){
                if (($clientDBName = $args->getOpt('db'))==''){
                    $clientDBName = readline("Enter the client db name: ");
                }
                if (($sessionDBName = $args->getOpt('session'))==''){
                    if (($sessionDBName = App::configuration('','__SESSION_DSN__',''))==''){
                        $sessionDBName = readline("Enter the session db name: ");
                    }
                }


                $session_database_password = "";
                $session_database_user = "";

                $client_database_password = "";
                $client_database_user = "";

                $clientOptions = "";
                if (($client_host = $args->getOpt('host'))!='') $clientOptions .= " --host=".$client_host." ";
                if (($client_username = $args->getOpt('username'))!='') $clientOptions .= " --user=".$client_username." ";
                if (($client_password = $args->getOpt('password'))!='') $clientOptions .= ' --password="'.$client_password.'" ';
                

                

                if (( $args->getOpt('createusers'))===true){
                    PostCheck::formatPrint(['blue'],"\tcreate database users ... ");
                    $session_database_password = (Uuid::uuid4())->toString();
                    $session_database_user = 'user_'.$sessionDBName;

                    $client_database_password = (Uuid::uuid4())->toString();
                    $client_database_user = 'user_'.$clientDBName;


                    PostCheck::formatPrint(['blue'],"\tsession database user: ".$session_database_user." \n");
                    PostCheck::formatPrint(['blue'],"\tsession database password: ".$session_database_password." \n");


                    PostCheck::formatPrint(['blue'],"\tclient database user: ".$client_database_user." \n");
                    PostCheck::formatPrint(['blue'],"\tclient database password: ".$client_database_password." \n");

                    exec('mysql '.$clientOptions.' -e "create user if not exists \''.$session_database_user.'\'@\'%\' identified by \''.$session_database_password.'\';"',$res,$err);
                    if ($err!=0){
                        PostCheck::formatPrintLn(['red'],'failed');
                        PostCheck::formatPrintLn(['red'],implode("\n",$res));
                        //exit();
                    }

                    exec('mysql '.$clientOptions.' -e "create user if not exists \''.$client_database_user.'\'@\'%\' identified by \''.$client_database_password.'\';"',$res,$err);
                    if ($err!=0){
                        PostCheck::formatPrintLn(['red'],'failed');
                        PostCheck::formatPrintLn(['red'],implode("\n",$res));
                        //exit();
                    }

                    exec('mysql '.$clientOptions.' -e "grant all on '.$sessionDBName.'.* to \''.$session_database_user.'\'@\'%\';"',$res,$err);
                    if ($err!=0){
                        PostCheck::formatPrintLn(['red'],'failed');
                        PostCheck::formatPrintLn(['red'],implode("\n",$res));
                        //exit();
                    }

                    exec('mysql '.$clientOptions.' -e "grant all on '.$clientDBName.'.* to \''.$client_database_user.'\'@\'%\';"',$res,$err);
                    if ($err!=0){
                        PostCheck::formatPrintLn(['red'],'failed');
                        PostCheck::formatPrintLn(['red'],implode("\n",$res));
                        exit();
                    }
                }


                PostCheck::formatPrint(['blue'],"\tcreate database *".$sessionDBName."* using mysql client... ");
                exec('mysql '.$clientOptions.' -e "create database if not exists '.$sessionDBName.';"',$res,$err);
                if ($err!=0){
                    PostCheck::formatPrintLn(['red'],'failed');
                    PostCheck::formatPrintLn(['red'],implode("\n",$res));
                    exit();
                }else{
                    PostCheck::formatPrintLn(['green'],'done');
                }

                PostCheck::formatPrint(['blue'],"\tcreate database ".$clientDBName." using mysql client... ");
                exec('mysql '.$clientOptions.' -e "create database if not exists '.$clientDBName.';"',$res,$err);
                if ($err!=0){
                    PostCheck::formatPrintLn(['red'],'failed');
                    PostCheck::formatPrintLn(['red'],implode("\n",$res));
                    exit();
                }else{
                    PostCheck::formatPrintLn(['green'],'done');
                }

                /*
                if ((  $args->getOpt('createusers'))===true){

                    $clientOptions = "";
                    if (($client_host = $args->getOpt('host'))!='') $clientOptions .= " --host=".$client_host." ";
                    $clientOptions .= " --user=".$session_database_user." ";
                    $clientOptions .= ' --password="'.$session_database_password.'" ';
                    
                }
                */
                PostCheck::formatPrint(['blue'],"\tsetup sessions db... ");

                exec('mysql '.$clientOptions.' --force=true -D '.$sessionDBName.' < '.__DIR__.'/commandline/sql/plain-system-session.sql',$res,$err);
                if ($err!=0){
                    PostCheck::formatPrintLn(['red'],'failed');
                    PostCheck::formatPrintLn(['red'],implode("\n",$res));
                    exit();
                }else{
                    PostCheck::formatPrintLn(['green'],'done');
                }
                
                /*
                if (( $args->getOpt('createusers'))===true){

                    $clientOptions = "";
                    if (($client_host = $args->getOpt('host'))!='') $clientOptions .= " --host=".$client_host." ";
                    $clientOptions .= " --user=".$client_database_user." ";
                    $clientOptions .= ' --password="'.$client_database_password.'" ';
                    
                }
                */

                /*
                PostCheck::formatPrint(['blue'],"\tsetup client db... ");
                exec('cat '.__DIR__.'/commandline/sql/plain-system.sql | sed -E \'s#SESSIONDB#'.$sessionDBName.'#g\' | mysql '.$clientOptions.' --force=true -D '.$clientDBName.' ',$res,$err);
                if ($err!=0){
                    PostCheck::formatPrintLn(['red'],'failed');
                    PostCheck::formatPrintLn(['red'],implode("\n",$res));
                    exit();
                }else{
                    PostCheck::formatPrintLn(['green'],'done');
                }
                */

                $clientUsername = 'admin';
                $clientpassword = (Uuid::uuid4())->toString();

                /*
                if (( $args->getOpt('createusers'))===true){

                    $clientOptions = "";
                    if (($client_host = $args->getOpt('host'))!='') $clientOptions .= " --host=".$client_host." ";
                    $clientOptions .= " --user=".$session_database_user." ";
                    $clientOptions .= ' --password="'.$session_database_password.'" ';
                    
                }
                */
                
                $sql = "INSERT IGNORE INTO macc_clients (id,username,password,host,port) VALUES ('".$clientDBName."','".App::configuration('','__SESSION_USER__','localhost')."','','".App::configuration('','__SESSION_HOST__','localhost')."',".App::configuration('','__SESSION_PORT__','localhost').")";
                exec('echo "'.$sql.'" | mysql '.$clientOptions.' --force=true -D '.$sessionDBName.' ',$res,$err);
                
                PostCheck::formatPrint(['blue'],"\tcreate client user... admin: ".$clientpassword." \n");
                $sql = "call ADD_TUALO_USER('".$clientUsername."','".$clientpassword."','".$clientDBName."','administration')";
                exec('echo "'.$sql.'" | mysql '.$clientOptions.' --force=true -D '.$sessionDBName.' ',$res,$err);


                break;
            }
            if ($line=='n'){
                break;
            }
        }

    }
}
