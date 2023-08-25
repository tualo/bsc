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
                    $sessionDBName = readline("Enter the session db name: ");
                }
                

                PostCheck::formatPrint(['blue'],"\tcreate database ".$sessionDBName." using mysql client... ");
                exec('mysql -e "create database if not exists '.$sessionDBName.';"',$res,$err);
                if ($err!=0){
                    PostCheck::formatPrintLn(['red'],'failed');
                    PostCheck::formatPrintLn(['red'],implode("\n",$res));
                    exit();
                }else{
                    PostCheck::formatPrintLn(['green'],'done');
                }

                PostCheck::formatPrint(['blue'],"\tcreate database ".$clientDBName." using mysql client... ");
                exec('mysql -e "create database if not exists '.$clientDBName.';"',$res,$err);
                if ($err!=0){
                    PostCheck::formatPrintLn(['red'],'failed');
                    PostCheck::formatPrintLn(['red'],implode("\n",$res));
                    exit();
                }else{
                    PostCheck::formatPrintLn(['green'],'done');
                }

                PostCheck::formatPrint(['blue'],"\tsetup sessions db... ");
                exec('mysql --force=true -D '.$sessionDBName.' < '.__DIR__.'/commandline/sql/plain-system-session.sql',$res,$err);
                if ($err!=0){
                    PostCheck::formatPrintLn(['red'],'failed');
                    PostCheck::formatPrintLn(['red'],implode("\n",$res));
                    exit();
                }else{
                    PostCheck::formatPrintLn(['green'],'done');
                }

                PostCheck::formatPrint(['blue'],"\tsetup client db... ");
             
                    /*
                    `login` varchar(255) NOT NULL DEFAULT '',
                    `passwd` varchar(255) DEFAULT NULL,
                    `groupname` varchar(32) DEFAULT NULL,
                    `typ` varchar(20) DEFAULT NULL,
                    `initial` int(11) DEFAULT 0,
                    `tpin` varchar(50) DEFAULT NULL,
                    `salt` varchar(255) DEFAULT NULL,
                    `pwtype` varchar(255) DEFAULT 'md5',
                    PRIMARY KEY (`login`)
                  )
                INSERT INTO `macc_users_clients` VALUES ('thomas.hoffmann@tualo.de','clientdatabase');
                INSERT INTO `macc_users_groups` VALUES ('thomas.hoffmann@tualo.de','administration',NULL),('thomas.hoffmann@tualo.de','_default_',NULL);
                */

                exec('cat '.__DIR__.'/commandline/sql/plain-system.sql | sed -E \'s#SESSIONDB#'.$sessionDBName.'#g\' | mysql --force=true -D '.$clientDBName.' ',$res,$err);
                if ($err!=0){
                    PostCheck::formatPrintLn(['red'],'failed');
                    PostCheck::formatPrintLn(['red'],implode("\n",$res));
                    exit();
                }else{
                    PostCheck::formatPrintLn(['green'],'done');
                }

                $clientUsername = 'admin';
                $clientpassword = (Uuid::uuid4())->toString();
                $sql = "INSERT INTO `macc_clients` VALUES ('".$clientDBName."',user(),'','localhost',3306)";
                exec('echo "'.$sql.'" | mysql --force=true -D '.$sessionDBName.' ',$res,$err);
                
                PostCheck::formatPrint(['blue'],"\tcreate client user... admin: ".$clientpassword." ");
                $sql = "call ADD_TUALO_USER('".$clientUsername."','".$clientpassword."','".$clientDBName."','administration')";
                exec('echo "'.$sql.'" | mysql --force=true -D '.$sessionDBName.' ',$res,$err);


                break;
            }
            if ($line=='n'){
                break;
            }
        }

    }
}
