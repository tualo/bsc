DELIMITER ;

CREATE TABLE IF NOT EXISTS `crontab_weekdays` (
  `id` varchar(15) NOT NULL,
  `name` varchar(20) NOT NULL,
  PRIMARY KEY (`id`)
);

INSERT  IGNORE INTO `crontab_weekdays` VALUES
    ('*','Alle'),
    ('Fri','Freitag'),
    ('Mon','Montag'),
    ('mon-fri','Montag-Freitag'),
    ('Sat','Samstag'),
    ('Sun','Sonntag'),
    ('Thu','Donnerstag'),
    ('thu-sat','Dienstag-Samstag'),
    ('Tue','Dienstag'),
    ('Wed','Mittwoch')
;