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
    source_group_id  => {type => 'integer', not_null => 1},
    active           => {type => 'integer', 'default' => 1, not_null => 1},
    created_date     => {type => 'datetime', not_null => 1, default => 'now()'},
  ],

  unique_key => ['name'],

  relationships => [
    source_group => {
      'type'        => 'many to one',
      'class'       => 'Bio::EnsEMBL::Versioning::Object::SourceGroup',
      'column_map'  => {'source_group_id' => 'source_group_id'}
    },
    version => {
      'type'        => 'one to many',
      'class'       => 'Bio::EnsEMBL::Versioning::Object::Version',
      'column_map'  => {'source_id' => 'source_id'}
    }
  ]
);



1;
