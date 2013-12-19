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

package Bio::EnsEMBL::Versioning::Object::Source;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Versioning::Object);


# A source is a type of data coming from an external source

__PACKAGE__->meta->setup(
  table       => 'source',

  columns     => [
    source_id        => {type => 'serial', primary_key => 1, not_null => 1},
    name             => {type => 'varchar', 'length' => 40 },
    source_group_id  => {type => 'integer'},
    active           => {type => 'integer', 'default' => 1, not_null => 1},
    created_date     => {type => 'timestamp', not_null => 1, default => 'now()'},
  ],

  unique_key => ['name'],

  allow_inline_column_values => 1,

  foreign_keys => [
    source_group => {
      'class'       => 'Bio::EnsEMBL::Versioning::Object::SourceGroup',
      'key_columns'  => {'source_group_id' => 'source_group_id'}
    },
  ],

  relationships => [
     version => {
       type       => 'one to many',
       class      => 'Bio::EnsEMBL::Versioning::Object::Version',
       column_map => { 'source_id' => 'source_id' },
     },
     source_download => {
       type       => 'one to one',
       class      => 'Bio::EnsEMBL::Versioning::Object::SourceDownload',
       column_map => { 'source_id' => 'source_id' },
     },
  ],

);



1;
