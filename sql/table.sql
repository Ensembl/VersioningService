-- Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

# Versioning db table definitions
#

# Conventions:
#  - use lower case and underscores
#  - internal ids are integers named tablename_id
#  - same name is given in foreign key relations

CREATE TABLE source_group (
  source_group_id          INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  name                     VARCHAR(40),
  created_date             TIMESTAMP NOT NULL DEFAULT NOW(),

  PRIMARY KEY (source_group_id),
  unique KEY name_idx (name)

) COLLATE=latin1_swedish_ci ENGINE=InnoDB;


CREATE TABLE source (
  source_id                INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  name                     VARCHAR(40),
  source_group_id          INT(10) UNSIGNED,
  active                   BOOLEAN NOT NULL DEFAULT 1,
  created_date             TIMESTAMP NOT NULL DEFAULT NOW(),

  PRIMARY KEY (source_id),
  UNIQUE KEY name_idx (name),
  FOREIGN KEY (source_group_id) REFERENCES source_group(source_group_id)

) COLLATE=latin1_swedish_ci ENGINE=InnoDB;

CREATE TABLE run (
  run_id                   INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  start                    TIMESTAMP NOT NULL DEFAULT NOW(),
  end                      TIMESTAMP,

  PRIMARY KEY (run_id)

) COLLATE=latin1_swedish_ci ENGINE=InnoDB;

CREATE TABLE version (
  version_id               INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  source_id                INT(10) UNSIGNED,
  version                  VARCHAR(40),
  created_date             TIMESTAMP NOT NULL DEFAULT NOW(),
  is_current               BOOLEAN NOT NULL DEFAULT 0,
  count_seen               INT(10) UNSIGNED NOT NULL,
  record_count             INT(10),
  uri                      VARCHAR(150),

  PRIMARY KEY (version_id),
  KEY version_idx (source_id, version),
  FOREIGN KEY (source_id) REFERENCES source(source_id)

) COLLATE=latin1_swedish_ci ENGINE=InnoDB;

CREATE TABLE process (
  process_id               INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  run_id                   INT(10) UNSIGNED,
  name                     VARCHAR(40),
  created_date             TIMESTAMP NOT NULL DEFAULT NOW(),

  PRIMARY KEY (process_id),
  UNIQUE KEY name_idx (name),
  FOREIGN KEY (run_id) REFERENCES run(run_id)

) COLLATE=latin1_swedish_ci ENGINE=InnoDB;

CREATE TABLE version_run (
  version_run_id           INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  version_id               INT(10) UNSIGNED,
  run_id                   INT(10) UNSIGNED,

  PRIMARY KEY (version_run_id),
  FOREIGN KEY (version_id) REFERENCES version(version_id),
  FOREIGN KEY (run_id) REFERENCES run(run_id)

) COLLATE=latin1_swedish_ci ENGINE=InnoDB;

CREATE TABLE source_download (
  source_download_id       INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  source_id                INT(10) UNSIGNED,
  module                   VARCHAR(40),
  parser                   VARCHAR(40),

  PRIMARY KEY (source_download_id),
  UNIQUE KEY module_idx (module),
  FOREIGN KEY (source_id) REFERENCES source(source_id)

) COLLATE=latin1_swedish_ci ENGINE=InnoDB;

CREATE TABLE resources (
  resource_id              INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  name                     VARCHAR(40),
  type                     ENUM('http', 'ftp', 'file', 'db') NOT NULL DEFAULT 'http',
  value                    VARCHAR(160),
  multiple_files           BOOLEAN NOT NULL DEFAULT 0,
  release_version          BOOLEAN NOT NULL DEFAULT 0,
  source_download_id       INT(10) UNSIGNED,
  
  PRIMARY KEY (resource_id),
  KEY name_idx (name),
  FOREIGN KEY (source_download_id) REFERENCES source_download(source_download_id)

) COLLATE=latin1_swedish_ci ENGINE=InnoDB;




