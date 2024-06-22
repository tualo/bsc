DELIMITER ;
CREATE TABLE IF NOT EXISTS `ds_class` (
  `class_name` varchar(64) NOT NULL,
  PRIMARY KEY (`class_name`)
);
INSERT  IGNORE INTO `ds_class` VALUES
('Artikel'),
('Aufgabenplanung'),
('Datenstamm'),
('Datenstamm-Berichte'),
('Debitoren'),
('Kreditoren'),
('Reklamationstool'),
('Sendungsverfolgung'),
('Unklassifiziert'),
('Warenwirtschaft');