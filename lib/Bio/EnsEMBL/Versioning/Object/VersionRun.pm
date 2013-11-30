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
