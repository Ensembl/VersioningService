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
    created_date      => {type => 'timestamp', not_null => 1, default => 'now()'},
  ],

  allow_inline_column_values => 1,

  unique_key => ['name'],

);




1;
