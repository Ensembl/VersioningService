package Bio::EnsEMBL::Mongoose::Parser::Parser;
use Moose::Role;

has 'source_file' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);


sub read_record {
    
}

__PACKAGE__->meta->make_immutable;

1;