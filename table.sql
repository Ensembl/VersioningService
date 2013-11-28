CREATE TABLE source_group (
  source_group_id          INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  name                     VARCHAR(40),
  created_date             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (source_group_id),
  unique KEY name_idx (name)

) COLLATE=latin1_swedish_ci ENGINE=InnoDB;


CREATE TABLE source (
  source_id                INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  name                     VARCHAR(40),
  source_group_id          INT(10) UNSIGNED NOT NULL,
  active                   BOOLEAN NOT NULL DEFAULT 1,
  created_date             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (source_id),
  UNIQUE KEY name_idx (name),
  FOREIGN KEY (source_group_id) REFERENCES source_group(source_group_id)

) COLLATE=latin1_swedish_ci ENGINE=InnoDB;


CREATE TABLE version (
  version_id               INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  source_id                INT(10) UNSIGNED NOT NULL,
  version                  VARCHAR(40),
  created_date             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_current               BOOLEAN NOT NULL DEFAULT 0,
  count_seen               INT(10) UNSIGNED NOT NULL,
  record_count             INT(10),

  PRIMARY KEY (version_id),
  KEY version_idx (source_id, version),
  FOREIGN KEY (source_id) REFERENCES source(source_id)

) COLLATE=latin1_swedish_ci ENGINE=InnoDB;

CREATE TABLE process (
  process_id               INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  name                     VARCHAR(40),
  created_date             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (process_id),
  UNIQUE KEY name_idx (name)

) COLLATE=latin1_swedish_ci ENGINE=InnoDB;

CREATE TABLE run (
  run_id                   INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  start                    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  end                      TIMESTAMP,

  PRIMARY KEY (run_id)

) COLLATE=latin1_swedish_ci ENGINE=InnoDB;

CREATE TABLE process_version (
  process_version_id       INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  process_id               INT(10) UNSIGNED NOT NULL,
  version_id               INT(10) UNSIGNED NOT NULL,
  run_id                   INT(10) UNSIGNED NOT NULL,

  PRIMARY KEY (process_version_id),
  FOREIGN KEY (version_id) REFERENCES version(version_id),
  FOREIGN KEY (process_id) REFERENCES process(process_id),
  FOREIGN KEY (run_id) REFERENCES run(run_id)

) COLLATE=latin1_swedish_ci ENGINE=InnoDB;

CREATE TABLE source_download (
  source_download_id       INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  source_id                INT(10) UNSIGNED NOT NULL,
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
  value                    VARCHAR(40),
  multiple_files           BOOLEAN NOT NULL DEFAULT 0,
  source_download_id       INT(10) UNSIGNED NOT NULL,
  
  PRIMARY KEY (resource_id),
  KEY name_idx (name),
  FOREIGN KEY (source_download_id) REFERENCES source_download(source_download_id)

) COLLATE=latin1_swedish_ci ENGINE=InnoDB;




