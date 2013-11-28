package Bio::EnsEMBL::Versioning::Object::ProcessVersion;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Versioning::Object);


# A process version maps a process with a source version

__PACKAGE__->meta->setup(
  table       => 'process_version',

  columns     => [
    process_version_id  => {type => 'serial', primary_key => 1, not_null => 1},
    process_id          => {type => 'int', not_null => 1},
    version_id          => {type => 'int', not_null => 1},
    run_id              => {type => 'int', not_null => 1},
  ],

  relationships => [
    process => {
      'type'        => 'many to one',
      'class'       => 'Bio::EnsEMBL::Versioning::Object::Process',
      'column_map'  => {'process_id' => 'process_id'},
    },
    version => {
      'type'        => 'many to one',
      'class'       => 'Bio::EnsEMBL::Versioning::Object::Version',
      'column_map'  => {'version_id' => 'version_id'},
    },
    run => {
      'type'        => 'many to one',
      'class'       => 'Bio::EnsEMBL::Versioning::Object::Run',
      'column_map'  => {'run_id' => 'run_id'},
    }
  ]
);


1;
