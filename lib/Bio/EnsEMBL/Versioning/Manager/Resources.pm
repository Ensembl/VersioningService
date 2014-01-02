=head1 LICENSE
 
Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 
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

package Bio::EnsEMBL::Versioning::Manager::Resources;

use strict;
use warnings;

use Bio::EnsEMBL::Versioning::Object::Resources;
use base qw(Bio::EnsEMBL::Versioning::Manager);

sub object_class { 'Bio::EnsEMBL::Versioning::Object::Resources' }

 __PACKAGE__->make_manager_methods('resources');


sub get_release_resource {
  my $self = shift;
  my $source_name = shift;
  
  my $resources = $self->get_objects(
                         with_objects => ['source'],
                         query => [
                                   'source.name' => $source_name,
                                   release_version => 1
                                  ],
                         distinct => 1);

  return $resources->[0];
}

1;
