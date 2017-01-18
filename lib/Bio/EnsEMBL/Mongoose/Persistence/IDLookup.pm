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

package Bio::EnsEMBL::Mongoose::Persistence::IDLookup;

use Moose;

use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use FindBin qw/$Bin/;

has 'config_file' => (
    is => 'ro',
    isa => 'Str',
    default => "$Bin/../conf/swissprot.conf"
);

has lucy => (
    is => 'ro',
    isa => 'Bio::EnsEMBL::Mongoose::Persistence::LucyQuery',
    lazy => 1,
    default => sub {
        my ($self) = @_;
        return my $lucy = Bio::EnsEMBL::Mongoose::Persistence::LucyQuery->new(config_file => $self->config_file());
    }
);

# NOTE - only exists to satisfy one-time Uniparc lookup. It assumes one Uniprot ID 
# per record, and ignores possible primary accessions
sub fetch_id {
    my $self = shift;
    my $ens_id = shift;
    
    my $query = 'xref:'.$ens_id;
    
    $self->lucy->query($query);
    
    my $hit = $self->lucy->next_result;
    return $hit->{accessions};
}

1;
