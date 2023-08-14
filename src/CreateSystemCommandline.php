<?php
namespace Tualo\Office\Basic;
use Garden\Cli\Cli;
use Garden\Cli\Args;
use Tualo\Office\Basic\ICommandline;
use Tualo\Office\ExtJSCompiler\Helper;
use Tualo\Office\Basic\TualoApplication as App;
use Tualo\Office\Basic\PostCheck;
use Tualo\Office\DS\DataRenderer;


class CreateSystemCommandline implements ICommandline{

    public static function getCommandName():string { return 'createsystem';}

    public static function setup(Cli $cli){
        $cli->command(self::getCommandName())
            ->description('runs postcheck commands for all modules')
            ->opt('client', 'only use this client', false, 'string');
    }

    

    public static function run(Args $args){
        $prompt = [
            "\t".'do you want to create a new system? [y|n|c] '
        ];
        while(in_array($line = readline(implode("\n",$prompt)),['yes','y','n','no','c'])){
            if ($line=='c') exit();
            if ($line=='y'){
                $sessionDBName = readline("Enter the session db name: ");
                $clientDBName = readline("Enter the client db name: ");

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
                exec('mysql -D '.$sessionDBName.' < '.__DIR__.'/commandline/sql/sessions.sql',$res,$err);
                if ($err!=0){
                    PostCheck::formatPrintLn(['red'],'failed');
                    PostCheck::formatPrintLn(['red'],implode("\n",$res));
                    exit();
                }else{
                    PostCheck::formatPrintLn(['green'],'done');
                }

                PostCheck::formatPrint(['blue'],"\tsetup client db... ");
                exec('mysql --force=true -D '.$clientDBName.' < '.__DIR__.'/commandline/sql/tualooffice.ddl.sql',$res,$err);
                if ($err!=0){
                    PostCheck::formatPrintLn(['red'],'failed');
                    PostCheck::formatPrintLn(['red'],implode("\n",$res));
                    exit();
                }else{
                    PostCheck::formatPrintLn(['green'],'done');
                }

                break;
            }
            if ($line=='n'){
                break;
            }
        }

    }
}
