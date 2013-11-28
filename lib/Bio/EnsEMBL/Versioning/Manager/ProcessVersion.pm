package Bio::EnsEMBL::Versioning::Manager::ProcessVersion;

use strict;
use warnings;

use Bio::EnsEMBL::Versioning::Object::ProcessVersion;
use base qw(Bio::EnsEMBL::Versioning::Manager);

sub object_class { 'Bio::EnsEMBL::Versioning::Object::ProcessVersion' }

 __PACKAGE__->make_manager_methods('process_versions');




1;
