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

package Bio::EnsEMBL::Versioning::Object::Version;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Versioning::Object);


# A version is the record of a source at a given time
# A source can have different versions, which were created at different times
# It references the location of the download as well as an index built on it

__PACKAGE__->meta->setup(
  table       => 'version',

  columns     => [
    version_id        => {type => 'serial', primary_key => 1, not_null => 1},
    source_id         => {type => 'integer'},
    version           => {type => 'varchar', not_null => 1, length => 255},
    created_date      => {type => 'timestamp', not_null => 1, default => 'now()'},
    count_seen        => {type => 'integer', not_null => 1, default => 1},
    record_count      => {type => 'integer'},
    uri               => {type => 'varchar', length => 255},  # location to find the local source copy
    index_uri         => {type => 'varchar', length => 255},  # location of index for this version of a source
  ],

  allow_inline_column_values => 1,

  foreign_keys => [
    source => {
      'class'       => 'Bio::EnsEMBL::Versioning::Object::Source',
      'key_columns'  => {'source_id' => 'source_id'}
    },
  ],

  relationships => [
    run => {
      'type'        => 'many to many',
      'map_class'   => 'Bio::EnsEMBL::Versioning::Object::VersionRun',
      'map_from'    => 'version',
      'map_to'      => 'run',
    },
  ],

);



1;
