<?php
/*
use Tualo\Office\Basic\Middleware\Maintaince;
use Tualo\Office\Basic\Middleware\SettingsCheck;
use Tualo\Office\Basic\Middleware\Session;
use Tualo\Office\Basic\Middleware\Router;
use Tualo\Office\Basic\Routes\Index;
*/

if (class_exists("Tualo\Office\Basic\Middleware\Maintaince")){ }
if (class_exists("Tualo\Office\Basic\Middleware\SettingsCheck")){ }
if (class_exists("Tualo\Office\Basic\Middleware\Session")){ }
if (class_exists("Tualo\Office\Basic\Middleware\Router")){ }

if (class_exists("Tualo\Office\Basic\Routes\Index")){ }
if (class_exists("Tualo\Office\Basic\Routes\Logout")){ }
//require_once __DIR__.'/Routes/Download.php';

require_once "Middleware/ClientIP.php";
require_once "Middleware/Timezone.php";
require_once "PostCheckCommandline.php";
require_once "PreCheckCommandline.php";
require_once "MaintainceCommandline.php";
require_once "CreateSystemCommandline.php";
require_once "CreateSystemUser.php";
require_once "CreateTMShell.php";

require_once "InstallViewSQLCommandline.php";
require_once "InstallMenuSQLCommandline.php";
require_once "InstallHTAccessCommandline.php";
require_once "SetConfigurationVariable.php";

require_once "Routes/RegisterClient.php";
require_once "Routes/Logout.php";
require_once "Routes/PublicRoute.php";

require_once "Checks/Tables.php";
require_once "commandline/InstallMain.php";

