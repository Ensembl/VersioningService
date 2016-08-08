=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package MongooseHelper;

use Modern::Perl;
use Moose;

with 'MooseX::Getopt';

has species => (is => 'rw', isa => 'Str', default => 'homo sapiens');
has dump_path => (is => 'rw', isa => 'Str', default => '/nfs/nobackup/ensembl/ktaylor');
has source_list => (is => 'rw', isa => 'ArrayRef[Str]', default => sub { [qw/Swissprot MIM mim2gene HGNC/]} );
has format => (is => 'rw', isa => 'Str', default => 'RDF');

1;