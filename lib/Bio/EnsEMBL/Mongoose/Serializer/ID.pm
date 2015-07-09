# Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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