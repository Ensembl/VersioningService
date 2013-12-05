package Bio::EnsEMBL::Versioning::Object::Run;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Versioning::Object);


# Run is the record of when a process is run for a given source version

__PACKAGE__->meta->setup(
  table       => 'run',

  columns     => [
    run_id        => {type => 'serial', primary_key => 1, not_null => 1},
    start         => {type => 'timestamp', not_null => 1, default => 'now()'},
    end           => {type => 'timestamp'},
  ],

  allow_inline_column_values => 1,

  relationships => [
    version => {
      'type'        => 'many to many',
      'map_class'   => 'Bio::EnsEMBL::Versioning::Object::VersionRun',
      'map_from'    => 'run',
      'map_to'      => 'version',
    },
  ],

);



1;
