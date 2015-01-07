package Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

use Moose;

# source of the xref, not necessarily the source that made the link.
has source => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

# name/id from the external source
has id => (
    isa => 'Str',
    is => 'rw',
    required =>1,
);

# refers to whether a link is retired or not
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

# who said this link exists. Needed where xref sources are aggregators themselves.
has author => (
    isa => 'Str',
    is => 'ro',
);

sub TO_JSON {
    return {%{shift()}};
}

__PACKAGE__->meta->make_immutable;

1;
