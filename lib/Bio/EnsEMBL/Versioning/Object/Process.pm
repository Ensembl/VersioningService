package Bio::EnsEMBL::Versioning::Object::Process;

use strict;
use warnings;


use base qw(Bio::EnsEMBL::Versioning::Object);


# A process is run at a given time to generate a new version of a given source

__PACKAGE__->meta->setup(
  table       => 'process',

  columns     => [
    process_id        => {type => 'serial', primary_key => 1, not_null => 1},
    name              => {type => 'varchar', 'length' => 40, not_null => 1},
    created_date      => {type => 'datetime', not_null => 1, default => 'now()'},
  ],

  unique_key => ['name'],

  relationships => [
    version => {
      'type'        => 'many to many',
      'map_class'   => 'Bio::EnsEMBL::Versioning::Object::ProcessVersion',
      'map_from'    => 'process',
      'map_to'      => 'version',
    },
    run => {
      'type'        => 'many to many',
      'map_class'   => 'Bio::EnsEMBL::Versioning::Object::ProcessVersion',
      'map_from'    => 'process',
      'map_to'      => 'run',
    }
  ]
);

1;
