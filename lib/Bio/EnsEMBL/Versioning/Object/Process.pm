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

package Bio::EnsEMBL::Versioning::Object::Process;

use strict;
use warnings;


use parent qw(Bio::EnsEMBL::Versioning::Object);


# A process is run at a given time to generate a new version of a given source

__PACKAGE__->meta->setup(
  table       => 'process',

  columns     => [
    process_id        => {type => 'serial', primary_key => 1, not_null => 1},
    run_id            => {type => 'integer'},
    name              => {type => 'varchar', 'length' => 128 , not_null => 1},
    created_date      => {type => 'timestamp', not_null => 1, default => 'now()'},
  ],

  unique_key => ['name'],

  allow_inline_column_values => 1,

  foreign_keys => [
    run => {
      'class'       => 'Bio::EnsEMBL::Versioning::Object::Run',
      'key_columns' => {'run_id' => 'run_id'}
    }
  ]
);

1;
