package Bio::EnsEMBL::Versioning::Manager::Process;

use strict;
use warnings;

use Bio::EnsEMBL::Versioning::Object::Process;
use base qw(Bio::EnsEMBL::Versioning::Manager);

sub object_class { 'Bio::EnsEMBL::Versioning::Object::Process' }

 __PACKAGE__->make_manager_methods('processes');




1;
