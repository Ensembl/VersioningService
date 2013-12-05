package Bio::EnsEMBL::Versioning::Object::Source;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Versioning::Object);


# A source is a type of data coming from an external source

__PACKAGE__->meta->setup(
  table       => 'source',

  columns     => [
    source_id        => {type => 'serial', primary_key => 1, not_null => 1},
    name             => {type => 'varchar', 'length' => 40 },
    source_group_id  => {type => 'integer'},
    active           => {type => 'integer', 'default' => 1, not_null => 1},
    created_date     => {type => 'timestamp', not_null => 1, default => 'now()'},
  ],

  unique_key => ['name'],

  allow_inline_column_values => 1,

  foreign_keys => [
    source_group => {
      'class'       => 'Bio::EnsEMBL::Versioning::Object::SourceGroup',
      'key_columns'  => {'source_group_id' => 'source_group_id'}
    },
  ],

);



1;
