-- Convert schema '/Users/ktaylor/Documents/workspace/mongoose/share/migrations/_source/deploy/1/001-auto.yml' to '/Users/ktaylor/Documents/workspace/mongoose/share/migrations/_source/deploy/2/001-auto.yml':;

;
BEGIN;

;
SET foreign_key_checks=0;

;
CREATE TABLE `version_manifest` (
  `file_id` integer unsigned NOT NULL auto_increment,
  `version_id` integer unsigned NULL,
  `record_count` integer NULL,
  `index_uri` varchar(255) NULL,
  INDEX `version_manifest_idx_version_id` (`version_id`),
  PRIMARY KEY (`file_id`),
  CONSTRAINT `version_manifest_fk_version_id` FOREIGN KEY (`version_id`) REFERENCES `version` (`version_id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB;

;
SET foreign_key_checks=1;

;
ALTER TABLE source ADD INDEX active_idx (active);

;
ALTER TABLE version ADD INDEX revision_idx (revision);

;

COMMIT;

