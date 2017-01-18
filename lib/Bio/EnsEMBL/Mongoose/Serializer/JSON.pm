=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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
    #$self->log->trace($json);
    print $handle $json;
}

1;
