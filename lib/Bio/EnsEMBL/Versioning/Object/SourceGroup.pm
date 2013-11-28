package Bio::EnsEMBL::Versioning::Object::SourceGroup;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Versioning::Object);


# A source group is a meta source
# For a number of sources, source group will only contain one source
# But if we want different types of information from the same global source, we will create separate sources for that group

__PACKAGE__->meta->setup(
  table       => 'source_group',

  columns     => [
    source_group_id   => {type => 'serial', primary_key => 1, not_null => 1},
    name              => {type => 'varchar', 'length' => 40},
    created_date      => {type => 'datetime', not_null => 1, default => 'now()'},
  ],

  unique_key => ['name'],

  relationships => [
    source => {
      'type'        => 'one to many',
      'class'       => 'Bio::EnsEMBL::Versioning::Object::Source',
      'column_map'  => {'source_group_id' => 'source_group_id'},
    }
  ]
);




1;
