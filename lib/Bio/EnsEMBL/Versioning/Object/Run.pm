package Bio::EnsEMBL::Versioning::Object::Run;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Versioning::Object);


# Run is the record of when a process is run for a given source version

__PACKAGE__->meta->setup(
  table       => 'run',

  columns     => [
    run_id        => {type => 'serial', primary_key => 1, not_null => 1},
    start         => {type => 'datetime', not_null => 1, default => 'now()'},
    end           => {type => 'datetime'},
  ],

  relationships => [
    process => {
      'type'        => 'many to many',
      'map_class'   => 'Bio::EnsEMBL::Versioning::Object::ProcessVersion',
      'map_from'    => 'run',
      'map_to'      => 'process',
    }
  ]
);



1;
