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

package Bio::EnsEMBL::Mongoose::Parser::Parser;
use Moose::Role;

use PerlIO::gzip;
use Bio::EnsEMBL::Mongoose::IOException;

has record => (
    is => 'rw',
    isa => 'Bio::EnsEMBL::Mongoose::Persistence::Record',
    lazy => 1,
    default => sub {
        return Bio::EnsEMBL::Mongoose::Persistence::Record->new;
    },
    clearer => 'clear_record',
);

has 'source_file' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'source_handle' => (
    isa => 'GlobRef',
    is => 'rw',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $fh;
        open $fh, "<:gzip(autopop)", $self->source_file 
          || Bio::EnsEMBL::Mongoose::IOException->throw('Failed to open source_file '.$self->source_file);
        return $fh;
    }
);


sub read_record {
    
}

1;