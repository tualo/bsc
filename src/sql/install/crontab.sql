DELIMITER ;

CREATE TABLE IF NOT EXISTS `crontab` (
  `id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `anwendung` varchar(255) NOT NULL,
  `supanwendung` varchar(255) NOT NULL,
  `minute` varchar(15) NOT NULL,
  `stunde` varchar(15) NOT NULL,
  `tag` varchar(15) NOT NULL,
  `monat` varchar(15) NOT NULL,
  `wochentag` varchar(15) NOT NULL,
  `letzterstart` datetime DEFAULT NULL,
  `status` tinyint(4) DEFAULT 0,
  `isrunning` tinyint(4) DEFAULT 0,
  `startat` datetime DEFAULT NULL,
  `stopat` datetime DEFAULT NULL,
  `errormsg` text DEFAULT NULL,
  `resultmsg` text DEFAULT NULL,
  `haserror` tinyint(4) DEFAULT 0,
  `sekunden_laufzeit` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_crontab_crontab_weekdays` (`wochentag`),
  KEY `fk_crontab_crontab_applications` (`anwendung`),
  CONSTRAINT `fk_crontab_crontab_applications` FOREIGN KEY (`anwendung`) REFERENCES `crontab_applications` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_crontab_crontab_weekdays` FOREIGN KEY (`wochentag`) REFERENCES `crontab_weekdays` (`id`) ON UPDATE CASCADE
);