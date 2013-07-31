package Bio::EnsEMBL::Mongoose::Parser::Parser;
use Moose;

has 'source_file' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);


sub read_record {
    warn "Read not implemented.";
}

__PACKAGE__->meta->make_immutable;

1;