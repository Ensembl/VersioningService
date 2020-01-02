=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

# This module allows the use of DBIC to autocreate a test database.
# It's inclusion at the start of .t files will allow disposable versioning service databases


package Bio::EnsEMBL::Versioning::TestDB;

use strict;
use warnings;
use Bio::EnsEMBL::Versioning::Broker;
use Env;
require Exporter;
use parent 'Exporter';
our @EXPORT_OK = qw(broker get_conf_location);

my $broker = Bio::EnsEMBL::Versioning::Broker->new(config_file => get_conf_location(), create => 1);
# $broker->schema->deploy(); # auto create schema in test DB

sub get_conf_location {
  my $conf = $ENV{MONGOOSE_TEST}; # MONGOOSE_TEST defines the config file to use for this test. e.g. working with a different DB engine.
  $conf ||= $ENV{MONGOOSE}.'/conf/test.conf';
  return $conf;
}

sub broker {
  return $broker;
}

# Insert cleanup of test database depending on driver here, or get Test::DBIx::Class configured before it is used.
sub END {
  $broker->schema->storage->dbh_do(sub {
    my ($storage,$dbh,@args) = @_;
    # lifted from DBIx::Class::TableNames which has fallen into disrepair
    my @tables = $storage->dbh->tables(undef, undef, undef, 'TABLE'); 
    s/\Q`\E//g for @tables; 
    s/\Q"\E//g for @tables;
    s/.+\.(.+)/$1/g for @tables;
    # Now that table names are cleaned, we can drop them all.
    my $db_name = $dbh->{Name};
    print "cleanup $db_name\n";
    my $table_names = join ',',@tables;
    
    if ($broker->config->{driver} eq 'SQLite') {
      # SQLite DBs are disk based, and must be removed manually
      my $sqlite_file = $broker->config->{file};
      unlink $sqlite_file if -e $sqlite_file;
    } else {
      $dbh->do(
      "SET foreign_key_checks = 0; 
       DROP TABLE $table_names;
       SET foreign_key_checks = 1;
       DROP DATABASE $db_name;
      ");  
    }
  });
}


1;
