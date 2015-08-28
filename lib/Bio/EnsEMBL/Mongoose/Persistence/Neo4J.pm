# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package Neo4J;

# In anticipation of Neo4J being an unfolding catastrophy, this module is ready to be abstracted for alternative backends...

use Moose;
use REST::Neo4p;
use REST::Neo4p::Batch;



with 'Bio::EnsEMBL::Mongoose::Persistence::DocumentStore';

sub init {
  my $self = shift;
  my %conf = %{ $self->config };
  my $connection_string = sprintf 'http://%s:%s',$conf{host},$conf{port};
  REST::Neo4p->connect($connection_string);
}

sub import_ids {
  my ($self,$list_of_ids) = @_;

  batch {
    while (my $id = shift @$list_of_ids) {
      REST::Neo4p::Node->new({ id => $id});
    }
  } 'discard_objs';
}

1;