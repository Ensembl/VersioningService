# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Upgrade versioning schemas in situ
# perl schema_update.pl --host $host --port 3306 --user me -pass $pass  --db $host
# The script picks up default configuration from /conf/manager.conf , but command line options override these
# Use --help for a list of possible options, not all of which are necessarily required.

use Modern::Perl;
use MongooseHelper;
use Bio::EnsEMBL::Versioning::ORM::Schema;
use Config::General;

# borrow config from the live setup wherein are specific DB connection parameters
my $conf = Config::General->new($ENV{MONGOOSE}.'/conf/manager.conf');
my $sql_dir = $ENV{MONGOOSE}.'/sql/';
my %opts = $conf->getall();
%opts = (%opts , %{ MongooseHelper->new_with_options() });

my $dsn = sprintf('DBI:%s:database=%s;host=%s;port=%s',$opts{driver},$opts{db},$opts{host},$opts{port});

my $schema = Bio::EnsEMBL::Versioning::ORM::Schema->connect(
  $dsn, 
  $opts{user},
  $opts{pass}
);

my $version = $schema->schema_version();
my $db_version = $schema->get_db_version();
print "Current schema version is $version\n";
print "DB schema version is $db_version\n" if defined $db_version;

if (!$db_version) {
  print "No schema present, installing one\n";
  $schema->deploy;
  exit();
} elsif ($db_version == $version) {
  print "Schemas are in sync\n";
  exit();
} elsif ($db_version < $version) {
  print "Creating patches and upgrading database from schema $db_version to $version of schema\n";
  $schema->create_ddl_dir( $opts{driver}, $version, $sql_dir, $schema->get_db_version());
  $schema->upgrade();

} elsif ($db_version > $version) {
  print "Somehow the database is a newer version than the software. Update your checkout or search for time-travellers\n";
  exit(1);
}
