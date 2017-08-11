-- Convert schema '/Users/ktaylor/Documents/workspace/mongoose/share/migrations/_source/deploy/2/001-auto.yml' to '/Users/ktaylor/Documents/workspace/mongoose/share/migrations/_source/deploy/1/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE source DROP INDEX active_idx;

;
ALTER TABLE version DROP INDEX revision_idx;

;
ALTER TABLE version_manifest DROP FOREIGN KEY version_manifest_fk_version_id;

;
DROP TABLE version_manifest;

;

COMMIT;

