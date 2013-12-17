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

package Bio::EnsEMBL::Versioning::Object::Resources;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Versioning::Object);


# A resource describes where the data to download can be found
# as well as any additional parameters that might be needed

__PACKAGE__->meta->setup(
  table       => 'resources',

  columns     => [
    resource_id        => {type => 'serial', primary_key => 1, not_null => 1},
    name               => {type => 'varchar', 'length' => 64},
    type               => {type => 'set', default => 'http', not_null => 1, 'values' => [qw(
                           http
                           ftp
                           file
                           db)]
    },
    value              => {type => 'varchar', 'length' => 150},
    multiple_files     => {type => 'integer', not_null => 1, default => 0},
    source_download_id => {type => 'integer'}
  ],

  foreign_keys => [
    source_download => {
      'class'       => 'Bio::EnsEMBL::Versioning::Object::SourceDownload',
      'key_columns'  => {'source_download_id' => 'source_download_id'},
    }
  ]
);



1;
