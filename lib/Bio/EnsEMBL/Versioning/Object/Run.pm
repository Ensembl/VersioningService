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

package Bio::EnsEMBL::Versioning::Object::Run;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Versioning::Object);


# Run is the record of when a process is run for a given source version

__PACKAGE__->meta->setup(
  table       => 'run',

  columns     => [
    run_id        => {type => 'serial', primary_key => 1, not_null => 1},
    start         => {type => 'timestamp', not_null => 1, default => 'now()'},
    end           => {type => 'timestamp'},
  ],

  allow_inline_column_values => 1,

  relationships => [
    version => {
      'type'        => 'many to many',
      'map_class'   => 'Bio::EnsEMBL::Versioning::Object::VersionRun',
      'map_from'    => 'run',
      'map_to'      => 'version',
    },
  ],

);



1;
