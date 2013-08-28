package Bio::EnsEMBL::Mongoose::Persistence::Query;
use Moose::Role;

use Config::General;

use FindBin qw/$Bin/;

has config => (
    isa => 'HashRef',
    is => 'ro',
    required => 1,
    default => sub {
        my $conf = Config::General->new("$Bin/../conf/swissprot.conf");
        my %opts = $conf->getall();
        return \%opts;
    },
);

has query_string => (
    isa => 'Str',
    is => 'rw',
);

# Runs the supplied query through the query engine.
# Returns the result size if possible
sub query {
    
};


# Should iterate through results internally and emit the next result until there are no more.
sub next_result {
    
};

1;