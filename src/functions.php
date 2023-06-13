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
require_once "MaintainceCommandline.php";
require_once "CreateSystemCommandline.php";
