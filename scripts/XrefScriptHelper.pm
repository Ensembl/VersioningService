=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

# A simple command line parameter checker for xref scripts.

package XrefScriptHelper;

use Modern::Perl;
use Moose;

with 'MooseX::Getopt';

has species => (
  is => 'rw', 
  isa => 'Str', 
  default => 'rattus_norvegicus', 
  documentation => 'Ensembl production name of species, i.e. homo_sapiens'
);
has ttl_path => (
  is => 'rw',
  isa => 'Str',
  default => '/hps/nobackup/production/ensembl/ktaylor/xref/latest/',
  documentation => 'A root path into which the produced ttl files will be written'
);
has output_file => (
  is => 'rw', 
  isa => 'Str', 
  default => 'identity_matches.tsv',
  documentation => 'A file to write decision-making debug to'
);
has debug_file => (
  is => 'rw', 
  isa => 'Str', 
  default => 'debug.tsv', 
  documentation => 'An additional file for debug data from xref decision-making code'
);
has debug => (
  is => 'rw',
  isa => 'Bool',
  default => 0,
  documentation => 'Turn this flag on in order to promote a profusion of text outputs'
);
has fuseki_heap => (
  is => 'rw',
  isa => 'Int',
  default => 30,
  documentation => 'Override for the heap size that is used to launch Fuseki.'
);

has config_file => (
  is => 'rw',
  isa => 'Str',
  default => '/homes/ktaylor/src/VersioningService/conf/xref_LOD_mapping.json',
  documentation => 'A JSON LOD config file describing the different sources and conversions required for the xref pipeline'
);

has config_schema => (
  is => 'rw',
  isa => 'Str',
  default => '/homes/ktaylor/src/VersioningService/conf/xref_LOD_schema.json',
  documentation => 'The schema constraining the config_file option. The file will be validated on each run'
);

has ens_host => (
  is => 'rw',
  isa => 'Str',
  default => 'mysql-ensembl-mirror.ebi.ac.uk',
  documentation => 'Database host for staging database. This will be used for getting a canonical list of IDs as well as data upload'
);

has ens_port => (
  is => 'rw',
  isa => 'Str',
  default => 4240,
  documentation => 'Database port for staging database. Use with ens_host option'
);

has ens_user => (
  is => 'rw',
  isa => 'Str',
  default => 'anonymous',
  documentation => 'Database user for staging database. Use with ens_host option'
);

has ens_pass => (
  is => 'rw',
  isa => 'Str',
  documentation => 'Password for write operations for ens_user'
);

has ens_db_version => (
  is => 'rw',
  isa => 'Str',
  default => 92,
  documentation => 'Database version for staging database. Use with ens_host option'
);

1;
