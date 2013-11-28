package Bio::EnsEMBL::Versioning::Manager::Run;

use strict;
use warnings;

use Bio::EnsEMBL::Versioning::Object::Run;
use base qw(Bio::EnsEMBL::Versioning::Manager);

sub object_class { 'Bio::EnsEMBL::Versioning::Object::Run' }

 __PACKAGE__->make_manager_methods('runs');




1;
