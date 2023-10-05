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

            ->opt('db', 'db name', false, 'string')
            ->opt('session', 'session db name', false, 'string');
    }

    

    public static function run(Args $args){
        $prompt = [
            "\t".'do you want to create a new system? [y|n|c] '
        ];
        while(in_array($line = readline(implode("\n",$prompt)),['yes','y','n','no','c'])){
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

                $clientOptions = "";
                if (($client_host = $args->getOpt('host'))!='') $clientOptions = " --host=".$client_host." ";
                if (($client_username = $args->getOpt('username'))!='') $clientOptions = " --user=".$client_username." ";
                if (($client_password = $args->getOpt('password'))!='') $clientOptions = ' --password="'.$client_password.'" ';
                

                
                /*
                if (App::configuration('','__SESSION_USER__','')!=''){
                    $clientOptions .= " --user=".App::configuration('','__SESSION_USER__','');
                }
                if (App::configuration('','__SESSION_PASSWORD__','')!=''){
                    $clientOptions .= " --password=".App::configuration('','__SESSION_PASSWORD__','');
                }
                if (App::configuration('','__SESSION_HOST__','')!=''){
                    $clientOptions .= " --host=".App::configuration('','__SESSION_HOST__','');
                }
                if (App::configuration('','__SESSION_PORT__','')!=''){
                    $clientOptions .= " --port=".App::configuration('','__SESSION_PORT__','');
                }
                */


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

                PostCheck::formatPrint(['blue'],"\tsetup sessions db... ");
                exec('mysql '.$clientOptions.' --force=true -D '.$sessionDBName.' < '.__DIR__.'/commandline/sql/plain-system-session.sql',$res,$err);
                if ($err!=0){
                    PostCheck::formatPrintLn(['red'],'failed');
                    PostCheck::formatPrintLn(['red'],implode("\n",$res));
                    exit();
                }else{
                    PostCheck::formatPrintLn(['green'],'done');
                }

                PostCheck::formatPrint(['blue'],"\tsetup client db... ");
             
                exec('cat '.__DIR__.'/commandline/sql/plain-system.sql | sed -E \'s#SESSIONDB#'.$sessionDBName.'#g\' | mysql '.$clientOptions.' --force=true -D '.$clientDBName.' ',$res,$err);
                if ($err!=0){
                    PostCheck::formatPrintLn(['red'],'failed');
                    PostCheck::formatPrintLn(['red'],implode("\n",$res));
                    exit();
                }else{
                    PostCheck::formatPrintLn(['green'],'done');
                }

                $clientUsername = 'admin';
                $clientpassword = (Uuid::uuid4())->toString();
                
                $sql = "INSERT INTO macc_clients (id,username,password,host,port) VALUES ('".$clientDBName."','".App::configuration('','__SESSION_USER__','localhost')."','','".App::configuration('','__SESSION_HOST__','localhost')."',".App::configuration('','__SESSION_PORT__','localhost').")";
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
