package Bio::EnsEMBL::Versioning::Object::SourceDownload;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Versioning::Object);


# A source download describes how new data can be downloaded for a given source
# A list of resources can be used

__PACKAGE__->meta->setup(
  table       => 'source_download',

  columns     => [
    source_download_id  => {type => 'serial', primary_key => 1, not_null => 1},
    source_id           => {type => 'integer'},
    module              => {type => 'varchar', 'length' => 40},
    parser              => {type => 'varchar', 'length' => 40},
  ],

  unique_key => ['module'],

  foreign_keys => [
    source => {
      'type'        => 'one to one',
      'class'       => 'Bio::EnsEMBL::Versioning::Object::Source',
      'key_columns'  => {'source_id' => 'source_id'}
    }
  ]
);



1;
