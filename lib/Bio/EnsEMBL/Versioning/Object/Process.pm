package Bio::EnsEMBL::Versioning::Object::Process;

use strict;
use warnings;


use base qw(Bio::EnsEMBL::Versioning::Object);


# A process is run at a given time to generate a new version of a given source

__PACKAGE__->meta->setup(
  table       => 'process',

  columns     => [
    process_id        => {type => 'serial', primary_key => 1, not_null => 1},
    run_id            => {type => 'integer'},
    name              => {type => 'varchar', 'length' => 40, not_null => 1},
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
