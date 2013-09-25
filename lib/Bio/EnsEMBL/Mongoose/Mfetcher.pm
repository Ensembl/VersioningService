package Bio::EnsEMBL::Mongoose::Mfetcher;

use Moose;

use Bio::EnsEMBL::Mongoose::Serializer::FASTA;

has handle => (
    isa => 'Maybe[IO::File]',
    is => 'ro',
    lazy => 1,
    default {},
);

has fasta_writer => (
    isa => 'Bio::EnsEMBL::Mongoose::Serializer::FASTA',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $handle;
        if ($self->handle) {
            return Bio::EnsEMBL::Mongoose::Serializer::FASTA->new(handle => $handle);
        }
        return Bio::EnsEMBL::Mongoose::Serializer::FASTA->new();
    }
);

has default_subset => (
    isa => 'Str',
    is => 'rw',
    default => 'evidence_level:1..3',
    
);

has query => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

sub query_it {
    my $self = shift;
    
}

1;