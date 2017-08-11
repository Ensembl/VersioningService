-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Thu Aug 10 17:11:55 2017
-- 
;
SET foreign_key_checks=0;
--
-- Table: `process`
--
CREATE TABLE `process` (
  `process_id` integer unsigned NOT NULL auto_increment,
  `run_id` integer unsigned NULL,
  `name` varchar(128) NULL,
  `created_date` timestamp NOT NULL DEFAULT current_timestamp,
  INDEX `process_idx_run_id` (`run_id`),
  PRIMARY KEY (`process_id`),
  UNIQUE `name_idx` (`name`),
  CONSTRAINT `process_fk_run_id` FOREIGN KEY (`run_id`) REFERENCES `run` (`run_id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB;
--
-- Table: `run`
--
CREATE TABLE `run` (
  `run_id` integer unsigned NOT NULL auto_increment,
  `start` timestamp NOT NULL DEFAULT current_timestamp,
  `end` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`run_id`)
) ENGINE=InnoDB;
--
-- Table: `source_group`
--
CREATE TABLE `source_group` (
  `source_group_id` integer unsigned NOT NULL auto_increment,
  `name` varchar(128) NULL,
  `created_date` timestamp NOT NULL DEFAULT current_timestamp,
  PRIMARY KEY (`source_group_id`),
  UNIQUE `name_idx` (`name`)
) ENGINE=InnoDB;
--
-- Table: `version`
--
CREATE TABLE `version` (
  `version_id` integer unsigned NOT NULL auto_increment,
  `source_id` integer unsigned NULL,
  `revision` varchar(255) NULL,
  `created_date` timestamp NOT NULL DEFAULT current_timestamp,
  `count_seen` integer unsigned NOT NULL,
  `record_count` integer NULL,
  `uri` varchar(255) NULL,
  `index_uri` varchar(255) NULL,
  INDEX `version_idx_source_id` (`source_id`),
  PRIMARY KEY (`version_id`),
  CONSTRAINT `version_fk_source_id` FOREIGN KEY (`source_id`) REFERENCES `source` (`source_id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB;
--
-- Table: `version_run`
--
CREATE TABLE `version_run` (
  `version_run_id` integer unsigned NOT NULL auto_increment,
  `version_id` integer unsigned NULL,
  `run_id` integer unsigned NULL,
  INDEX `version_run_idx_run_id` (`run_id`),
  INDEX `version_run_idx_version_id` (`version_id`),
  PRIMARY KEY (`version_run_id`),
  CONSTRAINT `version_run_fk_run_id` FOREIGN KEY (`run_id`) REFERENCES `run` (`run_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `version_run_fk_version_id` FOREIGN KEY (`version_id`) REFERENCES `version` (`version_id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB;
--
-- Table: `source`
--
CREATE TABLE `source` (
  `source_id` integer unsigned NOT NULL auto_increment,
  `name` varchar(128) NULL,
  `source_group_id` integer unsigned NULL,
  `active` tinyint NOT NULL DEFAULT 1,
  `created_date` timestamp NOT NULL DEFAULT current_timestamp,
  `downloader` varchar(128) NULL,
  `parser` varchar(128) NULL,
  `current_version` integer unsigned NULL,
  INDEX `source_idx_current_version` (`current_version`),
  INDEX `source_idx_source_group_id` (`source_group_id`),
  PRIMARY KEY (`source_id`),
  UNIQUE `name_idx` (`name`),
  CONSTRAINT `source_fk_current_version` FOREIGN KEY (`current_version`) REFERENCES `version` (`version_id`),
  CONSTRAINT `source_fk_source_group_id` FOREIGN KEY (`source_group_id`) REFERENCES `source_group` (`source_group_id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB;
SET foreign_key_checks=1;
