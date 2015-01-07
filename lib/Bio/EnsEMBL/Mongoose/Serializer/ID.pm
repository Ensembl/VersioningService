# tinpot writer for checking data integrity in the document store

package Bio::EnsEMBL::Mongoose::Serializer::ID;

use Moose;

use Bio::EnsEMBL::Mongoose::IOException;

has handle => (
    isa => 'Ref',
    is => 'ro',
    required => 1, 
);

with 'MooseX::Log::Log4perl';

sub print_record {
    my $self = shift;
    my $record = shift;
    my $handle = $self->handle;
    my $id = $record->primary_accession;
    unless ($id) { $id = $record->accessions->shift }

    print $handle $id."\n" or Bio::EnsEMBL::Mongoose::IOException->throw(message => "Error writing to file handle: $!");
}

1;