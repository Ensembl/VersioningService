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

package Bio::EnsEMBL::Versioning::Object::SourceDownload;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Versioning::Object);


# A source download describes how new data can be downloaded for a given source
# A list of resources can be used

__PACKAGE__->meta->setup(
  table       => 'source_download',

  columns     => [
    source_download_id  => {type => 'serial', primary_key => 1, not_null => 1},
    source_id           => {type => 'integer'},
    module              => {type => 'varchar', 'length' => 40},
    parser              => {type => 'varchar', 'length' => 40},
  ],

  unique_key => ['module'],

  foreign_keys => [
    source => {
      'type'        => 'one to one',
      'class'       => 'Bio::EnsEMBL::Versioning::Object::Source',
      'key_columns'  => {'source_id' => 'source_id'}
    }
  ]
);



1;
