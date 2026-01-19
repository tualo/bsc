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


class CreateSystemUser implements ICommandline
{

    public static function getCommandName(): string
    {
        return 'createuser';
    }

    public static function setup(Cli $cli)
    {
        $cli->command(self::getCommandName())
            ->description('create a user')
            ->opt('client', 'client', true, 'string')
            ->opt('username', 'username', true, 'string')
            ->opt('password', 'password plain text', true, 'string')
            ->opt('groups', 'groups separated by comma', true, 'string')
            ->opt('session', 'session db name', false, 'string')
            ->opt('master', 'set master flag', false, 'boolean');
    }


    public static function run(Args $args)
    {

        $clientOptions = "";
        /*
        if (($client_host = $args->getOpt('host'))!='') $clientOptions .= " --host=".$client_host." ";
        if (($client_username = $args->getOpt('username'))!='') $clientOptions .= " --user=".$client_username." ";
        if (($client_password = $args->getOpt('password'))!='') $clientOptions .= ' --password="'.$client_password.'" ';
        */

        $clientUsername = $args->getOpt('username');
        $clientpassword = $args->getOpt('password');
        $clientDBName = $args->getOpt('client');
        $clientGroups = explode(',', $args->getOpt('groups'));
        if (($sessionDBName = $args->getOpt('session', '')) == '') {
            if (($sessionDBName = App::configuration('database', 'db_name', '')) == '') {
                $sessionDBName = readline("Enter the session db name: ");
            }
        }


        $msg = 'create user ' . $clientUsername;
        PostCheck::formatPrint(['blue'], $msg . ' (' . $sessionDBName . ', ' . $clientDBName . '):  ');


        App::run();

        $session = App::get('session');
        $sessiondb = $session->db;

        if (is_null($sessiondb)) {
            PostCheck::formatPrint(['red'], "\tno session db\n");
        } else {
            $sql = "call ADD_TUALO_USER({clientUsername},{clientpassword},{clientDBName},{clientgroup})";
            $sessiondb->direct($sql, [
                'clientUsername' => $clientUsername,
                'clientpassword' => $clientpassword,
                'clientDBName' => $clientDBName,
                'clientgroup' => $clientGroups[0]
            ]);
            // prevent out of sync
            $sessiondb->moreResults();
            // exec('echo "' . $sql . '" | mysql ' . $clientOptions . ' --force=true -D ' . $sessionDBName . ' ', $res, $err);

            foreach ($clientGroups as $group) {
                $sql = "call ADD_TUALO_USER_GROUP({clientUsername},{clientgroup})";
                $sessiondb->direct($sql, [
                    'clientUsername' => $clientUsername,
                    'clientgroup' => $group
                ]);
                // prevent out of sync
                $sessiondb->moreResults();
            }
            if ($args->getOpt('master', false)) {
                $sql = "update macc_users set typ='master' where  login = {clientUsername} ";
                $sessiondb->direct($sql, [
                    'clientUsername' => $clientUsername
                ]);
            }
            PostCheck::formatPrint(['green'], "\tdone   \n");
        }
    }
}
