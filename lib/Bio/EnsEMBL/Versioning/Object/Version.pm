package Bio::EnsEMBL::Versioning::Object::Version;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Versioning::Object);


# A version is the record of a source at a given time
# A source can have different versions, which were created at different times
# Only one version of a source can be current at a given time

__PACKAGE__->meta->setup(
  table       => 'version',

  columns     => [
    version_id        => {type => 'serial', primary_key => 1, not_null => 1},
    source_id         => {type => 'integer', not_null => 1},
    version           => {type => 'varchar', not_null => 1, 'length' => 40 },
    created_date      => {type => 'datetime', not_null => 1, default => 'now()'},
    is_current        => {type => 'integer', not_null => 1, default => 0},
    count_seen        => {type => 'integer', not_null => 1, default => 1},
    record_count      => {type => 'integer'}
  ],

  relationships => [
    source => {
      'type'        => 'many to one',
      'class'       => 'Bio::EnsEMBL::Versioning::Object::Source',
      'column_map'  => {'source_id' => 'source_id'}
    },
    process => {
      'type'        => 'many to many',
      'map_class'   => 'Bio::EnsEMBL::Versioning::Object::ProcessVersion',
      'map_from'    => 'version',
      'map_to'      => 'process',
    }
  ]
);



1;
