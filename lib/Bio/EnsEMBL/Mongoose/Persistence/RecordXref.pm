package Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

use Moose;

has source => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has id => (
    isa => 'Str',
    is => 'rw',
    required =>1,
);

has active => (
    isa => 'Bool',
    is => 'ro',
    required => 1,
    default => 1,
);

has version => (
    isa => 'Str',
    is => 'ro',
);

sub TO_JSON {
    return {%{shift()}};
}

__PACKAGE__->meta->make_immutable;

1;
