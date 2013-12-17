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

package Bio::EnsEMBL::Versioning::Object::VersionRun;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Versioning::Object);


# A version run maps a run with versions

__PACKAGE__->meta->setup(
  table       => 'version_run',

  columns     => [
    version_run_id      => {type => 'int', type => 'serial', not_null => 1, primary_key => 1},
    version_id          => {type => 'int'},
    run_id              => {type => 'int'},
  ],

  allow_inline_column_values => 1,

  foreign_keys => [
    version => {
      'class'       => 'Bio::EnsEMBL::Versioning::Object::Version',
      'key_columns'  => {'version_id' => 'version_id'},
    },
    run => {
      'class'       => 'Bio::EnsEMBL::Versioning::Object::Run',
      'key_columns'  => {'run_id' => 'run_id'},
    }
  ]
);


1;
