package MongooseHelper;

use Modern::Perl;
use Moose;

with 'MooseX::Getopt';

has species => (is => 'rw', isa => 'Str', default => 'homo sapiens');
has dump_path => (is => 'rw', isa => 'Str', default => '/nfs/nobackup/ensembl/ktaylor');
has source_list => (is => 'rw', isa => 'ArrayRef[Str]', default => sub { [qw/Swissprot MIM mim2gene HGNC/]} );
has format => (is => 'rw', isa => 'Str', default => 'RDF');

1;