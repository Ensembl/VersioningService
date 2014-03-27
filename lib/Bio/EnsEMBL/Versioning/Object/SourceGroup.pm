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

package Bio::EnsEMBL::Versioning::Object::SourceGroup;

use strict;
use warnings;

use parent qw(Bio::EnsEMBL::Versioning::Object);


# A source group is a meta source
# For a number of sources, source group will only contain one source
# But if we want different types of information from the same global source, we will create separate sources for that group

__PACKAGE__->meta->setup(
  table       => 'source_group',

  columns     => [
    source_group_id   => {type => 'serial', primary_key => 1, not_null => 1},
    name              => {type => 'varchar', 'length' => 128},
    created_date      => {type => 'timestamp', not_null => 1, default => 'now()'},
  ],

  allow_inline_column_values => 1,

  unique_key => ['name'],

  relationships => [
     source => {
       type       => 'one to many',
       class      => 'Bio::EnsEMBL::Versioning::Object::Source',
       column_map => { 'source_group_id' => 'source_group_id' },
     },
  ],

);




1;
