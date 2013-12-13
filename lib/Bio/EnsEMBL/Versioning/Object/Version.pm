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
    source_id         => {type => 'integer'},
    version           => {type => 'varchar', not_null => 1, 'length' => 40 },
    created_date      => {type => 'timestamp', not_null => 1, default => 'now()'},
    is_current        => {type => 'integer', not_null => 1, default => 0},
    count_seen        => {type => 'integer', not_null => 1, default => 1},
    record_count      => {type => 'integer'},
    uri               => {type => 'varchar', length => 150},
  ],

  allow_inline_column_values => 1,

  foreign_keys => [
    source => {
      'class'       => 'Bio::EnsEMBL::Versioning::Object::Source',
      'key_columns'  => {'source_id' => 'source_id'}
    },
  ],

);



1;
