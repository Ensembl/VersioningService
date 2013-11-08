package Bio::EnsEMBL::Mongoose::Serializer::JSON;

use Moose;
use JSON::XS;

use Bio::EnsEMBL::Mongoose::IOException;

has handle => (
    isa => 'Ref',
    is => 'ro',
    required => 1, 
);

has encoder => (
    isa => 'Object',
    is => 'ro',
    required => 1,
    default => sub{
        return JSON::XS->new()->allow_blessed->convert_blessed;
    }
);

with 'MooseX::Log::Log4perl';

sub print_record {
    my $self = shift;
    my $record = shift;
    my $encoder = $self->encoder;
    my $handle = $self->handle;
    my $json = $self->encoder->encode($record);
    #$self->log->debug($json);
    print $handle $json;
}

1;