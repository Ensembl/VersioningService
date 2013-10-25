package Bio::EnsEMBL::Mongoose::Mfetcher;

use Moose;

use Bio::EnsEMBL::Mongoose::Serializer::FASTA;
use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use Bio::EnsEMBL::Mongoose::Taxonomizer;

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

has query_params => (
    isa => 'Bio::EnsEMBL::Mongoose::Persistence::QueryParameters',
    is => 'rw',
);



1;