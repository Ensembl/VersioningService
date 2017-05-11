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

package Bio::EnsEMBL::Mongoose::Serializer::FASTA;

use Moose;

use Bio::EnsEMBL::Mongoose::IOException;

has linewidth => (
    isa => 'Int',
    is => 'ro',
    required => 1,
    default => 60,
);

# No chunk size, only writing smaller things

has header_function => (
    isa => 'CodeRef',
    is => 'rw',
    lazy => 1,
    default => sub {
        return sub {
            my $self = shift;
            my $record = shift;
            my $accession = $record->primary_accession;
            unless ($accession || !$record->has_accessions) {
                $accession = $record->get_accession(1);
            }
            my $handle = $self->handle;
            printf $handle ">%s %s %s %s\n", $accession, $record->taxon_id, $record->evidence_level, ""; 
        }
    }
);

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
    
    my $function = $self->header_function;
    &$function($self,$record);
    
    my $seq = $record->sequence;
    my $width = $self->linewidth;
    $seq =~ s/(.{1,$width})/$1\n/g;
    print $handle $seq or Bio::EnsEMBL::Mongoose::IOException->throw(message => "Error writing to file handle: $!");
}


1;
