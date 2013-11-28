package Bio::EnsEMBL::Versioning::Object::Resources;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Versioning::Object);


# A resource describes where the data to download can be found
# as well as any additional parameters that might be needed

__PACKAGE__->meta->setup(
  table       => 'resources',

  columns     => [
    resource_id        => {type => 'serial', primary_key => 1, not_null => 1},
    name               => {type => 'varchar', 'length' => 64},
    type               => {type => 'set', default => 'http', not_null => 1, 'values' => [qw(
                           http
                           ftp
                           file
                           db)]
    },
    value              => {type => 'varchar', 'length' => 40},
    multiple_files     => {type => 'integer', not_null => 1, default => 0},
    source_download_id => {type => 'integer', not_null => 1}
  ],

  relationships => [
    source_download => {
      'type'        => 'many to one',
      'class'       => 'Bio::EnsEMBL::Versioning::Object::SourceDownload',
      'column_map'  => {'source_download_id' => 'source_download_id'},
    }
  ]
);



1;
