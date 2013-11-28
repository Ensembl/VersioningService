package Bio::EnsEMBL::Versioning::Manager::SourceDownload;

use strict;
use warnings;

use Bio::EnsEMBL::Versioning::Object::SourceDownload;
use base qw(Bio::EnsEMBL::Versioning::Manager);

sub object_class { 'Bio::EnsEMBL::Versioning::Object::SourceDownload' }

 __PACKAGE__->make_manager_methods('source_download');




1;
