# ************************************************************
# Sequel Pro SQL dump
# Version 4096
#
# http://www.sequelpro.com/
# http://code.google.com/p/sequel-pro/
#
# Host: 127.0.0.1 (MySQL 5.6.20)
# Database: kt7_versioning_db
# Generation Time: 2015-02-03 10:12:45 +0000
# ************************************************************


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


# Dump of table process
# ------------------------------------------------------------

DROP TABLE IF EXISTS `process`;

CREATE TABLE `process` (
  `process_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `run_id` int(10) unsigned DEFAULT NULL,
  `name` varchar(128) DEFAULT NULL,
  `created_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`process_id`),
  UNIQUE KEY `name_idx` (`name`),
  KEY `run_id` (`run_id`),
  CONSTRAINT `process_ibfk_1` FOREIGN KEY (`run_id`) REFERENCES `run` (`run_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;



# Dump of table run
# ------------------------------------------------------------

DROP TABLE IF EXISTS `run`;

CREATE TABLE `run` (
  `run_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `start` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `end` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`run_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;



# Dump of table source
# ------------------------------------------------------------

DROP TABLE IF EXISTS `source`;

CREATE TABLE `source` (
  `source_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(128) DEFAULT NULL,
  `source_group_id` int(10) unsigned DEFAULT NULL,
  `active` tinyint(1) NOT NULL DEFAULT '1',
  `created_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `downloader` varchar(128) DEFAULT NULL,
  `parser` varchar(128) DEFAULT NULL,
  `current_version` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`source_id`),
  UNIQUE KEY `name_idx` (`name`),
  KEY `source_group_id` (`source_group_id`),
  CONSTRAINT `source_ibfk_1` FOREIGN KEY (`source_group_id`) REFERENCES `source_group` (`source_group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

LOCK TABLES `source` WRITE;
/*!40000 ALTER TABLE `source` DISABLE KEYS */;

INSERT INTO `source` (`source_id`, `name`, `source_group_id`, `active`, `created_date`, `downloader`, `parser`, `current_version`)
VALUES
	(1,'UniProt/SWISSPROT',1,1,'2014-04-03 17:07:47','Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniProtSwissProt','Bio::EnsEMBL::Mongoose::Parser::Swissprot',5),
	(2,'UniParc',1,1,'2014-04-03 17:08:52','Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniProtUniParc','Bio::EnsEMBL::Mongoose::Parser::Uniparc',NULL),
	(3,'UniProt/SPTREMBL',1,0,'2014-04-03 17:09:53','Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniProtTrembl','Bio::EnsEMBL::Mongoose::Parser::Swissprot',NULL),
	(4,'RefSeq',2,1,'2014-04-03 17:09:57','Bio::EnsEMBL::Versioning::Pipeline::Downloader::RefSeq','Bio::EnsEMBL::Mongoose::Parser::Refseq',NULL),
	(5,'MIM',3,1,'2015-01-21 14:14:20','Bio::EnsEMBL::Versioning::Pipeline::Downloader::MIM','Bio::EnsEMBL::Mongoose::Parser::MIM',NULL),
	(6,'mim2gene',3,1,'2015-01-21 14:14:20','Bio::EnsEMBL::Versioning::Pipeline::Downloader::MIM2Gene','Bio::EnsEMBL::Mongoose::Parser::MIM2Gene',NULL),
	(7,'HGNC',4,1,'2015-01-21 14:14:20','Bio::EnsEMBL::Versioning::Pipeline::Downloader::HGNC','Bio::EnsEMBL::Mongoose::Parser::HGNC',NULL);

/*!40000 ALTER TABLE `source` ENABLE KEYS */;
UNLOCK TABLES;


# Dump of table source_group
# ------------------------------------------------------------

DROP TABLE IF EXISTS `source_group`;

CREATE TABLE `source_group` (
  `source_group_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(128) DEFAULT NULL,
  `created_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`source_group_id`),
  UNIQUE KEY `name_idx` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

LOCK TABLES `source_group` WRITE;
/*!40000 ALTER TABLE `source_group` DISABLE KEYS */;

INSERT INTO `source_group` (`source_group_id`, `name`, `created_date`)
VALUES
	(1,'Uniprot','2014-04-03 17:05:11'),
	(2,'RefSeq','2014-04-03 17:05:23'),
	(3,'MIM','2015-01-21 14:09:33'),
	(4,'HGNC','2015-01-21 14:09:33');

/*!40000 ALTER TABLE `source_group` ENABLE KEYS */;
UNLOCK TABLES;


# Dump of table version
# ------------------------------------------------------------

DROP TABLE IF EXISTS `version`;

CREATE TABLE `version` (
  `version_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `source_id` int(10) unsigned DEFAULT NULL,
  `revision` varchar(255) DEFAULT NULL,
  `created_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `count_seen` int(10) unsigned NOT NULL,
  `record_count` int(10) DEFAULT NULL,
  `uri` varchar(255) DEFAULT NULL,
  `index_uri` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`version_id`),
  KEY `version_idx` (`source_id`,`revision`),
  CONSTRAINT `version_ibfk_1` FOREIGN KEY (`source_id`) REFERENCES `source` (`source_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

LOCK TABLES `version` WRITE;
/*!40000 ALTER TABLE `version` DISABLE KEYS */;

/*!40000 ALTER TABLE `version` ENABLE KEYS */;
UNLOCK TABLES;


# Dump of table version_run
# ------------------------------------------------------------

DROP TABLE IF EXISTS `version_run`;

CREATE TABLE `version_run` (
  `version_run_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `version_id` int(10) unsigned DEFAULT NULL,
  `run_id` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`version_run_id`),
  KEY `version_id` (`version_id`),
  KEY `run_id` (`run_id`),
  CONSTRAINT `version_run_ibfk_1` FOREIGN KEY (`version_id`) REFERENCES `version` (`version_id`),
  CONSTRAINT `version_run_ibfk_2` FOREIGN KEY (`run_id`) REFERENCES `run` (`run_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;




/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
