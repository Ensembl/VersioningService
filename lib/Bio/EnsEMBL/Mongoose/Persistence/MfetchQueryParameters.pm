package Bio::EnsEMBL::Mongoose::Persistence::MfetchQueryParameters;

# A holding object for query parameters, prior to translation into 
# search engine lingo. 

use Moose;
use Moose::Util::TypeConstraints;

has source => (
    isa => 'Obj',  
    is => 'ro',
    
);

has output_format => (
    isa => enum([qw( FASTA JSON)]),
    is => 'ro',
    default => 'FASTA',
);

has ids => (
    isa => 'ArrayRef[Str]',
    is => 'rw',
    default => sub {[]},
    traits => ['Array'],
    handles => {
        count_ids => 'count',
        all_ids => 'elements'
    },
);



1;