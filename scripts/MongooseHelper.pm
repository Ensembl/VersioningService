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

# A simple command line parameter checker for scripts.

package MongooseHelper;

use Modern::Perl;
use Moose;

with 'MooseX::Getopt';

has species => (
  is => 'rw', 
  isa => 'Str', 
  default => 'homo sapiens', 
  documentation => 'Common name of species to dump. Will be transformed into a taxon ID for the query'
);
has dump_path => (
  is => 'rw', 
  isa => 'Str', 
  default => '/nfs/nobackup/ensembl/ktaylor', 
  documentation => 'A root path into which the produced ttl files will be written'
);
has source_list => (
  is => 'rw', 
  isa => 'ArrayRef', 
  default => sub { [qw/Swissprot Trembl MIM mim2gene HGNC EntrezGene Uniparc RefSeq Reactome ArrayExpress RNAcentral/]},
  documentation => 'Name a source to dump, or several by repeating the option. Defaults to all known sources'
);
has format => (
  is => 'rw', 
  isa => 'Str', 
  default => 'RDF', 
  documentation => 'Decide which format to dump the data as. Examples: RDF, JSON, FASTA'
);

has db => (is => 'rw', isa => 'Str', documentation => 'Database name on server');
has driver => (is => 'rw',isa => 'Str',default => 'mysql', documentation => 'Database driver, usually mysql but could also be SQLite or postgres (Pg)');
has host => (is => 'rw', isa => 'Str', documentation => 'Hostname of database server');
has port => (is => 'rw', isa => 'Int', default => 3306, documentation => 'Port on database server (default 3306)');
has user => (is => 'rw', isa => 'Str', documentation => 'Username to log into database server');
has pass => (is => 'rw', isa => 'Str', documentation => 'Password for -user to access database');

1;
